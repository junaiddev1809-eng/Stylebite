import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/models/home_post_model.dart';
import '../../reel/controllers/reel_controller.dart';
import '../../reel/models/reel_item_model.dart';
import '../../reports/api/reports_api.dart';
import '../../search/utils/explore_media_mapper.dart';
import '../controllers/restaurant_review_store.dart';
import '../services/post_interaction_store.dart';
import '../utils/like_toggle.dart';
import '../utils/rating_math.dart';
import '../utils/post_detail_open_helper.dart';

class HashtagFeedController extends GetxController {
  HashtagFeedController({required this.tag});

  final String tag;

  static const int _pageSize = 20;
  static const int _maxScanPages = 8;

  final RxList<HomePostModel> posts = <HomePostModel>[].obs;
  final RxMap<String, int> selectedRatings = <String, int>{}.obs;
  final RxSet<String> likeLoadingIds = <String>{}.obs;
  final RxSet<String> saveLoadingIds = <String>{}.obs;
  final RxSet<String> shareLoadingIds = <String>{}.obs;
  final RxSet<String> voteLoadingIds = <String>{}.obs;
  Worker? _interactionWorker;
  final RxBool isInitialLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;

  final ScrollController scrollController = ScrollController();

  String get plainTag => tag.replaceFirst('#', '');

  String? _workingEndpoint;
  int _currentPage = 0;
  bool _isFetching = false;
  final Set<String> _seenIds = <String>{};

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
    _seedFromCaches();
    unawaited(refreshFeed());
  }

  @override
  void onClose() {
    _interactionWorker?.dispose();
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  Future<void> refreshFeed() => _fetch(reset: true);

  Future<void> loadMore() async {
    if (!hasMore.value || isInitialLoading.value) {
      return;
    }
    await _fetch(reset: false);
  }

  Future<void> toggleLike(String postId) async {
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
    await _runPostAction(
      loadingSet: shareLoadingIds,
      postId: postId,
      endpoint: 'feed/posts/$postId/share',
      body: <String, dynamic>{'share_channel': shareChannel},
    );
  }

  Future<void> votePost(String postId, int rating) async {
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
      posts.removeWhere((post) => post.id == postId);
      _seenIds.remove(postId);
      if (Get.isRegistered<HomeController>()) {
        Get.find<HomeController>().removePost(postId);
      }
      successSnackBar(
        message: (payload['message'] ?? 'Post deleted successfully.')
            .toString(),
      );
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

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
      _seenIds.remove(postId);
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
      posts.removeWhere(
        (post) =>
            post.profileUsername.trim().replaceFirst('@', '').toLowerCase() ==
                normalized.toLowerCase() ||
            post.username.trim().replaceFirst('@', '').toLowerCase() ==
                normalized.toLowerCase(),
      );
      if (Get.isRegistered<HomeController>()) {
        final home = Get.find<HomeController>();
        final blockedIds = home.visiblePosts
            .where(
              (post) =>
                  post.profileUsername
                          .trim()
                          .replaceFirst('@', '')
                          .toLowerCase() ==
                      normalized.toLowerCase() ||
                  post.username.trim().replaceFirst('@', '').toLowerCase() ==
                      normalized.toLowerCase(),
            )
            .map((post) => post.id)
            .toList(growable: false);
        for (final id in blockedIds) {
          home.removePost(id);
        }
      }
      successSnackBar(
        message: (payload['message'] ?? 'User blocked successfully.')
            .toString(),
      );
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> refreshPost(String postId) => _refreshPost(postId);

  void _seedFromCaches() {
    final matches = <HomePostModel>[];
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      matches.addAll(
        [
          ...home.visiblePosts,
          ...home.cachedPostsFor(HomeFeedType.style),
          ...home.cachedPostsFor(HomeFeedType.bite),
        ].where((post) => post.containsHashtag(tag)),
      );
    }
    if (Get.isRegistered<ReelController>()) {
      final reels = Get.find<ReelController>();
      matches.addAll(
        [
          ...reels.cachedReelsFor(ReelFeedType.style),
          ...reels.cachedReelsFor(ReelFeedType.bite),
        ].map((reel) => reel.toHomePost()).where(
          (post) => post.containsHashtag(tag),
        ),
      );
    }
    if (matches.isEmpty) {
      return;
    }
    _appendPosts(
      ExploreMediaMapper.rankForExplore(posts: matches, reels: const []),
      replace: true,
    );
  }

  Future<void> _fetch({required bool reset}) async {
    if (_isFetching) {
      return;
    }
    _isFetching = true;
    if (reset) {
      isInitialLoading.value = posts.isEmpty;
      hasError.value = false;
      errorMessage.value = '';
      _currentPage = 0;
      hasMore.value = true;
      _seenIds.clear();
      posts.clear();
      _seedFromCaches();
    } else {
      isLoadingMore.value = true;
    }

    try {
      var page = reset ? 1 : _currentPage + 1;
      var scanned = 0;
      var more = true;

      while (scanned < _maxScanPages && more) {
        scanned += 1;
        final observedAt = PostInteractionStore.ensure().observedClock;
        final result = await _fetchPage(page);
        final reels = await _fetchMatchingReels(page);
        page = result.page;
        more = result.hasMore || reels.hasMore;
        final additions = _appendPosts(
          [...result.posts, ...reels.posts],
          replace: false,
          observedAt: observedAt,
        );
        _currentPage = page;
        hasMore.value = more;
        if (additions > 0 || !reset || !more) {
          break;
        }
        page += 1;
      }
      _publishExploreMix();
    } catch (error) {
      hasError.value = posts.isEmpty;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      if (posts.isNotEmpty) {
        errorSnackBar(message: errorMessage.value);
      }
    } finally {
      isInitialLoading.value = false;
      isLoadingMore.value = false;
      _isFetching = false;
    }
  }

  Future<_HashtagPageResult> _fetchPage(int page) async {
    final endpoints = _endpointsFor(page);
    Object? lastError;
    for (final endpoint in endpoints) {
      try {
        final result = await _requestPage(endpoint, page);
        _workingEndpoint = endpoint;
        return result;
      } catch (error) {
        lastError = error;
        if (error is _HashtagHttpException && error.statusCode != 404) {
          rethrow;
        }
      }
    }
    throw lastError ?? Exception('Unable to load hashtag posts.');
  }

  List<String> _endpointsFor(int page) {
    final encoded = Uri.encodeComponent(plainTag);
    final hashed = Uri.encodeComponent(tag);
    if (_workingEndpoint != null) {
      return <String>[_withPage(_workingEndpoint!, page)];
    }
    return <String>[
      'feed/hashtags/$encoded?page=$page&per_page=$_pageSize',
      'feed/tags/$encoded?page=$page&per_page=$_pageSize',
      'feed/home?discover_type=for_you&page=$page&per_page=$_pageSize&tag=$encoded&hashtag=$encoded&q=$hashed',
      'feed/home?type=outfit&discover_type=for_you&page=$page&per_page=$_pageSize&tag=$encoded&hashtag=$encoded&q=$hashed',
      'feed/home?type=food&discover_type=for_you&page=$page&per_page=$_pageSize&tag=$encoded&hashtag=$encoded&q=$hashed',
    ];
  }

  String _withPage(String endpoint, int page) {
    final uri = Uri.parse(endpoint.contains('://') ? endpoint : 'https://dummy/$endpoint');
    final params = Map<String, String>.from(uri.queryParameters);
    params['page'] = '$page';
    final path = endpoint.split('?').first;
    return '$path?${Uri(queryParameters: params).query}';
  }

  Future<_HashtagPageResult> _requestPage(String endpoint, int page) async {
    await ContestEnrollmentStore.instance.ensureLoaded();
    final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
    if (response == null) {
      throw const _HashtagHttpException('No response from server.', 0);
    }
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw _HashtagHttpException('Invalid server response.', response.statusCode);
    }
    if (response.statusCode == 404) {
      throw _HashtagHttpException(
        (payload['message'] ?? 'Not found').toString(),
        404,
      );
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['status_code'] != 1) {
      throw _HashtagHttpException(
        (payload['message'] ?? 'Unable to load hashtag posts.').toString(),
        response.statusCode,
      );
    }

    final parsed = [
      ..._parsePosts(payload),
      ..._parseReels(payload),
    ];
    final matched = parsed.where((post) => post.containsHashtag(tag)).toList(
      growable: false,
    );
    // Dedicated hashtag endpoints may already be filtered and omit tag fields.
    final dedicated =
        endpoint.contains('/hashtags/') || endpoint.contains('/tags/');
    final postsToUse = matched.isNotEmpty || !dedicated ? matched : parsed;
    return _HashtagPageResult(
      posts: postsToUse,
      hasMore: _readHasMore(payload),
      page: _readPage(payload, page),
    );
  }

  List<HomePostModel> _parsePosts(Map<String, dynamic> payload) {
    final raw = payload['feed'] ??
        payload['posts'] ??
        payload['data'] ??
        payload['results'];
    if (raw is Map<String, dynamic>) {
      return _parsePosts(raw);
    }
    if (raw is! List) {
      return const <HomePostModel>[];
    }
    return raw
        .whereType<Map>()
        .map(
          (item) {
            final json = item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            return HomePostModel.fromJson(
              json,
              responseType: (json['post_type'] ??
                      json['type'] ??
                      payload['type'] ??
                      '')
                  .toString(),
            );
          },
        )
        .toList(growable: false);
  }

  List<HomePostModel> _parseReels(Map<String, dynamic> payload) {
    final raw = payload['reels'];
    if (raw is! List) {
      return const <HomePostModel>[];
    }
    final responseType = (payload['type'] ?? '').toString();
    return raw
        .whereType<Map>()
        .map(
          (item) {
            final json = item.map(
              (key, value) => MapEntry(key.toString(), value),
            );
            return ReelItemModel.fromJson(
              json,
              responseType: (json['post_type'] ?? json['type'] ?? responseType)
                  .toString(),
            ).toHomePost();
          },
        )
        .toList(growable: false);
  }

  Future<_HashtagPageResult> _fetchMatchingReels(int page) async {
    final encoded = Uri.encodeComponent(plainTag);
    final hashed = Uri.encodeComponent(tag);
    final collected = <HomePostModel>[];
    var hasMore = false;
    for (final type in const ['outfit', 'food']) {
      final parsed = await _tryFetchReels(
        'reels?type=$type&page=$page&sort=trending&tag=$encoded&hashtag=$encoded&q=$hashed',
      );
      final fallback = parsed ??
          await _tryFetchReels('reels?type=$type&page=$page&sort=trending');
      if (fallback == null) {
        continue;
      }
      hasMore = hasMore || fallback.pagination.hasMorePages;
      collected.addAll(
        fallback.reels
            .map((reel) => reel.toHomePost())
            .where((post) => post.containsHashtag(tag)),
      );
    }
    return _HashtagPageResult(
      posts: collected,
      hasMore: hasMore,
      page: page,
    );
  }

  Future<ReelResponse?> _tryFetchReels(String endpoint) async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (payload['status_code'] != 1 && payload['status_code'] != '1') {
        return null;
      }
      return ReelResponse.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  void _publishExploreMix() {
    if (posts.isEmpty) {
      return;
    }
    final photos = <HomePostModel>[];
    final videos = <HomePostModel>[];
    for (final post in posts) {
      if (post.mediaType == HomeMediaType.video) {
        videos.add(post);
      } else {
        photos.add(post);
      }
    }
    posts.assignAll(
      ExploreMediaMapper.rankForExplore(posts: photos, reels: videos),
    );
  }

  bool _readHasMore(Map<String, dynamic> payload) {
    final pagination = payload['pagination'];
    if (pagination is Map) {
      final hasMore = pagination['has_more_pages'] ?? pagination['has_more'];
      if (hasMore is bool) {
        return hasMore;
      }
      final current = int.tryParse('${pagination['current_page'] ?? ''}') ?? 0;
      final last = int.tryParse('${pagination['last_page'] ?? ''}') ?? 0;
      if (current > 0 && last > 0) {
        return current < last;
      }
    }
    return false;
  }

  int _readPage(Map<String, dynamic> payload, int fallback) {
    final pagination = payload['pagination'];
    if (pagination is Map) {
      return int.tryParse('${pagination['current_page'] ?? ''}') ?? fallback;
    }
    return fallback;
  }

  int _appendPosts(
    List<HomePostModel> incoming, {
    required bool replace,
    int? observedAt,
  }) {
    final store = PostInteractionStore.ensure();
    final hydrated = incoming
        .map(
          (post) => observedAt == null
              ? store.presentHome(post)
              : store.ingestHome(post, observedAt: observedAt),
        )
        .toList(growable: false);
    if (replace) {
      _seenIds
        ..clear()
        ..addAll(hydrated.map((post) => post.id));
      posts.assignAll(hydrated);
      for (final post in hydrated) {
        selectedRatings[post.id] =
            selectedRatings[post.id] ?? post.defaultSelectedRate;
      }
      RestaurantReviewStore.instance.ingestPosts(hydrated);
      return hydrated.length;
    }

    final additions = hydrated
        .where((post) => _seenIds.add(post.id))
        .toList(growable: false);
    if (additions.isEmpty) {
      return 0;
    }
    posts.addAll(additions);
    for (final post in additions) {
      selectedRatings[post.id] =
          selectedRatings[post.id] ?? post.defaultSelectedRate;
    }
    RestaurantReviewStore.instance.ingestPosts(additions);
    return additions.length;
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    if (scrollController.position.extentAfter < 500) {
      unawaited(loadMore());
    }
  }

  HomePostModel? _findPost(String postId) {
    for (final post in posts) {
      if (post.id == postId) {
        return post;
      }
    }
    return null;
  }

  void _replacePost(HomePostModel updated) {
    final merged = preferLocalVote(
      incoming: updated,
      selected: selectedRatings[updated.id],
      local: _findPost(updated.id),
    );
    final index = posts.indexWhere((post) => post.id == merged.id);
    if (index >= 0) {
      posts[index] = merged;
    }
    selectedRatings[merged.id] = merged.defaultSelectedRate;
    if (Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().upsertPost(merged);
    }
  }

  Future<void> _refreshPost(String postId) async {
    final observedAt = PostInteractionStore.ensure().observedClock;
    final updated = await PostDetailOpenHelper.fetchPost(postId);
    if (updated == null) {
      return;
    }
    _replacePost(
      PostInteractionStore.ensure().ingestHome(updated, observedAt: observedAt),
    );
    RestaurantReviewStore.instance.ingestPosts(<HomePostModel>[updated]);
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
}

class _HashtagPageResult {
  const _HashtagPageResult({
    required this.posts,
    required this.hasMore,
    required this.page,
  });

  final List<HomePostModel> posts;
  final bool hasMore;
  final int page;
}

class _HashtagHttpException implements Exception {
  const _HashtagHttpException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}
