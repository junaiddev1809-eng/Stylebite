import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../../core/utils/verified_badge_hydrator.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/models/home_post_model.dart';
import '../../reports/api/reports_api.dart';
import '../models/post_comment_model.dart';
import '../models/post_detail_model.dart';
import '../services/post_interaction_store.dart';
import '../utils/like_toggle.dart';
import '../utils/rating_math.dart';
import 'restaurant_review_store.dart';
import '../../messages/services/chat_event_bus.dart';

class PostDetailController extends GetxController {
  PostDetailController({
    required this.postId,
    required HomePostModel initialPost,
  }) : post = initialPost.obs;

  final String postId;
  final Rx<HomePostModel> post;

  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxBool isCommentsLoading = false.obs;
  final RxBool isLoadingMoreComments = false.obs;
  final RxBool hasMoreComments = true.obs;
  final RxBool canVote = false.obs;
  final RxBool isLikeLoading = false.obs;
  final RxBool isSaveLoading = false.obs;
  final RxBool isShareLoading = false.obs;
  final RxBool isVoteLoading = false.obs;
  final RxBool isSubmittingComment = false.obs;
  final RxList<PostCommentModel> comments = <PostCommentModel>[].obs;
  final RxSet<String> commentLikeLoadingIds = <String>{}.obs;
  final RxSet<String> replyLikeLoadingIds = <String>{}.obs;

  final ScrollController commentsScrollController = ScrollController();

  int _currentCommentsPage = 0;
  StreamSubscription<ChatPushEvent>? _pushSubscription;

  Worker? _interactionWorker;

  @override
  void onInit() {
    super.onInit();
    commentsScrollController.addListener(_onCommentsScroll);
    _pushSubscription = ChatEventBus.instance.stream.listen(_handlePushEvent);
    post.value = PostInteractionStore.ensure().presentHome(post.value);
    _interactionWorker = ever(PostInteractionStore.ensure().revision, (_) {
      _applySharedInteraction();
    });
    RestaurantReviewStore.instance.ingestPosts(<HomePostModel>[post.value]);
    fetchDetail();
  }

  @override
  void onClose() {
    _interactionWorker?.dispose();
    commentsScrollController
      ..removeListener(_onCommentsScroll)
      ..dispose();
    _pushSubscription?.cancel();
    super.onClose();
  }

  Future<void> fetchDetail({bool showLoader = true}) async {
    if (showLoader) {
      isLoading.value = true;
    }
    hasError.value = false;

    try {
      final observedAt = PostInteractionStore.ensure().observedClock;
      final detail = await _fetchDetailResponse();
      if (detail == null) {
        return;
      }

      final shown = PostInteractionStore.ensure().ingestHome(
        detail.post,
        observedAt: observedAt,
      );
      post.value = shown;
      canVote.value = detail.canVote;
      _syncHomeFeedPost(shown);
      RestaurantReviewStore.instance.ingestPosts(<HomePostModel>[shown]);
      unawaited(
        RestaurantReviewStore.instance.ensureRestaurantLoaded(detail.post),
      );
      await fetchComments(reset: true, showLoader: showLoader);
    } catch (error) {
      hasError.value = true;
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (showLoader) {
        isLoading.value = false;
      }
    }
  }

  Future<void> fetchComments({
    required bool reset,
    bool showLoader = true,
  }) async {
    if (reset) {
      if (showLoader) {
        isCommentsLoading.value = true;
      }
      _currentCommentsPage = 0;
      hasMoreComments.value = true;
    } else {
      if (isLoadingMoreComments.value || !hasMoreComments.value) {
        return;
      }
      isLoadingMoreComments.value = true;
    }

    try {
      final page = reset ? 1 : _currentCommentsPage + 1;
      final commentsResponse = await _fetchCommentsResponse(page: page);
      if (commentsResponse == null) {
        return;
      }

      if (reset) {
        comments.assignAll(commentsResponse.comments);
      } else {
        final merged = <String, PostCommentModel>{
          for (final item in comments) item.id: item,
        };
        for (final item in commentsResponse.comments) {
          merged[item.id] = item;
        }
        comments.assignAll(merged.values);
      }

      _currentCommentsPage = commentsResponse.pagination.currentPage;
      hasMoreComments.value = commentsResponse.pagination.hasMorePages;
      VerifiedBadgeHydrator.hydrate(_commentUsernames(comments));
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (reset) {
        if (showLoader) {
          isCommentsLoading.value = false;
        }
      } else {
        isLoadingMoreComments.value = false;
      }
    }
  }

  Future<void> toggleLike() async {
    final current = post.value;
    final shared = PostInteractionStore.ensure().stateFor(postId);
    PostInteractionStore.ensure().toggleLike(
      postId: postId,
      isLiked: shared?.isLiked ?? current.isLiked,
      likeCount: shared?.likeCount ?? parseLikeCount(current.likes),
      isSaved: current.isSaved,
      saveCount: current.saveCount,
    );
  }

  void _applySharedInteraction() {
    post.value = PostInteractionStore.ensure().presentHome(post.value);
  }

  void toggleSave() {
    final current = post.value;
    final shared = PostInteractionStore.ensure().stateFor(postId);
    PostInteractionStore.ensure().toggleSave(
      postId: postId,
      isSaved: shared?.isSaved ?? current.isSaved,
      saveCount: shared?.saveCount ?? current.saveCount,
      isLiked: current.isLiked,
      likeCount: parseLikeCount(current.likes),
      draft: SavedPostDraft.fromHome(current),
    );
  }

  Future<void> sharePost({
    required String shareChannel,
    int? targetUserId,
  }) async {
    await _runPostAction(
      loadingFlag: isShareLoading,
      endpoint: 'feed/posts/$postId/share',
      body: <String, dynamic>{
        'share_channel': shareChannel,
        'target_user_id': targetUserId,
      },
    );
  }

  Future<void> votePost(int rating) async {
    if (isVoteLoading.value) {
      return;
    }

    final previous = post.value;
    var shown = postWithRating(post: previous, rating: rating);
    post.value = shown;
    isVoteLoading.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'feed/posts/$postId/vote',
        body: <String, dynamic>{'rating_value': rating},
      );
      await _ensureSuccess(response, fallback: 'Unable to update post');
      final payload = jsonDecode(response!.body) as Map<String, dynamic>;
      shown = postFromVotePayload(post.value, payload) ?? shown;
      post.value = shown;
      _syncHomeFeedPost(shown);
    } catch (error) {
      post.value = previous;
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isVoteLoading.value = false;
    }
  }

  Future<void> submitComment(String text) async {
    if (isSubmittingComment.value) {
      return;
    }

    isSubmittingComment.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'feed/posts/$postId/comments',
        body: <String, dynamic>{'body': text},
      );
      await _ensureSuccess(response, fallback: 'Unable to add comment');
      _insertLocalComment(text);
      _scheduleBackgroundSync();
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isSubmittingComment.value = false;
    }
  }

  Future<void> submitReply({
    required String commentId,
    String? parentReplyId,
    required String text,
  }) async {
    if (_isLocalCommentId(commentId) ||
        (parentReplyId != null && _isLocalCommentId(parentReplyId))) {
      return;
    }

    if (isSubmittingComment.value) {
      return;
    }

    isSubmittingComment.value = true;
    try {
      final body = <String, dynamic>{'body': text};
      body['parent_reply_id'] =
          parentReplyId != null && parentReplyId.isNotEmpty
          ? parentReplyId
          : null;

      final response = await ApiHelper.postRequestWithAuthorization(
        'feed/comments/$commentId/replies',
        body: body,
      );
      await _ensureSuccess(response, fallback: 'Unable to add reply');
      _insertLocalReply(
        commentId: commentId,
        parentReplyId: parentReplyId,
        text: text,
      );
      _scheduleBackgroundSync();
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isSubmittingComment.value = false;
    }
  }

  Future<void> likeComment(String commentId) async {
    if (_isLocalCommentId(commentId)) {
      return;
    }
    await _runCommentAction(
      loadingSet: commentLikeLoadingIds,
      id: commentId,
      endpoint: 'feed/comments/$commentId/like',
    );
  }

  Future<void> likeReply(String replyId) async {
    if (_isLocalCommentId(replyId)) {
      return;
    }
    await _runCommentAction(
      loadingSet: replyLikeLoadingIds,
      id: replyId,
      endpoint: 'feed/replies/$replyId/like',
    );
  }

  Future<void> reportComment(
    String commentId,
    String reasonCode,
    String? details,
  ) async {
    if (_isLocalCommentId(commentId)) {
      return;
    }
    await _reportCommentOrReply(
      targetType: 'comment',
      targetId: commentId,
      reasonCode: reasonCode,
      details: details,
    );
  }

  Future<void> reportReply(
    String replyId,
    String reasonCode,
    String? details,
  ) async {
    if (_isLocalCommentId(replyId)) {
      return;
    }
    await _reportCommentOrReply(
      targetType: 'reply',
      targetId: replyId,
      reasonCode: reasonCode,
      details: details,
    );
  }

  Future<void> deleteComment(String commentId) async {
    await _deleteCommentOrReply(id: commentId, isReply: false);
  }

  Future<void> deleteReply(String replyId) async {
    await _deleteCommentOrReply(id: replyId, isReply: true);
  }

  Future<void> _deleteCommentOrReply({
    required String id,
    required bool isReply,
  }) async {
    final previousComments = List<PostCommentModel>.from(comments);
    final previousPost = post.value;
    final removedCount = _removeCommentFromUi(id);
    if (removedCount <= 0) {
      return;
    }
    _adjustPostCommentCount(-removedCount);

    try {
      if (!_isLocalCommentId(id)) {
        await _deleteRemoteComment(
          endpoints: isReply
              ? <String>['feed/replies/$id']
              : <String>[
                  'feed/comments/$id',
                  'feed/posts/$postId/comments/$id',
                ],
          fallback: isReply
              ? 'Unable to delete reply'
              : 'Unable to delete comment',
        );
      }
      successSnackBar(
        message: isReply ? 'Reply deleted.' : 'Comment deleted.',
      );
      if (!_isLocalCommentId(id)) {
        _scheduleBackgroundSync();
      }
    } catch (error) {
      comments.assignAll(previousComments);
      post.value = previousPost;
      _syncHomeFeedPost(previousPost);
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _reportCommentOrReply({
    required String targetType,
    required String targetId,
    required String reasonCode,
    String? details,
  }) async {
    final id = int.tryParse(targetId);
    if (id == null) {
      errorSnackBar(message: 'Unable to report this right now.');
      return;
    }
    try {
      final result = await ReportsApi.submitReport(
        targetType: targetType,
        targetId: id,
        reason: reasonCode,
        description: details,
      );
      if (result.alreadyReported) {
        infoSnackBar(
          message: 'You already reported this. Our team is reviewing it.',
        );
      } else {
        successSnackBar(
          message:
              '${targetType == 'reply' ? 'Reply' : 'Comment'} reported. Thanks for letting us know.',
        );
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void maybeLoadMoreComments(int index) {
    if (index >= comments.length - 2) {
      fetchComments(reset: false);
    }
  }

  Future<void> refreshPostAndComments() async {
    await fetchDetail(showLoader: false);
  }

  Future<bool> deletePost() async {
    try {
      final response = await ApiHelper.deleteRequestWithAuthorization(
        'posts/$postId',
      );
      await _ensureSuccess(response, fallback: 'Unable to delete post');
      final homeController = Get.isRegistered<HomeController>()
          ? Get.find<HomeController>()
          : null;
      homeController?.removePost(postId);
      successSnackBar(message: 'Post deleted successfully.');
      return true;
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<void> repostOwnerPost() async {
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'posts/$postId/repost',
      );
      await _ensureSuccess(response, fallback: 'Unable to repost post');
      await fetchDetail(showLoader: false);
      successSnackBar(message: 'Post reposted successfully.');
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool> blockPostAuthor() async {
    final targetUsername = post.value.profileUsername.trim().isNotEmpty
        ? post.value.profileUsername.trim().replaceFirst('@', '')
        : post.value.username.trim().replaceFirst('@', '');
    final currentUsername = LocalStorage.getUsername()?.trim().replaceFirst(
      '@',
      '',
    );
    if (targetUsername.isEmpty ||
        targetUsername.toLowerCase() == currentUsername?.toLowerCase()) {
      errorSnackBar(message: 'You cannot block yourself.');
      return false;
    }

    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'profiles/${Uri.encodeComponent(targetUsername)}/block',
        body: <String, dynamic>{},
      );
      await _ensureSuccess(response, fallback: 'Unable to block user');
      final homeController = Get.isRegistered<HomeController>()
          ? Get.find<HomeController>()
          : null;
      homeController?.removePost(postId);
      successSnackBar(message: 'User blocked successfully.');
      return true;
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  Future<void> refreshPostAndCommentsSilently() async {
    try {
      final detail = await _fetchDetailResponse();
      if (detail == null) {
        return;
      }

      final currentCount = _countFromDisplay(post.value.comments);
      final backendCount = _countFromDisplay(detail.post.comments);
      post.value = backendCount < currentCount
          ? detail.post.copyWith(comments: post.value.comments)
          : detail.post;
      canVote.value = detail.canVote;
      _syncHomeFeedPost(post.value);
      if (!_hasLocalPendingItems) {
        await fetchComments(reset: true, showLoader: false);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        final refreshedComments = await _fetchCommentsResponse(page: 1);
        if (refreshedComments != null) {
          comments.assignAll(refreshedComments.comments);
          _currentCommentsPage = refreshedComments.pagination.currentPage;
          hasMoreComments.value = refreshedComments.pagination.hasMorePages;
          VerifiedBadgeHydrator.hydrate(
            _commentUsernames(refreshedComments.comments),
          );
        }
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _handlePushEvent(ChatPushEvent event) {
    if (!event.isCommentEvent) {
      return;
    }

    final eventPostId = _readPushPostId(event.payload);
    if (eventPostId == postId) {
      refreshPostAndCommentsSilently();
    }
  }

  void _onCommentsScroll() {
    if (!commentsScrollController.hasClients) {
      return;
    }
    if (commentsScrollController.position.extentAfter < 300) {
      fetchComments(reset: false);
    }
  }

  Future<void> _runPostAction({
    required RxBool loadingFlag,
    required String endpoint,
    Map<String, dynamic>? body,
  }) async {
    if (loadingFlag.value) {
      return;
    }

    loadingFlag.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        endpoint,
        body: body,
      );
      await _ensureSuccess(response, fallback: 'Unable to update post');
      await fetchDetail(showLoader: false);
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      loadingFlag.value = false;
    }
  }

  Future<void> _runCommentAction({
    required RxSet<String> loadingSet,
    required String id,
    required String endpoint,
  }) async {
    if (loadingSet.contains(id)) {
      return;
    }

    loadingSet.add(id);
    try {
      final response = await ApiHelper.postRequestWithAuthorization(endpoint);
      await _ensureSuccess(response, fallback: 'Unable to update like');
      await refreshPostAndComments();
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      loadingSet.remove(id);
    }
  }

  Future<PostDetailResponse?> _fetchDetailResponse() async {
    await ContestEnrollmentStore.instance.ensureLoaded();
    final response = await ApiHelper.fetchDataWithAuthorization(
      'feed/posts/$postId?comments_page=1',
    );

    if (response == null) {
      throw Exception('No response returned from post detail endpoint.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (!_isSuccessStatusCode(response.statusCode) ||
        payload['status_code'] != 1) {
      throw Exception(
        (payload['message'] ?? 'Failed to load post detail').toString(),
      );
    }

    return PostDetailResponse.fromJson(payload);
  }

  Future<PostCommentsResponse?> _fetchCommentsResponse({
    required int page,
  }) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      'feed/posts/$postId/comments?page=$page',
    );

    if (response == null) {
      throw Exception('No response returned from comments endpoint.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (!_isSuccessStatusCode(response.statusCode) ||
        payload['status_code'] != 1) {
      throw Exception(
        (payload['message'] ?? 'Failed to load comments').toString(),
      );
    }

    return PostCommentsResponse.fromJson(payload);
  }

  Future<void> _ensureSuccess(
    dynamic response, {
    required String fallback,
  }) async {
    if (response == null) {
      throw Exception('No response returned from server.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (!_isSuccessStatusCode(response.statusCode) ||
        payload['status_code'] != 1) {
      throw Exception((payload['message'] ?? fallback).toString());
    }
  }

  Future<void> _deleteRemoteComment({
    required List<String> endpoints,
    required String fallback,
  }) async {
    Exception? lastError;
    for (final endpoint in endpoints) {
      final response = await ApiHelper.deleteRequestWithAuthorization(endpoint);
      if (response == null) {
        lastError = Exception('No response returned from server.');
        continue;
      }
      try {
        await _ensureSuccess(response, fallback: fallback);
        return;
      } catch (error) {
        lastError = error is Exception ? error : Exception(error.toString());
        if (response.statusCode != 404) {
          throw lastError;
        }
      }
    }
    throw lastError ?? Exception(fallback);
  }

  void _syncHomeFeedPost(HomePostModel updatedPost) {
    if (!Get.isRegistered<HomeController>()) {
      return;
    }
    Get.find<HomeController>().upsertPost(updatedPost);
  }

  void _insertLocalComment(String text) {
    comments.insert(0, PostCommentModel.localFromViewer(text: text));
    _incrementPostCommentCount();
  }

  void _scheduleBackgroundSync() {
    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (isClosed) {
        return;
      }
      await refreshPostAndCommentsSilently();
    });
  }

  void _insertLocalReply({
    required String commentId,
    required String? parentReplyId,
    required String text,
  }) {
    final reply = PostCommentModel.localFromViewer(
      text: text,
      commentId: commentId,
      parentReplyId: parentReplyId,
    );

    final updated = comments
        .map(
          (comment) => _attachReply(
            comment: comment,
            targetCommentId: commentId,
            parentReplyId: parentReplyId,
            reply: reply,
          ),
        )
        .toList(growable: false);
    comments.assignAll(updated);
    _incrementPostCommentCount();
  }

  PostCommentModel _attachReply({
    required PostCommentModel comment,
    required String targetCommentId,
    required String? parentReplyId,
    required PostCommentModel reply,
  }) {
    if (comment.id == targetCommentId && parentReplyId == null) {
      return comment.copyWith(
        replies: <PostCommentModel>[...comment.replies, reply],
        replyCount: comment.replyCount + 1,
      );
    }

    final updatedReplies = comment.replies
        .map(
          (child) => _attachReply(
            comment: child,
            targetCommentId: targetCommentId,
            parentReplyId: parentReplyId,
            reply: reply,
          ),
        )
        .toList(growable: false);

    if (parentReplyId != null && comment.id == parentReplyId) {
      return comment.copyWith(
        replies: <PostCommentModel>[...updatedReplies, reply],
        replyCount: comment.replyCount + 1,
      );
    }

    return comment.copyWith(replies: updatedReplies);
  }

  void _incrementPostCommentCount() {
    _adjustPostCommentCount(1);
  }

  void _adjustPostCommentCount(int delta) {
    final current = _countFromDisplay(post.value.comments);
    final next = (current + delta).clamp(0, 1 << 30).toInt();
    final updatedPost = post.value.copyWith(comments: _formatCount(next));
    post.value = updatedPost;
    _syncHomeFeedPost(updatedPost);
  }

  int _removeCommentFromUi(String id) {
    var removed = 0;
    final remaining = <PostCommentModel>[];
    for (final comment in comments) {
      if (comment.id == id) {
        removed += _commentTreeSize(comment);
        continue;
      }
      final stripped = _stripReply(comment, id);
      remaining.add(stripped.comment);
      removed += stripped.removedCount;
    }
    comments.assignAll(remaining);
    return removed;
  }

  int _commentTreeSize(PostCommentModel comment) {
    return 1 +
        comment.replies.fold<int>(
          0,
          (sum, reply) => sum + _commentTreeSize(reply),
        );
  }

  _StrippedComment _stripReply(PostCommentModel comment, String id) {
    var removed = 0;
    final kept = <PostCommentModel>[];
    for (final reply in comment.replies) {
      if (reply.id == id) {
        removed += _commentTreeSize(reply);
        continue;
      }
      final nested = _stripReply(reply, id);
      kept.add(nested.comment);
      removed += nested.removedCount;
    }
    return _StrippedComment(
      comment: comment.copyWith(
        replies: kept,
        replyCount:
            (comment.replyCount - removed).clamp(0, comment.replyCount).toInt(),
      ),
      removedCount: removed,
    );
  }

  int _countFromDisplay(String raw) {
    final normalized = raw.trim().toLowerCase();
    if (normalized.endsWith('k')) {
      final parsed = double.tryParse(
        normalized.substring(0, normalized.length - 1),
      );
      return ((parsed ?? 0) * 1000).round();
    }
    if (normalized.endsWith('m')) {
      final parsed = double.tryParse(
        normalized.substring(0, normalized.length - 1),
      );
      return ((parsed ?? 0) * 1000000).round();
    }
    return int.tryParse(normalized) ?? 0;
  }

  String _formatCount(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}m';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return value.toString();
  }

  bool get _hasLocalPendingItems => comments.any(_containsLocalIds);

  bool _containsLocalIds(PostCommentModel comment) {
    if (comment.isLocalPending) {
      return true;
    }
    return comment.replies.any(_containsLocalIds);
  }

  List<String> _commentUsernames(Iterable<PostCommentModel> items) {
    final usernames = <String>[];
    for (final comment in items) {
      usernames.add(comment.user);
      usernames.addAll(_commentUsernames(comment.replies));
    }
    return usernames;
  }

  bool _isLocalCommentId(String id) => id.startsWith('local-');

  bool _isSuccessStatusCode(int statusCode) =>
      statusCode >= 200 && statusCode < 300;

  String _readPushPostId(Map<String, dynamic> payload) {
    final candidates = <dynamic>[
      payload['post_id'],
      payload['entity_id'],
      payload['postId'],
    ];
    for (final value in candidates) {
      final resolved = value?.toString().trim();
      if (resolved != null && resolved.isNotEmpty && resolved != 'null') {
        return resolved;
      }
    }

    final actionUrl = payload['action_url']?.toString().trim() ?? '';
    if (actionUrl.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(actionUrl);
    if (uri == null) {
      return '';
    }
    final postsIndex = uri.pathSegments.indexOf('posts');
    if (postsIndex >= 0 && postsIndex + 1 < uri.pathSegments.length) {
      return uri.pathSegments[postsIndex + 1];
    }
    return '';
  }
}

class _StrippedComment {
  const _StrippedComment({
    required this.comment,
    required this.removedCount,
  });

  final PostCommentModel comment;
  final int removedCount;
}
