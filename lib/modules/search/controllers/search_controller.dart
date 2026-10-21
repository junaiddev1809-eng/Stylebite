import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/verified_badge_hydrator.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/models/home_post_model.dart';
import '../../post/screens/post_detail_screen.dart';
import '../../post/utils/hashtag_open_helper.dart';
import '../../profile/models/profile_model.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../../reel/controllers/reel_controller.dart';
import '../../reel/models/reel_item_model.dart';
import '../../reel/utils/reel_open_helper.dart';
import '../models/search_user_model.dart';
import '../utils/explore_media_mapper.dart';

class UserSearchController extends GetxController {
  UserSearchController({this.perPage = 20});

  final int perPage;

  final TextEditingController searchTextController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final RxList<SearchUserModel> users = <SearchUserModel>[].obs;
  final RxList<HomePostModel> exploreItems = <HomePostModel>[].obs;
  final RxList<HomePostModel> personMedia = <HomePostModel>[].obs;
  final RxList<HomePostModel> relatedMedia = <HomePostModel>[].obs;
  final RxBool isInitialLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isExploreLoading = false.obs;
  final RxBool isExploreLoadingMore = false.obs;
  final RxBool isMediaLoading = false.obs;
  final RxBool hasMore = false.obs;
  final RxBool exploreHasMore = false.obs;
  final RxBool hasError = false.obs;
  final RxBool exploreHasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString exploreErrorMessage = ''.obs;
  final RxString query = ''.obs;
  final RxString mediaOwnerUsername = ''.obs;

  Timer? _debounce;
  int _currentPage = 0;
  int _explorePage = 0;
  int _requestSeq = 0;
  bool _usingBrowseFallback = false;
  String? _pendingOpenUsername;
  bool _hasAutoOpenedProfile = false;
  bool _exploreHasMorePosts = false;
  bool _exploreHasMoreReels = false;
  bool _exploreRefreshInFlight = false;
  final List<HomePostModel> _explorePosts = <HomePostModel>[];
  final List<HomePostModel> _exploreReels = <HomePostModel>[];

  static const int _maxScanPages = 8;
  static const int _explorePerPage = 18;

  bool get isSearching => _normalizeQuery(query.value).isNotEmpty;

  bool get isHashtagSearch => HashtagOpenHelper.tagFromQuery(query.value) != null;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
  }

  @override
  void onClose() {
    _debounce?.cancel();
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    searchTextController.dispose();
    super.onClose();
  }

  void resetIdle({bool clearText = true}) {
    _debounce?.cancel();
    _requestSeq++;
    _usingBrowseFallback = false;
    _currentPage = 0;
    hasMore.value = false;
    hasError.value = false;
    errorMessage.value = '';
    isInitialLoading.value = false;
    isLoadingMore.value = false;
    isMediaLoading.value = false;
    users.clear();
    personMedia.clear();
    relatedMedia.clear();
    mediaOwnerUsername.value = '';
    query.value = '';
    if (clearText) {
      searchTextController.clear();
    }
    unawaited(loadExplore(reset: true, seq: _requestSeq));
  }

  void ensureExplore() {
    _debounce?.cancel();
    _requestSeq++;
    _usingBrowseFallback = false;
    query.value = '';
    if (searchTextController.text.isNotEmpty) {
      searchTextController.clear();
    }
    users.clear();
    personMedia.clear();
    relatedMedia.clear();
    mediaOwnerUsername.value = '';
    isInitialLoading.value = false;
    isMediaLoading.value = false;
    hasError.value = false;
    exploreHasError.value = false;
    if (exploreItems.isEmpty) {
      _seedExploreFromHome();
    }
    isExploreLoading.value = exploreItems.isEmpty;
    unawaited(loadExplore(reset: true, seq: _requestSeq));
  }

  void cancelInFlight() {
    _debounce?.cancel();
    _requestSeq++;
    _exploreRefreshInFlight = false;
    isExploreLoading.value = false;
    isExploreLoadingMore.value = false;
  }

  void onQueryChanged(String value) {
    final normalized = _normalizeQuery(value);
    final wasSearching = isSearching;
    query.value = value;
    _pendingOpenUsername = null;
    _hasAutoOpenedProfile = false;
    _debounce?.cancel();

    if (normalized.isEmpty) {
      if (!wasSearching) {
        return;
      }
      resetIdle(clearText: false);
      return;
    }

    users.clear();
    personMedia.clear();
    relatedMedia.clear();
    mediaOwnerUsername.value = '';
    hasError.value = false;
    isInitialLoading.value = true;
    isMediaLoading.value = true;

    _debounce = Timer(const Duration(milliseconds: 280), () {
      searchUsers(reset: true);
    });
  }

  Future<void> refreshSearch() async {
    if (_normalizeQuery(query.value).isEmpty) {
      await loadExplore(reset: true);
      return;
    }
    await searchUsers(reset: true);
  }

  void configure({String? initialQuery, bool autoOpenProfile = false}) {
    if (initialQuery == null || initialQuery.trim().isEmpty) {
      resetIdle();
      return;
    }

    final normalized = _extractProfileUsername(initialQuery.trim());
    query.value = normalized;
    searchTextController.text = normalized;
    _pendingOpenUsername = autoOpenProfile ? normalized.toLowerCase() : null;
    _hasAutoOpenedProfile = false;
    users.clear();
    personMedia.clear();
    relatedMedia.clear();
    mediaOwnerUsername.value = '';
    searchUsers(reset: true);
  }

  void openMedia(HomePostModel post) {
    if (ReelOpenHelper.isReel(post)) {
      ReelOpenHelper.openFromPost(post);
      return;
    }
    Get.to<void>(() => PostDetailScreen(post: post));
  }

  Future<void> loadExplore({required bool reset, int? seq}) async {
    if (_normalizeQuery(query.value).isNotEmpty) {
      return;
    }

    final token = seq ?? (reset ? ++_requestSeq : _requestSeq);
    if (reset) {
      _exploreRefreshInFlight = true;
      _explorePosts.clear();
      _exploreReels.clear();
      _seedExploreFromHome();
      isExploreLoading.value = exploreItems.isEmpty;
      exploreHasError.value = false;
      exploreErrorMessage.value = '';
      isExploreLoadingMore.value = false;
      _explorePage = 0;
      _exploreHasMorePosts = true;
      _exploreHasMoreReels = true;
      exploreHasMore.value = true;
    } else {
      if (_exploreRefreshInFlight ||
          isExploreLoadingMore.value ||
          isExploreLoading.value ||
          !exploreHasMore.value) {
        return;
      }
      isExploreLoadingMore.value = true;
    }

    try {
      final nextPage = _explorePage + 1;
      final results = await Future.wait<Object?>([
        _tryFetchFeed(
          'feed/home?type=outfit&discover_type=for_you&page=$nextPage&per_page=$_explorePerPage',
        ),
        _tryFetchReels('reels?type=outfit&page=$nextPage'),
        if (reset)
          _tryFetchFeed(
            'feed/home?type=outfit&discover_type=trending&page=1&per_page=$_explorePerPage',
          ),
        if (reset)
          _tryFetchFeed(
            'feed/home?type=outfit&discover_type=for_you&page=2&per_page=$_explorePerPage',
          ),
        if (reset) _tryFetchReels('reels?type=outfit&sort=trending&page=1'),
      ]);
      if (token != _requestSeq || _normalizeQuery(query.value).isNotEmpty) {
        return;
      }

      _commitExploreResults(
        reset: reset,
        nextPage: nextPage,
        primaryFeed: results[0] as HomeFeedResponse?,
        primaryReels: results[1] as ReelResponse?,
        extraFeeds: [
          for (var i = 2; i < results.length; i++)
            if (results[i] is HomeFeedResponse) results[i]! as HomeFeedResponse,
        ],
        extraReels: [
          for (var i = 2; i < results.length; i++)
            if (results[i] is ReelResponse) results[i]! as ReelResponse,
        ],
      );
    } catch (error) {
      if (token != _requestSeq) {
        return;
      }
      if (exploreItems.isEmpty) {
        exploreHasError.value = true;
        exploreErrorMessage.value = error.toString().replaceFirst(
          'Exception: ',
          '',
        );
      } else {
        errorSnackBar(
          message: error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (token == _requestSeq) {
        isExploreLoading.value = false;
        isExploreLoadingMore.value = false;
        _exploreRefreshInFlight = false;
      }
    }
  }

  Future<void> searchUsers({required bool reset}) async {
    final hashtag = HashtagOpenHelper.tagFromQuery(query.value);
    if (hashtag != null) {
      await _searchHashtag(hashtag, reset: reset);
      return;
    }

    final normalizedQuery = _normalizeQuery(query.value);
    if (normalizedQuery.isEmpty) {
      resetIdle(clearText: false);
      return;
    }

    final seq = ++_requestSeq;
    _exploreRefreshInFlight = false;

    if (reset) {
      isInitialLoading.value = true;
      isMediaLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';
      _currentPage = 0;
      hasMore.value = false;
      _usingBrowseFallback = false;
      personMedia.clear();
      relatedMedia.clear();
      mediaOwnerUsername.value = '';
    } else {
      if (isLoadingMore.value || !hasMore.value || isInitialLoading.value) {
        return;
      }
      isLoadingMore.value = true;
    }

    try {
      final collected = <SearchUserModel>[if (!reset) ...users];

      if (reset) {
        await _collectMatches(
          query: normalizedQuery,
          seq: seq,
          collected: collected,
          startPage: 1,
          browse: false,
          maxPages: 3,
        );
        if (seq != _requestSeq) {
          return;
        }

        if (collected.isEmpty) {
          final firstToken = normalizedQuery.split(RegExp(r'\s+')).first;
          if (firstToken != normalizedQuery) {
            await _collectMatches(
              query: firstToken,
              matchQuery: normalizedQuery,
              seq: seq,
              collected: collected,
              startPage: 1,
              browse: false,
              maxPages: 3,
            );
          }
        }

        if (seq != _requestSeq) {
          return;
        }

        if (collected.isEmpty) {
          _usingBrowseFallback = true;
          await _collectMatches(
            query: '',
            matchQuery: normalizedQuery,
            seq: seq,
            collected: collected,
            startPage: 1,
            browse: true,
          );
        }

        if (seq != _requestSeq) {
          return;
        }

        if (collected.isEmpty) {
          final direct = await _lookupExactUsername(normalizedQuery);
          if (direct != null) {
            collected.add(direct);
            hasMore.value = false;
          }
        }
      } else {
        await _collectMatches(
          query: _usingBrowseFallback ? '' : normalizedQuery,
          matchQuery: normalizedQuery,
          seq: seq,
          collected: collected,
          startPage: _currentPage + 1,
          browse: _usingBrowseFallback,
          maxPages: _usingBrowseFallback ? 4 : 2,
        );
      }

      if (seq != _requestSeq) {
        return;
      }

      final ranked = _dedupeAndSort(collected, normalizedQuery);
      users.assignAll(ranked);
      VerifiedBadgeHydrator.hydrate(users.map((user) => user.username));
      _maybeAutoOpenProfile();

      if (reset) {
        isInitialLoading.value = false;
        unawaited(
          _loadSearchMedia(
            needle: normalizedQuery,
            seq: seq,
            matchedUsers: ranked,
          ),
        );
      }
    } catch (error) {
      if (seq != _requestSeq) {
        return;
      }
      hasError.value = true;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      if (!reset) {
        errorSnackBar(message: errorMessage.value);
      }
      if (reset) {
        unawaited(
          _loadSearchMedia(
            needle: normalizedQuery,
            seq: seq,
            matchedUsers: const [],
          ),
        );
      }
    } finally {
      if (seq == _requestSeq) {
        if (reset) {
          isInitialLoading.value = false;
        } else {
          isLoadingMore.value = false;
        }
      }
    }
  }

  Future<void> _searchHashtag(String tag, {required bool reset}) async {
    if (!reset) {
      return;
    }

    final seq = ++_requestSeq;
    _exploreRefreshInFlight = false;
    users.clear();
    personMedia.clear();
    relatedMedia.clear();
    mediaOwnerUsername.value = '';
    isInitialLoading.value = false;
    isMediaLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';
    hasMore.value = false;

    try {
      final collected = <HomePostModel>[];
      if (Get.isRegistered<HomeController>()) {
        collected.addAll(
          Get.find<HomeController>().visiblePosts.where(
            (post) => _isStylePost(post) && post.containsHashtag(tag),
          ),
        );
      }
      if (Get.isRegistered<ReelController>()) {
        collected.addAll(
          Get.find<ReelController>()
              .cachedReelsFor(ReelFeedType.style)
              .map(ExploreMediaMapper.fromReel)
              .where((post) => post.containsHashtag(tag)),
        );
      }
      if (collected.isNotEmpty) {
        relatedMedia.assignAll(ExploreMediaMapper.dedupe(collected));
      }

      final encoded = Uri.encodeComponent(tag.replaceFirst('#', ''));
      final hashed = Uri.encodeQueryComponent(tag);
      final endpoints = <String>[
        'feed/hashtags/$encoded?page=1&per_page=$_explorePerPage',
        'feed/tags/$encoded?page=1&per_page=$_explorePerPage',
        'feed/home?type=outfit&discover_type=for_you&page=1&per_page=$_explorePerPage&tag=$encoded&hashtag=$encoded&q=$hashed',
        'search/posts?type=outfit&page=1&per_page=$_explorePerPage&q=$hashed',
      ];

      for (final endpoint in endpoints) {
        if (seq != _requestSeq) {
          return;
        }
        final parsed = await _tryFetchFeed(endpoint);
        if (parsed == null) {
          continue;
        }
        final dedicated =
            endpoint.contains('/hashtags/') || endpoint.contains('/tags/');
        collected.addAll(
          parsed.feed.where((post) {
            if (!_isStylePost(post)) {
              return false;
            }
            return dedicated || post.containsHashtag(tag);
          }),
        );
        if (ExploreMediaMapper.dedupe(collected).length >= 12) {
          break;
        }
      }

      if (seq != _requestSeq) {
        return;
      }

      final reels = await _tryFetchReels('reels?type=outfit&page=1&sort=trending');
      if (seq != _requestSeq) {
        return;
      }
      if (reels != null) {
        collected.addAll(
          reels.reels
              .map(ExploreMediaMapper.fromReel)
              .where((post) => post.containsHashtag(tag)),
        );
      }

      relatedMedia.assignAll(
        ExploreMediaMapper.rankForExplore(
          posts: ExploreMediaMapper.dedupe(collected).where(_isStylePost).toList(),
          reels: const [],
        ),
      );
    } catch (error) {
      if (seq != _requestSeq) {
        return;
      }
      if (relatedMedia.isEmpty) {
        hasError.value = true;
        errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      }
    } finally {
      if (seq == _requestSeq) {
        isMediaLoading.value = false;
        isInitialLoading.value = false;
      }
    }
  }

  Future<void> _loadSearchMedia({
    required String needle,
    required int seq,
    required List<SearchUserModel> matchedUsers,
  }) async {
    isMediaLoading.value = true;
    try {
      SearchUserModel? owner;
      for (final user in matchedUsers) {
        final rank = user.prefixRank(needle);
        if (rank >= 0 && rank <= 3) {
          owner = user;
          break;
        }
      }

      if (owner != null) {
        mediaOwnerUsername.value = owner.username;
      }

      await Future.wait<void>([
        if (owner != null) _fetchPersonMedia(owner, seq),
        _fetchRelatedMedia(
          needle: needle,
          seq: seq,
          ownerUsername: owner?.username,
        ),
      ]);
    } finally {
      if (seq == _requestSeq) {
        isMediaLoading.value = false;
      }
    }
  }

  Future<void> _fetchPersonMedia(SearchUserModel owner, int seq) async {
    try {
      final overview = await _fetchProfileOverview(owner.username);
      if (seq != _requestSeq || overview == null) {
        return;
      }
      final converted = ExploreMediaMapper.dedupe([
        ...overview.outfitPosts.map(
          (post) => ExploreMediaMapper.fromProfilePost(
            post: post,
            user: overview.user,
          ),
        ),
      ]).where(_isStylePost).toList(growable: false);
      personMedia.assignAll(converted);
    } catch (_) {}
  }

  Future<void> _fetchRelatedMedia({
    required String needle,
    required int seq,
    String? ownerUsername,
  }) async {
    final collected = <HomePostModel>[];
    final encoded = Uri.encodeQueryComponent(needle);

    Future<void> takeFeed(String endpoint, {bool requireMatch = false}) async {
      if (seq != _requestSeq) {
        return;
      }
      final parsed = await _tryFetchFeed(endpoint);
      if (parsed == null || seq != _requestSeq) {
        return;
      }
      collected.addAll(
        parsed.feed.where((post) {
          if (!_isStylePost(post)) {
            return false;
          }
          if (requireMatch && !ExploreMediaMapper.matchesQuery(post, needle)) {
            return false;
          }
          return true;
        }),
      );
    }

    Future<void> takeReels(String endpoint) async {
      if (seq != _requestSeq) {
        return;
      }
      final parsed = await _tryFetchReels(endpoint);
      if (parsed == null || seq != _requestSeq) {
        return;
      }
      collected.addAll(
        parsed.reels
            .map(ExploreMediaMapper.fromReel)
            .where(_isStylePost)
            .where((post) => ExploreMediaMapper.matchesQuery(post, needle)),
      );
    }

    await takeFeed(
      'search/posts?type=outfit&page=1&per_page=$_explorePerPage&q=$encoded',
    );
    if (collected.length < 8) {
      await takeFeed(
        'feed/home?type=outfit&discover_type=for_you&page=1&per_page=$_explorePerPage&q=$encoded&query=$encoded',
        requireMatch: true,
      );
    }
    if (collected.length < 12) {
      await takeReels('reels?type=outfit&page=1');
    }
    if (collected.length < 8) {
      await takeFeed(
        'feed/home?type=outfit&discover_type=for_you&page=1&per_page=$_explorePerPage',
        requireMatch: true,
      );
    }

    if (seq != _requestSeq) {
      return;
    }

    final ownerKey = ownerUsername?.trim().toLowerCase() ?? '';
    final personIds = personMedia.map((item) => item.id).toSet();
    relatedMedia.assignAll(
      ExploreMediaMapper.dedupe(collected).where((post) {
        if (personIds.contains(post.id)) {
          return false;
        }
        if (ownerKey.isNotEmpty &&
            post.username.trim().toLowerCase() == ownerKey) {
          return false;
        }
        return true;
      }),
    );
  }

  Future<ProfileOverviewModel?> _fetchProfileOverview(String username) async {
    final cleaned = username.trim().replaceFirst(RegExp(r'^@+'), '');
    if (cleaned.isEmpty) {
      return null;
    }
    final response = await ApiHelper.fetchDataWithAuthorization(
      'profiles/${Uri.encodeComponent(cleaned)}/overview?per_page=18',
    );
    if (response == null ||
        response.statusCode < 200 ||
        response.statusCode >= 300) {
      return null;
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['status_code'] != 1 && payload['status_code'] != '1') {
      return null;
    }
    return ProfileOverviewResponseModel.fromMap(payload).overview;
  }

  Future<HomeFeedResponse?> _tryFetchFeed(String endpoint) async {
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
      return HomeFeedResponse.fromJson(payload);
    } catch (_) {
      return null;
    }
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

  void _commitExploreResults({
    required bool reset,
    required int nextPage,
    required HomeFeedResponse? primaryFeed,
    required ReelResponse? primaryReels,
    required List<HomeFeedResponse> extraFeeds,
    required List<ReelResponse> extraReels,
  }) {
    if (primaryFeed == null &&
        primaryReels == null &&
        extraFeeds.isEmpty &&
        extraReels.isEmpty) {
      if (exploreItems.isEmpty) {
        exploreHasError.value = true;
        exploreErrorMessage.value = 'Unable to load Explore right now.';
        exploreHasMore.value = false;
      }
      return;
    }

    final posts = <HomePostModel>[..._explorePosts];
    final reels = <HomePostModel>[..._exploreReels];
    final seenPosts = posts.map((item) => item.id).toSet();
    final seenReels = reels.map((item) => item.id).toSet();

    void addPosts(Iterable<HomePostModel> incoming) {
      for (final post in incoming) {
        final id = post.id.trim();
        if (id.isEmpty || !_isStylePost(post) || !seenPosts.add(id)) {
          continue;
        }
        posts.add(post);
      }
    }

    void addReels(Iterable<HomePostModel> incoming) {
      for (final reel in incoming) {
        final id = reel.id.trim();
        if (id.isEmpty || !_isStylePost(reel) || !seenReels.add(id)) {
          continue;
        }
        reels.add(reel);
      }
    }

    if (primaryFeed != null) {
      _explorePage = primaryFeed.pagination.currentPage == 0
          ? nextPage
          : primaryFeed.pagination.currentPage;
      _exploreHasMorePosts = primaryFeed.pagination.hasMorePages;
      addPosts(primaryFeed.feed);
    } else if (reset) {
      _exploreHasMorePosts = false;
    }

    if (primaryReels != null) {
      _exploreHasMoreReels = primaryReels.pagination.hasMorePages;
      addReels(primaryReels.reels.map(ExploreMediaMapper.fromReel));
      if (primaryFeed == null) {
        _explorePage = primaryReels.pagination.currentPage == 0
            ? nextPage
            : primaryReels.pagination.currentPage;
      }
    } else if (reset) {
      _exploreHasMoreReels = false;
    }

    for (final feed in extraFeeds) {
      addPosts(feed.feed);
    }
    for (final reelPage in extraReels) {
      addReels(reelPage.reels.map(ExploreMediaMapper.fromReel));
    }

    final ranked = ExploreMediaMapper.rankForExplore(
      posts: posts,
      reels: reels,
    );
    if (ranked.isEmpty) {
      return;
    }

    _explorePosts
      ..clear()
      ..addAll(posts);
    _exploreReels
      ..clear()
      ..addAll(reels);
    exploreHasMore.value = _exploreHasMorePosts || _exploreHasMoreReels;
    if (reset) {
      exploreItems.assignAll(ranked);
    } else {
      final existing = exploreItems.map((item) => item.id).toSet();
      exploreItems.addAll(ranked.where((item) => existing.add(item.id)));
    }
    exploreItems.refresh();
  }

  void _addExplorePosts(Iterable<HomePostModel> incoming) {
    final seen = _explorePosts.map((item) => item.id).toSet();
    for (final post in incoming) {
      final id = post.id.trim();
      if (id.isEmpty || !_isStylePost(post) || !seen.add(id)) {
        continue;
      }
      _explorePosts.add(post);
    }
  }

  void _addExploreReels(Iterable<HomePostModel> incoming) {
    final seen = _exploreReels.map((item) => item.id).toSet();
    for (final reel in incoming) {
      final id = reel.id.trim();
      if (id.isEmpty || !_isStylePost(reel) || !seen.add(id)) {
        continue;
      }
      _exploreReels.add(reel);
    }
  }

  void _seedExploreFromHome() {
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      _addExplorePosts(home.cachedPostsFor(HomeFeedType.style));
      _addExplorePosts(home.visiblePosts);
    }
    if (Get.isRegistered<ReelController>()) {
      _addExploreReels(
        Get.find<ReelController>()
            .cachedReelsFor(ReelFeedType.style)
            .map(ExploreMediaMapper.fromReel),
      );
    }
    if (_explorePosts.isEmpty && _exploreReels.isEmpty) {
      return;
    }
    exploreItems.assignAll(
      ExploreMediaMapper.rankForExplore(
        posts: _explorePosts,
        reels: _exploreReels,
      ),
    );
  }

  bool _isStylePost(HomePostModel post) {
    return post.feedType == HomeFeedType.style && !post.isFoodPost;
  }

  Future<void> _collectMatches({
    required String query,
    required int seq,
    required List<SearchUserModel> collected,
    required int startPage,
    required bool browse,
    String? matchQuery,
    int maxPages = _maxScanPages,
  }) async {
    final prefixQuery = matchQuery ?? query;
    var page = startPage;
    var pagesFetched = 0;

    while (pagesFetched < maxPages) {
      if (seq != _requestSeq) {
        return;
      }

      final parsed = await _fetchSearchPage(page: page, query: query);
      if (seq != _requestSeq) {
        return;
      }

      _currentPage = parsed.pagination.currentPage;
      hasMore.value = parsed.pagination.hasMorePages;
      pagesFetched++;

      final matched = parsed.users
          .where((user) => user.matchesPrefix(prefixQuery))
          .toList(growable: false);
      for (final user in matched) {
        if (collected.any(
          (existing) =>
              existing.username.toLowerCase() == user.username.toLowerCase(),
        )) {
          continue;
        }
        collected.add(user);
      }

      if (!parsed.pagination.hasMorePages) {
        hasMore.value = false;
        return;
      }

      if (collected.length >= perPage && pagesFetched >= 1 && !browse) {
        return;
      }

      if (collected.length >= perPage && browse) {
        return;
      }

      page += 1;
    }
  }

  Future<SearchUsersResponseModel> _fetchSearchPage({
    required int page,
    required String query,
  }) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      _buildEndpoint(page: page, query: query),
    );

    if (response == null) {
      throw Exception('No response returned from user search endpoint.');
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        (payload['status_code'] != 1 && payload['status_code'] != '1')) {
      throw Exception(
        (payload['message'] ?? 'Failed to search users').toString(),
      );
    }

    return SearchUsersResponseModel.fromJson(payload);
  }

  Future<SearchUserModel?> _lookupExactUsername(String rawQuery) async {
    final username = _normalizeQuery(rawQuery);
    if (username.isEmpty || username.contains(' ') || username.length < 2) {
      return null;
    }

    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'profiles/${Uri.encodeComponent(username)}/overview?per_page=1',
      );
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (payload['status_code'] != 1 && payload['status_code'] != '1') {
        return null;
      }

      final userJson = payload['user'];
      if (userJson is! Map) {
        return null;
      }

      final user = SearchUserModel.fromJson(
        Map<String, dynamic>.from(userJson),
      );
      if (!user.matchesPrefix(username) &&
          user.username.trim().toLowerCase() != username.toLowerCase()) {
        return null;
      }
      return user;
    } catch (_) {
      return null;
    }
  }

  List<SearchUserModel> _dedupeAndSort(
    List<SearchUserModel> source,
    String query,
  ) {
    final seen = <String>{};
    final unique = <SearchUserModel>[];
    for (final user in source) {
      final key = user.username.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      unique.add(user);
    }

    unique.sort((a, b) {
      final rankCompare = a.prefixRank(query).compareTo(b.prefixRank(query));
      if (rankCompare != 0) {
        return rankCompare;
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return unique;
  }

  String _buildEndpoint({required int page, required String query}) {
    final buffer = StringBuffer('users/search?page=$page&per_page=$perPage');
    final normalized = _normalizeQuery(query);
    if (normalized.isNotEmpty) {
      final encoded = Uri.encodeQueryComponent(normalized);
      buffer.write('&q=$encoded&query=$encoded&search=$encoded');
    }
    return buffer.toString();
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return;
    }
    if (position.pixels < position.maxScrollExtent - 220) {
      return;
    }
    if (_normalizeQuery(query.value).isEmpty) {
      unawaited(loadExplore(reset: false));
      return;
    }
    if (isHashtagSearch) {
      return;
    }
    searchUsers(reset: false);
  }

  void _maybeAutoOpenProfile() {
    final targetUsername = _pendingOpenUsername;
    if (_hasAutoOpenedProfile ||
        targetUsername == null ||
        targetUsername.isEmpty) {
      return;
    }

    SearchUserModel? match;
    for (final user in users) {
      if (user.username.trim().toLowerCase() == targetUsername) {
        match = user;
        break;
      }
    }
    if (match == null) {
      return;
    }

    final resolvedMatch = match;
    _hasAutoOpenedProfile = true;
    ProfileOpenHelper.open(
      username: resolvedMatch.username,
      initialIsFollowing: resolvedMatch.isFollowing,
      avatarUrl: resolvedMatch.avatarUrl,
    );
  }

  String _normalizeQuery(String raw) {
    return raw.trim().replaceFirst(RegExp(r'^@+'), '');
  }

  String _extractProfileUsername(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.scheme == 'stylebite') {
      if (uri.host == 'profile' && uri.pathSegments.isNotEmpty) {
        return uri.pathSegments.first;
      }
      final fromQuery = uri.queryParameters['username'];
      if (fromQuery != null && fromQuery.trim().isNotEmpty) {
        return fromQuery.trim();
      }
    }
    return raw;
  }
}
