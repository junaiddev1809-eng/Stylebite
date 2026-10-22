import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/models/home_post_model.dart';
import '../../post/controllers/restaurant_review_store.dart';
import '../../post/services/post_interaction_store.dart';
import '../../post/utils/like_toggle.dart';
import '../../post/utils/rating_math.dart';
import '../../post/utils/post_detail_open_helper.dart';
import '../../reports/api/reports_api.dart';
import '../../story/story_marker.dart';
import '../models/profile_model.dart';
import '../utils/profile_overview_query.dart';

class ProfilePostsFeedController extends GetxController {
  ProfilePostsFeedController({
    required this.username,
    required this.tab,
    required this.isOwnProfile,
    required this.authorName,
    required this.avatarUrl,
    required List<HomePostModel> initialPosts,
    required String selectedPostId,
    required int initialPage,
    required bool initialHasMore,
  }) : selectedPostId = selectedPostId.obs,
       _currentPage = initialPage {
    final store = PostInteractionStore.ensure();
    posts.assignAll(initialPosts.map(store.presentHome));
    for (final post in posts) {
      store.rememberDraft(SavedPostDraft.fromHome(post));
    }
    hasMore.value = initialHasMore;
    for (final post in initialPosts) {
      selectedRatings[post.id] =
          selectedRatings[post.id] ?? post.defaultSelectedRate;
    }
  }

  static const int _pageSize = 10;

  final String username;
  final ProfileContentTab tab;
  final bool isOwnProfile;
  final String authorName;
  final String avatarUrl;
  final RxString selectedPostId;

  final RxList<HomePostModel> posts = <HomePostModel>[].obs;
  final RxMap<String, int> selectedRatings = <String, int>{}.obs;
  final RxSet<String> likeLoadingIds = <String>{}.obs;
  final RxSet<String> saveLoadingIds = <String>{}.obs;
  final RxSet<String> shareLoadingIds = <String>{}.obs;
  final RxSet<String> voteLoadingIds = <String>{}.obs;
  Worker? _interactionWorker;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;

  final ScrollController scrollController = ScrollController();

  int _currentPage;
  bool _isFetchingMore = false;

  int get currentPage => _currentPage;

  int get selectedIndex {
    final index = posts.indexWhere(
      (post) => post.id == selectedPostId.value,
    );
    return index < 0 ? 0 : index;
  }

  List<HomePostModel> get previousPosts {
    final index = selectedIndex;
    if (index <= 0) {
      return const <HomePostModel>[];
    }
    return posts.sublist(0, index);
  }

  List<HomePostModel> get remainingPosts {
    return posts.sublist(selectedIndex);
  }

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _interactionWorker = ever(PostInteractionStore.ensure().revision, (_) {
      final id = PostInteractionStore.ensure().lastChangedId;
      if (id != null) {
        _applySharedInteraction(id);
      }
    });
    RestaurantReviewStore.instance.ingestPosts(posts);
    unawaited(_hydrateVisiblePosts());
  }

  @override
  void onClose() {
    _interactionWorker?.dispose();
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  bool _isPendingPost(String postId) =>
      PostDetailOpenHelper.isPendingId(postId);

  Future<void> toggleLike(String postId) async {
    if (_isPendingPost(postId)) {
      return;
    }
    final currentPost = _findPost(postId);
    if (currentPost == null) {
      return;
    }
    final shared = PostInteractionStore.ensure().stateFor(postId);
    PostInteractionStore.ensure().toggleLike(
      postId: postId,
      isLiked: shared?.isLiked ?? currentPost.isLiked,
      likeCount: shared?.likeCount ?? parseLikeCount(currentPost.likes),
      isSaved: currentPost.isSaved,
      saveCount: currentPost.saveCount,
    );
  }

  void toggleSave(String postId) {
    if (_isPendingPost(postId)) {
      return;
    }
    final currentPost = _findPost(postId);
    if (currentPost == null) {
      return;
    }
    final shared = PostInteractionStore.ensure().stateFor(postId);
    PostInteractionStore.ensure().toggleSave(
      postId: postId,
      isSaved: shared?.isSaved ?? currentPost.isSaved,
      saveCount: shared?.saveCount ?? currentPost.saveCount,
      isLiked: currentPost.isLiked,
      likeCount: parseLikeCount(currentPost.likes),
      draft: SavedPostDraft.fromHome(currentPost),
    );
  }

  void _applySharedInteraction(String postId) {
    final current = _findPost(postId);
    if (current == null) {
      return;
    }
    _replacePost(PostInteractionStore.ensure().presentHome(current));
  }

  Future<void> sharePost(String postId, {required String shareChannel}) async {
    if (_isPendingPost(postId)) {
      return;
    }
    await _runPostAction(
      loadingSet: shareLoadingIds,
      postId: postId,
      endpoint: 'feed/posts/$postId/share',
      body: <String, dynamic>{'share_channel': shareChannel},
    );
  }

  Future<void> votePost(String postId, int rating) async {
    if (_isPendingPost(postId)) {
      return;
    }
    final previousRating = selectedRatings[postId];
    final previousPost = _findPost(postId);
    if (previousPost == null) {
      return;
    }
    if (previousRating == rating ||
        (previousRating == null && previousPost.defaultSelectedRate == rating)) {
      return;
    }
    selectedRatings[postId] = rating;
    selectedRatings.refresh();
    _replacePost(postWithRating(post: previousPost, rating: rating));
    voteLoadingIds.add(postId);
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'feed/posts/$postId/vote',
        body: <String, dynamic>{'rating_value': rating},
      );
      if (response == null) {
        throw Exception('No response returned from vote endpoint.');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to update post').toString(),
        );
      }
      final current = _findPost(postId) ?? previousPost;
      final confirmed = postFromVotePayload(current, payload);
      if (confirmed != null) {
        _replacePost(confirmed);
      }
      selectedRatings[postId] = rating;
      selectedRatings.refresh();
      unawaited(_refreshPost(postId));
    } catch (error) {
      if (previousRating == null) {
        selectedRatings.remove(postId);
      } else {
        selectedRatings[postId] = previousRating;
      }
      selectedRatings.refresh();
      _replacePost(previousPost);
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      voteLoadingIds.remove(postId);
    }
  }

  Future<void> deletePost(String postId) async {
    if (_isPendingPost(postId)) {
      return;
    }
    try {
      final response = await ApiHelper.deleteRequestWithAuthorization(
        'posts/$postId',
      );
      if (response == null) {
        throw Exception('No response returned from delete endpoint.');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to delete post').toString(),
        );
      }
      final removedIndex = posts.indexWhere((post) => post.id == postId);
      posts.removeWhere((post) => post.id == postId);
      if (selectedPostId.value == postId && posts.isNotEmpty) {
        final nextIndex = removedIndex.clamp(0, posts.length - 1);
        selectedPostId.value = posts[nextIndex].id;
      }
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().removePost(postId);
      }
      successSnackBar(
        message: (payload['message'] ?? 'Post deleted successfully.')
            .toString(),
      );
      if (posts.isEmpty) {
        Get.back<void>();
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> refreshPost(String postId) => _refreshPost(postId);

  Future<void> reportPost(
    String postId, {
    required String reason,
    String? details,
  }) async {
    final targetId = int.tryParse(postId);
    if (targetId == null) {
      errorSnackBar(message: 'Unable to report this post.');
      return;
    }
    try {
      final result = await ReportsApi.submitReport(
        targetType: 'post',
        targetId: targetId,
        reason: reason,
        description: details,
      );
      posts.removeWhere((post) => post.id == postId);
      if (result.alreadyReported) {
        infoSnackBar(
          message: 'You already reported this. Our team is reviewing it.',
        );
      } else {
        successSnackBar(message: 'Post reported. Thanks for letting us know.');
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> blockUser(String targetUsername) async {
    final normalized = targetUsername.trim().replaceFirst('@', '');
    final currentUsername = LocalStorage.getUsername()?.trim().replaceFirst(
      '@',
      '',
    );
    if (normalized.isEmpty ||
        normalized.toLowerCase() == currentUsername?.toLowerCase()) {
      errorSnackBar(message: 'You cannot block yourself.');
      return;
    }

    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'profiles/${Uri.encodeComponent(normalized)}/block',
        body: <String, dynamic>{},
      );
      if (response == null) {
        throw Exception('No response returned from block endpoint.');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to block user').toString(),
        );
      }
      successSnackBar(
        message: (payload['message'] ?? 'User blocked successfully.')
            .toString(),
      );
      Get.back<void>();
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> loadMore() async {
    if (_isFetchingMore ||
        isLoadingMore.value ||
        !hasMore.value ||
        tab == ProfileContentTab.more) {
      return;
    }

    _isFetchingMore = true;
    isLoadingMore.value = true;
    final observedAt = PostInteractionStore.ensure().observedClock;
    try {
      final overview = await _fetchOverviewPage(_currentPage + 1);
      final incoming = _postsFromOverview(overview)
          .map(
            (post) => PostInteractionStore.ensure().ingestHome(
              post,
              observedAt: observedAt,
            ),
          )
          .toList(growable: false);
      final existingIds = posts.map((post) => post.id).toSet();
      final additions = incoming
          .where((post) => !existingIds.contains(post.id))
          .toList(growable: false);
      if (additions.isNotEmpty) {
        posts.addAll(additions);
        for (final post in additions) {
          selectedRatings[post.id] =
              selectedRatings[post.id] ?? post.defaultSelectedRate;
        }
        RestaurantReviewStore.instance.ingestPosts(additions);
        unawaited(_hydratePosts(additions.take(4).map((post) => post.id)));
      }

      final pagination = _paginationFromOverview(overview);
      _currentPage = pagination.currentPage;
      hasMore.value = pagination.hasMorePages;
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isLoadingMore.value = false;
      _isFetchingMore = false;
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    if (scrollController.position.extentAfter < 400) {
      unawaited(loadMore());
    }
  }

  Future<void> _hydrateVisiblePosts() async {
    final start = math.max(0, selectedIndex - 1);
    final ids = posts.skip(start).take(5).map((post) => post.id);
    await _hydratePosts(ids);
  }

  Future<void> _hydratePosts(Iterable<String> ids) async {
    for (final id in ids) {
      await _refreshPost(id);
    }
  }

  Future<void> _refreshPost(String postId) async {
    if (_isPendingPost(postId)) {
      return;
    }
    final observedAt = PostInteractionStore.ensure().observedClock;
    final updated = await PostDetailOpenHelper.fetchPost(postId);
    if (updated == null) {
      return;
    }
    final merged = _replacePost(
      PostInteractionStore.ensure().ingestHome(updated, observedAt: observedAt),
    );
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().upsertPost(merged);
    }
    RestaurantReviewStore.instance.ingestPosts(<HomePostModel>[merged]);
  }

  Future<void> _runPostAction({
    required RxSet<String> loadingSet,
    required String postId,
    required String endpoint,
    Map<String, dynamic>? body,
  }) async {
    if (loadingSet.contains(postId)) {
      return;
    }
    loadingSet.add(postId);
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        endpoint,
        body: body,
      );
      if (response == null) {
        return;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to update post').toString(),
        );
      }
      unawaited(_refreshPost(postId));
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      loadingSet.remove(postId);
    }
  }

  Future<ProfileOverviewModel> _fetchOverviewPage(int page) async {
    final pages = profileSectionPages(tab, page);
    final params = profileOverviewQuery(
      outfitPage: pages.outfitPage,
      foodPage: pages.foodPage,
      savedPage: pages.savedPage,
      perPage: _pageSize,
    );

    final path = isOwnProfile
        ? 'profile/me/overview'
        : 'profiles/${Uri.encodeComponent(username)}/overview';
    final uri = Uri(path: path, queryParameters: params);
    await ContestEnrollmentStore.instance.ensureLoaded();
    final response = await ApiHelper.fetchDataWithAuthorization(uri.toString());
    if (response == null) {
      throw Exception('Unable to load more posts.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (payload.containsKey('status_code') && payload['status_code'] != 1)) {
      throw Exception(
        (payload['message'] ?? 'Unable to load more posts').toString(),
      );
    }
    return ProfileOverviewResponseModel.fromMap(payload).overview;
  }

  List<HomePostModel> _postsFromOverview(ProfileOverviewModel overview) {
    final source = switch (tab) {
      ProfileContentTab.outfits => overview.outfitPosts,
      ProfileContentTab.food => overview.foodPosts,
      ProfileContentTab.saved =>
        overview.savedPosts.map((item) => item.post).toList(growable: false),
      ProfileContentTab.more => const <ProfilePostModel>[],
    };
    return source
        .where(
          (post) => !StoryMarker.isStory(tags: post.tags, caption: post.caption),
        )
        .map(
          (post) => post.toHomePostModel(
            username: username,
            avatarUrl: avatarUrl,
            profileUsername: username,
            authorName: authorName,
          ),
        )
        .toList(growable: false);
  }

  ProfilePaginationModel _paginationFromOverview(ProfileOverviewModel overview) {
    return switch (tab) {
      ProfileContentTab.outfits => overview.outfitPagination,
      ProfileContentTab.food => overview.foodPagination,
      ProfileContentTab.saved => overview.savedPagination,
      ProfileContentTab.more => overview.outfitPagination,
    };
  }

  HomePostModel? _findPost(String postId) {
    for (final post in posts) {
      if (post.id == postId) {
        return post;
      }
    }
    return null;
  }

  HomePostModel _replacePost(HomePostModel updatedPost) {
    final merged = preferLocalVote(
      incoming: updatedPost,
      selected: selectedRatings[updatedPost.id],
      local: _findPost(updatedPost.id),
    );
    final index = posts.indexWhere((post) => post.id == merged.id);
    if (index == -1) {
      return merged;
    }
    posts[index] = merged;
    selectedRatings[merged.id] = merged.defaultSelectedRate;
    posts.refresh();
    return merged;
  }
}
