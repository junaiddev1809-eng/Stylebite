import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/reel_ready_service.dart';
import '../../../core/ranking/trending_ranker.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/app_location_service.dart';
import '../../../core/utils/local_storage.dart';
import '../../reports/api/reports_api.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../../post/controllers/restaurant_review_store.dart';
import '../../post/services/post_interaction_store.dart';
import '../../post/utils/like_toggle.dart';
import '../../reel/controllers/reel_controller.dart';
import '../../reel/models/reel_item_model.dart';
import '../../story/controllers/story_controller.dart';
import '../../story/story_marker.dart';
import '../models/home_battle_model.dart';
import '../models/home_model.dart';
import '../../post/utils/rating_math.dart';
import '../models/home_post_model.dart';

enum HomeDiscoverType { forYou, nearby }

class HomeController extends GetxController {
  final Rx<HomeFeedType> selectedFeedType = HomeFeedType.style.obs;
  final Rx<HomeDiscoverType> selectedDiscoverType = HomeDiscoverType.forYou.obs;
  final RxMap<String, int> selectedRatings = <String, int>{}.obs;

  final RxBool isInitialLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasError = false.obs;
  final RxBool hasMore = true.obs;
  final RxList<HomePostModel> visiblePosts = <HomePostModel>[].obs;
  final RxInt feedRevision = 0.obs;
  final Map<String, Rx<HomePostModel>> _postSubjects =
      <String, Rx<HomePostModel>>{};
  List<HomePostModel> _publishedPosts = <HomePostModel>[];
  final Map<HomeFeedType, List<HomePostModel>> _suggestedReelsByFeed =
      <HomeFeedType, List<HomePostModel>>{};
  final RxList<HomeFeedRow> feedRows = <HomeFeedRow>[].obs;

  static const int _suggestAfter = 7;
  static const int _suggestEvery = 10;
  static const int _suggestPerRow = 10;
  static const int _suggestRowPool = 16;

  int get publishedCount => _publishedPosts.length;

  HomePostModel publishedPostAt(int index) => _publishedPosts[index];

  Rx<HomePostModel> watchPost(HomePostModel seed) {
    return _postSubjects.putIfAbsent(seed.id, () => seed.obs);
  }
  final RxSet<String> likeLoadingIds = <String>{}.obs;
  final RxSet<String> saveLoadingIds = <String>{}.obs;
  final RxSet<String> shareLoadingIds = <String>{}.obs;
  final RxSet<String> voteLoadingIds = <String>{}.obs;
  Worker? _interactionWorker;

  // New state to track location permission
  final RxBool isLocationDenied = false.obs;

  final ScrollController scrollController = ScrollController();

  final Map<String, _FeedSessionState> _feedCache =
      <String, _FeedSessionState>{};
  final Map<String, HomePostModel> _localPosts = <String, HomePostModel>{};
  final Map<String, HomePostModel> _pinnedPosts = <String, HomePostModel>{};

  bool _isPendingPost(String postId) =>
      postId.startsWith('local-') || postId.startsWith('-');

  void showLocalPost(HomePostModel post) {
    _localPosts[post.id] = post;
    if (selectedFeedType.value != post.feedType) {
      setFeedType(post.feedType);
      return;
    }
    _publishVisiblePosts(<HomePostModel>[post, ...visiblePosts]);
  }

  void replaceLocalPost(String localId, HomePostModel serverPost) {
    _localPosts.remove(localId);
    _dropPostId(localId);
    _pinnedPosts[serverPost.id] = serverPost;
    if (serverPost.feedType != selectedFeedType.value) {
      return;
    }
    _publishVisiblePosts(List<HomePostModel>.from(visiblePosts));
  }

  void removeLocalPost(String localId) {
    _localPosts.remove(localId);
    _dropPostId(localId);
    _publishVisiblePosts(List<HomePostModel>.from(visiblePosts));
  }

  void _dropPostId(String postId) {
    visiblePosts.removeWhere((post) => post.id == postId);
    _publishedPosts.removeWhere((post) => post.id == postId);
    _postSubjects.remove(postId);
    for (final cache in _feedCache.values) {
      cache.posts.removeWhere((post) => post.id == postId);
      cache.loadedPostIds.remove(postId);
    }
  }
  final Queue<String> _recentMediaUrls = Queue<String>();
  final Completer<void> _firstLoadReady = Completer<void>();

  Future<void> get firstLoadReady => _firstLoadReady.future;

  static HomeController ensureController() {
    if (Get.isRegistered<HomeController>()) {
      return Get.find<HomeController>();
    }
    return Get.put(HomeController(), permanent: true);
  }

  List<HomePostModel> cachedPostsFor(HomeFeedType type) {
    final seen = <String>{};
    final posts = <HomePostModel>[];
    void take(HomePostModel post) {
      final id = post.id.trim();
      if (id.isEmpty || !seen.add(id)) {
        return;
      }
      posts.add(post);
    }

    if (selectedFeedType.value == type) {
      for (final post in visiblePosts) {
        take(post);
      }
    }
    for (final entry in _feedCache.entries) {
      if (!entry.key.startsWith('${type.name}_')) {
        continue;
      }
      for (final post in entry.value.posts) {
        take(post);
      }
    }
    return posts;
  }

  Future<List<HomePostModel>> fetchFeedPosts({
    required HomeFeedType type,
    int page = 1,
    int perPage = 20,
  }) async {
    final typeParam = type == HomeFeedType.style ? 'outfit' : 'food';
    unawaited(ContestEnrollmentStore.instance.ensureLoaded());
    final response = await ApiHelper.fetchDataWithAuthorization(
      'feed/home?type=$typeParam&page=$page&per_page=$perPage&discover_type=for_you',
    );
    if (response == null || response.statusCode != 200) {
      return const <HomePostModel>[];
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      return const <HomePostModel>[];
    }
    final payload = Map<String, dynamic>.from(decoded);
    if (payload['status_code'] != 1 && payload['status_code'] != '1') {
      return const <HomePostModel>[];
    }
    try {
      return HomeFeedResponse.fromJson({
        ...payload,
        'type': typeParam,
      }).feed;
    } catch (_) {
      return const <HomePostModel>[];
    }
  }

  late final HomeModel model = HomeModel(
    userAvatar:
        'https://lh3.googleusercontent.com/aida-public/AB6AXuAmThVWAgF4z9Hf5AQLwepw90x93Oj5GUpSEy6YiaNqal9NyA1AuobSY_6k3Sk-szwdyHipm0XEyvbqDpR1eEf4kGnRVIRIwmkqm90vPeg8BU137w4lBSATx9R1dUTetfJudq84g5jO0lZSegWVfDMdcxGyhoRwyWxzBqLml4bJ4hYj2-VBLipMkXPSTRgcQFADfoHBCQYCs_B7u0TAKlTh2ShT5bqeENwDsAF4UHF_cb3tM_h2I0unJVJOGdzIknYeTHSnzM3iTsaa',
    quickActions: const [
      HomeQuickAction(icon: HeroIcons.magnifyingGlass, showDot: false),
      HomeQuickAction(icon: HeroIcons.bell, showDot: true),
      HomeQuickAction(icon: HeroIcons.chatBubbleOvalLeft, showDot: false),
    ],
    battle: const HomeBattleModel(
      badge: 'Live Now',
      title: 'Neon Street vs.\nPastel Retro',
      buttonLabel: 'Vote & Win',
      previewImageOne:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=400&q=80',
      previewImageTwo:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=80',
      moreLabel: '+42',
    ),
    posts: const [],
  );

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
    refreshFeed();
  }

  @override
  void onClose() {
    _interactionWorker?.dispose();
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  void _applySharedInteraction(String postId) {
    final current = _findPost(postId);
    if (current == null) {
      return;
    }
    _updatePost(PostInteractionStore.ensure().presentHome(current));
  }

  bool _isManualRefreshing = false;

  /// Scrolls the current Style/Bite feed to the top and reloads page 1.
  /// Used when the user taps the Home tab they are already on.
  Future<void> scrollToTop() async {
    if (_isManualRefreshing || isInitialLoading.value) {
      return;
    }
    _isManualRefreshing = true;
    try {
      if (scrollController.hasClients && scrollController.offset > 0) {
        await scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
      _session.scrollOffset = 0;
      await refreshFeed();
    } finally {
      _isManualRefreshing = false;
    }
  }

  Future<void> refreshFeed() async {
    // If visiblePosts is empty, it means we are either on initial load
    // or we just switched to an empty tab. In these cases, show the shimmer.
    final bool isFirstLoad = visiblePosts.isEmpty;
    
    if (isFirstLoad) {
      isInitialLoading.value = true;
    }
    
    hasError.value = false;
    isLocationDenied.value = false;

    // Note: We don't clear visiblePosts here immediately to allow 
    // RefreshIndicator to show its animation smoothly over the old data.
    
    try {
      final cache = _session;
      final staleIds = List<String>.from(cache.loadedPostIds);

      // Fetch page 1 and replace existing data in cache and visible list
      await _fetchPage(page: 1, replaceExisting: true);
      
      // Clean up old ratings that are no longer part of this feed session
      selectedRatings.removeWhere((key, value) => staleIds.contains(key));

      if (isFirstLoad && scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
      if (selectedFeedType.value == HomeFeedType.style) {
        unawaited(StoryController.ensure().load());
      }
    } catch (error) {
      // If we don't have any data yet, we show the Error State UI
      if (visiblePosts.isEmpty) {
        hasError.value = true;
      }
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isInitialLoading.value = false;
      if (!_firstLoadReady.isCompleted) {
        _firstLoadReady.complete();
      }
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value || hasError.value || isLocationDenied.value) {
      return;
    }

    isLoadingMore.value = true;
    try {
      await _fetchPage(page: _session.currentPage + 1);
    } catch (error) {
      hasError.value = true;
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isLoadingMore.value = false;
    }
  }

  void maybeLoadMore(int index) {
    if (index >= visiblePosts.length - 2) {
      loadMore();
    }
  }

  void setFeedType(HomeFeedType value) {
    if (selectedFeedType.value == value) {
      return;
    }
    _persistScrollOffset();
    selectedFeedType.value = value;
    _restoreCachedStateOrFetch();
  }

  void setDiscoverType(HomeDiscoverType value) {
    if (selectedDiscoverType.value == value) {
      return;
    }
    _persistScrollOffset();
    selectedDiscoverType.value = value;
    _restoreCachedStateOrFetch();
  }

  // UI can call this when user clicks "Grant Permission" button
  Future<void> retryLocationPermission() async {
    final hasPermission = await AppLocationService.requestPermission();
    if (hasPermission) {
      isLocationDenied.value = false;
      await refreshFeed();
    }
  }

  void selectRating(String postId, int rating) {
    selectedRatings[postId] = rating;
  }

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

  Future<void> sharePost(
    String postId, {
    required String shareChannel,
    int? targetUserId,
  }) async {
    if (_isPendingPost(postId)) {
      return;
    }
    await _runPostAction(
      loadingSet: shareLoadingIds,
      postId: postId,
      endpoint: 'feed/posts/$postId/share',
      body: <String, dynamic>{
        'share_channel': shareChannel,
        'target_user_id': targetUserId,
      },
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
    _updatePost(postWithRating(post: previousPost, rating: rating));
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
        _updatePost(confirmed);
      }
      selectedRatings[postId] = rating;
      selectedRatings.refresh();
      unawaited(_refreshSinglePost(postId));
    } catch (error) {
      if (previousRating == null) {
        selectedRatings.remove(postId);
      } else {
        selectedRatings[postId] = previousRating;
      }
      selectedRatings.refresh();
      _updatePost(previousPost);
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      voteLoadingIds.remove(postId);
    }
  }

  void upsertPost(HomePostModel updatedPost) {
    _replacePublishedPost(updatedPost);
    for (final cache in _feedCache.values) {
      _replacePostInList(cache.posts, updatedPost);
      cache.loadedPostIds.add(updatedPost.id);
    }
    selectedRatings[updatedPost.id] = updatedPost.defaultSelectedRate;
  }

  void removePost(String postId) {
    visiblePosts.removeWhere((post) => post.id == postId);
    _publishedPosts.removeWhere((post) => post.id == postId);
    _session.posts.removeWhere((post) => post.id == postId);
    _session.loadedPostIds.remove(postId);
    selectedRatings.remove(postId);
    feedRevision.value++;
  }

  void _applyContestEnrollment() {
    if (visiblePosts.isEmpty) {
      return;
    }
    var changed = false;
    final next = <HomePostModel>[];
    for (final post in visiblePosts) {
      final info = ContestEnrollmentStore.instance.infoFor(post.id);
      if (post.ratingEnabled || info == null) {
        next.add(post);
        continue;
      }
      changed = true;
      next.add(
        post.copyWith(
          ratingEnabled: true,
          contestId: info.contestId > 0 ? info.contestId : post.contestId,
          contestTitle: info.contestTitle.trim().isNotEmpty
              ? info.contestTitle
              : post.contestTitle,
        ),
      );
    }
    if (!changed) {
      return;
    }
    _publishVisiblePosts(next);
    _session.posts
      ..clear()
      ..addAll(next);
  }

  /// Turns the rating module on for a post that is already loaded in the
  /// feed (e.g. right after the user enrolls it in a contest).
  void markPostContestEnrolled(
    String postId, {
    int contestId = 0,
    String contestTitle = '',
  }) {
    final existing = _findPost(postId);
    if (existing == null) {
      return;
    }
    final alreadyMarked = existing.ratingEnabled &&
        (contestId <= 0 || existing.contestId == contestId);
    if (alreadyMarked) {
      return;
    }
    upsertPost(
      existing.copyWith(
        ratingEnabled: true,
        contestId: contestId > 0 ? contestId : existing.contestId,
        contestTitle: contestTitle.trim().isNotEmpty
            ? contestTitle.trim()
            : existing.contestTitle,
      ),
    );
  }

  Future<bool> deletePost(String postId) async {
    if (_isPendingPost(postId)) {
      return false;
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
      removePost(postId);
      successSnackBar(
        message: (payload['message'] ?? 'Post deleted successfully.')
            .toString(),
      );
      return true;
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
      return false;
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
      removePost(postId);
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

  Future<void> repostPost(String postId) async {
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'posts/$postId/repost',
      );
      if (response == null) {
        throw Exception('No response returned from repost endpoint.');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to repost post').toString(),
        );
      }
      successSnackBar(
        message: (payload['message'] ?? 'Post reposted successfully.')
            .toString(),
      );
      await _refreshSinglePost(postId);
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> refreshSinglePost(String postId) => _refreshSinglePost(postId);

  Future<void> blockUser(String username, {String? reason}) async {
    final normalized = username.trim().replaceFirst('@', '');
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
        body: reason == null || reason.trim().isEmpty
            ? <String, dynamic>{}
            : <String, dynamic>{'reason': reason.trim()},
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

      _publishVisiblePosts([
        for (final post in _publishedPosts)
          if (!_matchesUsername(post.profileUsername, normalized) &&
              !_matchesUsername(post.username, normalized))
            post,
      ]);
      for (final cache in _feedCache.values) {
        cache.posts.removeWhere(
          (post) =>
              _matchesUsername(post.profileUsername, normalized) ||
              _matchesUsername(post.username, normalized),
        );
        cache.loadedPostIds
          ..clear()
          ..addAll(cache.posts.map((post) => post.id));
      }
      successSnackBar(
        message: (payload['message'] ?? 'User blocked successfully.')
            .toString(),
      );
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _restoreCachedStateOrFetch() async {
    final cache = _session;
    hasError.value = false;
    isLocationDenied.value = false;

    if (cache.posts.isNotEmpty) {
      hasMore.value = cache.hasMore;
      _publishVisiblePosts(cache.posts);
      _restoreScrollOffset(cache.scrollOffset);
    } else {
      // Clear visible list so that the shimmer state is triggered in refreshFeed
      _publishVisiblePosts(const <HomePostModel>[]);
      await refreshFeed();
    }
  }

  Future<void> _fetchPage({
    required int page,
    bool replaceExisting = false,
  }) async {
    double? lat;
    double? lng;

    if (selectedDiscoverType.value == HomeDiscoverType.nearby) {
      // Pehle current permission status check karo
      LocationPermission permission = await Geolocator.checkPermission();
      bool hasPermission = permission == LocationPermission.always || 
                          permission == LocationPermission.whileInUse;
      
      // Agar permission nahi hai aur first page load ho raha hai toh request karo
      if (!hasPermission && page == 1) {
        hasPermission = await AppLocationService.requestPermission();
      }

      if (hasPermission) {
        isLocationDenied.value = false;
        try {
          final position = await Geolocator.getCurrentPosition();
          lat = position.latitude;
          lng = position.longitude;
        } catch (e) {
          // Silent catch
        }
      } else {
        isLocationDenied.value = true;
        if (page == 1) {
          _publishVisiblePosts(const <HomePostModel>[]);
          isInitialLoading.value = false;
          return; // API call skip karo
        }
      }
    } else {
      isLocationDenied.value = false;
    }

    unawaited(
      ContestEnrollmentStore.instance.ensureLoaded().then((_) {
        _applyContestEnrollment();
      }),
    );
    final observedAt = PostInteractionStore.ensure().observedClock;
    final response = await ApiHelper.fetchDataWithAuthorization(
      _buildFeedEndpoint(page, lat: lat, lng: lng),
    );

    if (response == null) {
      throw Exception('No response returned from feed endpoint.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || payload['status_code'] != 1) {
      throw Exception((payload['message'] ?? 'Failed to load feed').toString());
    }

    final parsed = HomeFeedResponse.fromJson(payload);
    final filteredFeed = parsed.feed.where(_matchesCurrentSelection).toList();
    final store = PostInteractionStore.ensure();
    final rankedFeed = (selectedDiscoverType.value == HomeDiscoverType.forYou
            ? TrendingRanker.rankPosts(filteredFeed)
            : filteredFeed)
        .map((post) => store.ingestHome(post, observedAt: observedAt))
        .toList(growable: false);
    final cache = _session;
    final merged = replaceExisting
        ? rankedFeed
        : _mergePosts(cache.posts, rankedFeed);

    cache.posts
      ..clear()
      ..addAll(merged);
    cache.loadedPostIds
      ..clear()
      ..addAll(cache.posts.map((post) => post.id));
    cache.currentPage = parsed.pagination.currentPage;
    cache.hasMore = parsed.pagination.hasMorePages;
    cache.lastSyncedAt = DateTime.now();

    hasMore.value = cache.hasMore;
    _publishVisiblePosts(cache.posts);
    RestaurantReviewStore.instance.ingestPosts(cache.posts);
    _applyContestEnrollment();
    unawaited(_hydrateMissingHashtags(filteredFeed));

    for (final post in filteredFeed) {
      selectedRatings[post.id] =
          selectedRatings[post.id] ?? post.defaultSelectedRate;
      _rememberLoadedMedia(post);
    }
  }

  String _buildFeedEndpoint(int page, {double? lat, double? lng}) {
    final type = selectedFeedType.value == HomeFeedType.style
        ? 'outfit'
        : 'food';
    final discoverType = selectedDiscoverType.value == HomeDiscoverType.forYou
        ? 'for_you'
        : 'nearby';
    
    var endpoint = 'feed/home?type=$type&page=$page&per_page=10&discover_type=$discoverType';
    
    if (selectedDiscoverType.value == HomeDiscoverType.nearby && lat != null && lng != null) {
      endpoint += '&lat=$lat&lng=$lng';
    }
    
    return endpoint;
  }

  bool _matchesCurrentSelection(HomePostModel post) {
    if (StoryMarker.isStory(tags: post.tags, caption: post.caption)) {
      return false;
    }
    if (selectedFeedType.value == HomeFeedType.style) {
      return post.feedType == HomeFeedType.style;
    }
    return post.feedType == HomeFeedType.bite &&
        (post.mediaType == HomeMediaType.image ||
            post.mediaType == HomeMediaType.video);
  }

  List<HomePostModel> _mergePosts(
    List<HomePostModel> existing,
    List<HomePostModel> incoming,
  ) {
    final byId = <String, HomePostModel>{
      for (final post in existing) post.id: post,
    };
    for (final post in incoming) {
      byId[post.id] = post;
    }
    return byId.values.toList(growable: false);
  }

  _FeedSessionState get _session =>
      _feedCache.putIfAbsent(_sessionKey, _FeedSessionState.new);

  String get _sessionKey =>
      '${selectedFeedType.value.name}_${selectedDiscoverType.value.name}';

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    _session.scrollOffset = scrollController.offset;
    if (scrollController.position.extentAfter < 600) {
      loadMore();
    }
  }

  void _persistScrollOffset() {
    if (!scrollController.hasClients) {
      return;
    }
    _session.scrollOffset = scrollController.offset;
  }

  void _restoreScrollOffset(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) {
        return;
      }
      final maxExtent = scrollController.position.maxScrollExtent;
      final target = offset.clamp(0, maxExtent).toDouble();
      scrollController.jumpTo(target);
    });
  }

  void _rememberLoadedMedia(HomePostModel post) {
    final url = post.primaryMediaUrl;
    if (url.isEmpty) {
      return;
    }

    _recentMediaUrls.remove(url);
    _recentMediaUrls.addLast(url);

    while (_recentMediaUrls.length > 10) {
      _recentMediaUrls.removeFirst();
    }
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

      unawaited(_refreshSinglePost(postId));
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      loadingSet.remove(postId);
    }
  }

  Future<void> _hydrateMissingHashtags(List<HomePostModel> incoming) async {
    for (final post in incoming) {
      if (post.tags.isNotEmpty) {
        continue;
      }
      unawaited(_refreshSinglePost(post.id));
    }
  }

  Future<void> _refreshSinglePost(String postId) async {
    final observedAt = PostInteractionStore.ensure().observedClock;
    final response = await ApiHelper.fetchDataWithAuthorization(
      'feed/posts/$postId?comments_page=1',
    );
    if (response == null) {
      return;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 || payload['status_code'] != 1) {
      return;
    }

    final parsed = HomePostModel.fromJson(
      payload['post'] as Map<String, dynamic>? ?? const {},
      responseType:
          ((payload['post'] as Map<String, dynamic>? ??
                      const {})['post_type'] ??
                  '')
              .toString(),
    );
    upsertPost(
      PostInteractionStore.ensure().ingestHome(
        preferLocalVote(
          incoming: parsed,
          selected: selectedRatings[postId],
          local: _findPost(postId),
        ),
        observedAt: observedAt,
      ),
    );
  }

  HomePostModel? _findPost(String postId) {
    for (final post in _publishedPosts) {
      if (post.id == postId) {
        return post;
      }
    }
    for (final post in visiblePosts) {
      if (post.id == postId) {
        return post;
      }
    }

    for (final cache in _feedCache.values) {
      for (final post in cache.posts) {
        if (post.id == postId) {
          return post;
        }
      }
    }

    return null;
  }

  void _updatePost(HomePostModel updatedPost) {
    _replacePublishedPost(updatedPost);
    for (final cache in _feedCache.values) {
      _replacePostInList(cache.posts, updatedPost);
      cache.loadedPostIds.add(updatedPost.id);
    }
  }

  void _publishVisiblePosts(List<HomePostModel> posts) {
    final incomingIds = posts.map((post) => post.id).toSet();
    _pinnedPosts.removeWhere((id, post) => incomingIds.contains(id));
    final locals = _localPosts.values
        .where((post) => post.feedType == selectedFeedType.value)
        .toList(growable: false);
    final pinned = _pinnedPosts.values
        .where(
          (post) =>
              post.feedType == selectedFeedType.value &&
              !incomingIds.contains(post.id),
        )
        .toList(growable: false);
    final merged = <HomePostModel>[
      ...locals,
      ...pinned,
      ...posts.where((post) => !_localPosts.containsKey(post.id)),
    ];
    final store = PostInteractionStore.ensure();
    _publishedPosts = merged.map(store.presentHome).toList(growable: false);
    for (final post in _publishedPosts) {
      _syncPostSubject(post);
    }
    visiblePosts.assignAll(_publishedPosts);
    _rebuildFeedRows();
    unawaited(_loadSuggestedReels());
    feedRevision.value++;
    ReelReadyService.prefetch(
      _publishedPosts
          .where(
            (post) =>
                post.resolvedMediaType == AppMediaType.video ||
                post.mediaType == HomeMediaType.video,
          )
          .map((post) => post.primaryMediaUrl),
    );
  }

  void _replacePublishedPost(HomePostModel updatedPost) {
    _syncPostSubject(updatedPost);
    final publishedIndex = _publishedPosts.indexWhere(
      (post) => post.id == updatedPost.id,
    );
    if (publishedIndex != -1) {
      _publishedPosts[publishedIndex] = updatedPost;
    }
    final visibleIndex = visiblePosts.indexWhere(
      (post) => post.id == updatedPost.id,
    );
    if (visibleIndex != -1) {
      visiblePosts[visibleIndex] = updatedPost;
    }
  }

  void _syncPostSubject(HomePostModel post) {
    final existing = _postSubjects[post.id];
    if (existing == null) {
      _postSubjects[post.id] = post.obs;
      return;
    }
    existing.value = post;
  }

  void _replacePostInList(List<HomePostModel> list, HomePostModel updatedPost) {
    final index = list.indexWhere((item) => item.id == updatedPost.id);
    if (index == -1) {
      return;
    }
    list[index] = updatedPost;
  }

  bool _matchesUsername(String candidate, String normalizedTarget) {
    return candidate.trim().replaceFirst('@', '').toLowerCase() ==
        normalizedTarget.toLowerCase();
  }

  void _rebuildFeedRows() {
    final posts = _publishedPosts;
    final suggestions =
        _suggestedReelsByFeed[selectedFeedType.value] ?? const <HomePostModel>[];
    final rows = <HomeFeedRow>[];
    var slot = 0;
    for (var i = 0; i < posts.length; i++) {
      rows.add(HomeFeedRow.post(posts[i]));
      final count = i + 1;
      final shouldInsert = count == _suggestAfter ||
          (count > _suggestAfter && (count - _suggestAfter) % _suggestEvery == 0);
      if (!shouldInsert || suggestions.isEmpty) {
        continue;
      }
      final start = (slot * _suggestPerRow) % suggestions.length;
      final slice = <HomePostModel>[];
      final used = <String>{};
      for (var n = 0; n < suggestions.length && slice.length < _suggestRowPool; n++) {
        final item = suggestions[(start + n) % suggestions.length];
        if (!used.add(item.id)) {
          continue;
        }
        slice.add(item);
      }
      if (slice.isEmpty) {
        continue;
      }
      rows.add(HomeFeedRow.suggestions(slice));
      slot += 1;
    }
    if (hasMore.value) {
      rows.add(const HomeFeedRow.spinner());
    }
    feedRows.assignAll(rows);
  }

  Future<void> _loadSuggestedReels() async {
    final feedType = selectedFeedType.value;
    final reelType =
        feedType == HomeFeedType.style ? ReelFeedType.style : ReelFeedType.bite;
    final apiType = feedType == HomeFeedType.style ? 'outfit' : 'food';
    final seen = <String>{};
    final collected = <HomePostModel>[];

    void take(HomePostModel post) {
      if (post.id.trim().isEmpty || !seen.add(post.id)) {
        return;
      }
      if (StoryMarker.isStory(tags: post.tags, caption: post.caption)) {
        return;
      }
      collected.add(post.copyWith(feedType: feedType));
    }

    if (Get.isRegistered<ReelController>()) {
      for (final reel in Get.find<ReelController>().cachedReelsFor(reelType)) {
        take(
          reel.toHomePost().copyWith(
            feedType: feedType,
            mediaType: HomeMediaType.video,
          ),
        );
      }
    }

    for (final post in _publishedPosts) {
      if (post.feedType != feedType) {
        continue;
      }
      if (post.mediaType != HomeMediaType.video &&
          post.resolvedMediaType != AppMediaType.video) {
        continue;
      }
      take(post);
    }

    var hasMorePages = true;
    for (var page = 1; page <= 5 && collected.length < _suggestRowPool; page++) {
      if (!hasMorePages && page > 1) {
        break;
      }
      try {
        final response = await ApiHelper.fetchDataWithAuthorization(
          'reels?type=$apiType&page=$page&per_page=24&sort=trending',
        );
        if (response == null || response.statusCode != 200) {
          break;
        }
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        if (payload['status_code'] != 1 && payload['status_code'] != '1') {
          break;
        }
        final parsed = ReelResponse.fromJson(payload);
        hasMorePages = parsed.pagination.hasMorePages;
        for (final reel in parsed.reels) {
          take(
            reel.toHomePost().copyWith(
              feedType: feedType,
              mediaType: HomeMediaType.video,
            ),
          );
        }
      } catch (_) {
        break;
      }
    }

    if (collected.isEmpty) {
      return;
    }
    _suggestedReelsByFeed[feedType] = collected;
    if (selectedFeedType.value == feedType) {
      _rebuildFeedRows();
      ReelReadyService.prefetch(
        collected.take(_suggestPerRow).map((post) => post.primaryMediaUrl),
      );
    }
  }
}

class HomeFeedRow {
  const HomeFeedRow._({
    required this.kind,
    this.post,
    this.reels = const [],
  });

  const HomeFeedRow.post(HomePostModel post)
      : this._(kind: HomeFeedRowKind.post, post: post);

  const HomeFeedRow.suggestions(List<HomePostModel> reels)
      : this._(kind: HomeFeedRowKind.suggestions, reels: reels);

  const HomeFeedRow.spinner() : this._(kind: HomeFeedRowKind.spinner);

  final HomeFeedRowKind kind;
  final HomePostModel? post;
  final List<HomePostModel> reels;
}

enum HomeFeedRowKind { post, suggestions, spinner }

class _FeedSessionState {
  final List<HomePostModel> posts = <HomePostModel>[];
  final Set<String> loadedPostIds = <String>{};
  int currentPage = 0;
  bool hasMore = true;
  double scrollOffset = 0;
  DateTime? lastSyncedAt;
}
