import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../home/controllers/home_controller.dart';
import '../../home/models/home_post_model.dart';
import '../../post/controllers/restaurant_review_store.dart';
import '../../post/screens/post_detail_screen.dart';
import '../../post/utils/hashtag_open_helper.dart';
import '../../reel/controllers/reel_controller.dart';
import '../../reel/models/reel_item_model.dart';
import '../../reel/utils/reel_open_helper.dart';
import '../utils/explore_media_mapper.dart';

class BiteRestaurantSearchController extends GetxController {
  static const int _perPage = 20;
  static const int _maxScanPages = 8;

  final TextEditingController searchTextController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final RxList<HomePostModel> posts = <HomePostModel>[].obs;
  final RxList<HomePostModel> exploreItems = <HomePostModel>[].obs;
  final RxList<HomePostModel> restaurantMedia = <HomePostModel>[].obs;
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
  final RxString mediaOwnerRestaurant = ''.obs;

  Timer? _debounce;
  DateTime? _suppressQueryUntil;
  int searchEpoch = 0;
  int _currentPage = 0;
  int _explorePage = 0;
  int _requestSeq = 0;
  bool _usingFeedScan = false;
  bool _exploreHasMorePosts = false;
  bool _exploreHasMoreReels = false;
  bool _exploreRefreshInFlight = false;
  final List<HomePostModel> _explorePosts = <HomePostModel>[];
  final List<HomePostModel> _exploreReels = <HomePostModel>[];

  static const int _explorePerPage = 18;

  bool get isSearching => _normalize(query.value).isNotEmpty;

  bool get isHashtagSearch => HashtagOpenHelper.tagFromQuery(query.value) != null;

  List<HomePostModel> get uniqueRestaurants {
    final seen = <String>{};
    final unique = <HomePostModel>[];
    for (final post in posts) {
      final key = _restaurantKey(post);
      if (key.isEmpty || !seen.add(key)) {
        continue;
      }
      unique.add(post);
    }
    return unique;
  }

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
    _usingFeedScan = false;
    _currentPage = 0;
    hasMore.value = false;
    hasError.value = false;
    errorMessage.value = '';
    isInitialLoading.value = false;
    isLoadingMore.value = false;
    isMediaLoading.value = false;
    posts.clear();
    restaurantMedia.clear();
    relatedMedia.clear();
    mediaOwnerRestaurant.value = '';
    query.value = '';
    if (clearText) {
      searchTextController.clear();
    }
    unawaited(loadExplore(reset: true, seq: _requestSeq));
  }

  void onQueryChanged(String value) {
    if (_suppressQueryUntil != null &&
        DateTime.now().isBefore(_suppressQueryUntil!)) {
      if (_normalize(value).isNotEmpty) {
        searchTextController.value = const TextEditingValue();
      }
      query.value = '';
      return;
    }
    final wasSearching = isSearching;
    query.value = value;
    _debounce?.cancel();
    if (_normalize(value).isEmpty) {
      if (!wasSearching) {
        return;
      }
      resetIdle(clearText: false);
      return;
    }
    posts.clear();
    restaurantMedia.clear();
    relatedMedia.clear();
    mediaOwnerRestaurant.value = '';
    hasError.value = false;
    isInitialLoading.value = true;
    isMediaLoading.value = true;
    _debounce = Timer(const Duration(milliseconds: 280), () {
      searchRestaurants(reset: true);
    });
  }

  Future<void> refreshSearch() async {
    if (_normalize(query.value).isEmpty) {
      await loadExplore(reset: true);
      return;
    }
    await searchRestaurants(reset: true);
  }

  void openMedia(HomePostModel post) {
    if (ReelOpenHelper.isReel(post)) {
      ReelOpenHelper.openFromPost(post);
      return;
    }
    Get.to<void>(() => PostDetailScreen(post: post));
  }

  void openExplore({Iterable<HomePostModel> extraPosts = const []}) {
    _debounce?.cancel();
    _suppressQueryUntil = DateTime.now().add(const Duration(milliseconds: 800));
    _requestSeq++;
    query.value = '';
    if (searchTextController.text.isNotEmpty) {
      searchTextController.value = const TextEditingValue();
    }
    posts.clear();
    restaurantMedia.clear();
    relatedMedia.clear();
    mediaOwnerRestaurant.value = '';
    isInitialLoading.value = false;
    isMediaLoading.value = false;
    exploreHasError.value = false;
    exploreErrorMessage.value = '';

    _explorePosts.clear();
    _exploreReels.clear();
    _seedExploreFromHome();
    _addExplorePosts(extraPosts.where(_isBiteExplorePost));
    if (_explorePosts.isNotEmpty || _exploreReels.isNotEmpty) {
      exploreItems.assignAll(
        ExploreMediaMapper.rankForExplore(
          posts: _explorePosts,
          reels: _exploreReels,
        ),
      );
      exploreItems.refresh();
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

  void primeExplore({Iterable<HomePostModel> extraPosts = const []}) {
    openExplore(extraPosts: extraPosts);
  }

  Future<void> loadExplore({required bool reset, int? seq}) async {
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
      _seedExploreFromHome();
      final results = await Future.wait<Object?>([
        _fetchFoodFeed(nextPage),
        _tryFetchReels('reels?type=food&page=$nextPage'),
        if (reset)
          _tryFetchFeed(
            'feed/home?type=food&discover_type=trending&page=1&per_page=$_explorePerPage',
          ),
        if (reset) _fetchFoodFeed(2),
        if (reset) _tryFetchReels('reels?type=food&sort=trending&page=1'),
      ]);
      if (token != _requestSeq) {
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
      if (exploreItems.isEmpty &&
          (_explorePosts.isNotEmpty || _exploreReels.isNotEmpty)) {
        exploreItems.assignAll(
          ExploreMediaMapper.rankForExplore(
            posts: _explorePosts,
            reels: _exploreReels,
          ),
        );
      }
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

  Future<void> _searchHashtag(String tag, {required bool reset}) async {
    if (!reset) {
      return;
    }

    final seq = ++_requestSeq;
    _exploreRefreshInFlight = false;
    posts.clear();
    restaurantMedia.clear();
    relatedMedia.clear();
    mediaOwnerRestaurant.value = '';
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
            (post) => _isBitePost(post) && post.containsHashtag(tag),
          ),
        );
      }
      if (Get.isRegistered<ReelController>()) {
        collected.addAll(
          Get.find<ReelController>()
              .cachedReelsFor(ReelFeedType.bite)
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
        'feed/home?type=food&discover_type=for_you&page=1&per_page=$_explorePerPage&tag=$encoded&hashtag=$encoded&q=$hashed',
        'search/posts?type=food&page=1&per_page=$_explorePerPage&q=$hashed',
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
            if (!_isBitePost(post)) {
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

      final reels = await _tryFetchReels('reels?type=food&page=1&sort=trending');
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
          posts: ExploreMediaMapper.dedupe(collected).where(_isBitePost).toList(),
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

  Future<void> searchRestaurants({required bool reset}) async {
    if (_suppressQueryUntil != null &&
        DateTime.now().isBefore(_suppressQueryUntil!)) {
      return;
    }
    final hashtag = HashtagOpenHelper.tagFromQuery(query.value);
    if (hashtag != null) {
      await _searchHashtag(hashtag, reset: reset);
      return;
    }

    final needle = _normalize(query.value);
    if (needle.isEmpty) {
      if (!_exploreRefreshInFlight &&
          !isExploreLoading.value &&
          exploreItems.isEmpty) {
        resetIdle(clearText: false);
      }
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
      _usingFeedScan = false;
      restaurantMedia.clear();
      relatedMedia.clear();
      mediaOwnerRestaurant.value = '';
    } else if (isLoadingMore.value || !hasMore.value || isInitialLoading.value) {
      return;
    } else {
      isLoadingMore.value = true;
    }

    try {
      final collected = <HomePostModel>[
        if (!reset) ...posts,
      ];

      if (reset) {
        collected.addAll(_localMatches(needle));
        if (collected.isNotEmpty) {
          posts.assignAll(_dedupeAndSort(collected, needle));
        }

        await _collectFromSearchApi(
          needle: needle,
          seq: seq,
          collected: collected,
          startPage: 1,
        );
        if (seq != _requestSeq) {
          return;
        }

        if (collected.isEmpty) {
          _usingFeedScan = true;
          await _collectFromFoodFeed(
            needle: needle,
            seq: seq,
            collected: collected,
            startPage: 1,
          );
        }
      } else if (_usingFeedScan) {
        await _collectFromFoodFeed(
          needle: needle,
          seq: seq,
          collected: collected,
          startPage: _currentPage + 1,
        );
      } else {
        await _collectFromSearchApi(
          needle: needle,
          seq: seq,
          collected: collected,
          startPage: _currentPage + 1,
        );
        if (seq != _requestSeq) {
          return;
        }
        if (collected.length == posts.length) {
          _usingFeedScan = true;
          await _collectFromFoodFeed(
            needle: needle,
            seq: seq,
            collected: collected,
            startPage: 1,
          );
        }
      }

      if (seq != _requestSeq) {
        return;
      }
      posts.assignAll(_dedupeAndSort(collected, needle));
      RestaurantReviewStore.instance.ingestPosts(posts);
      if (reset) {
        isInitialLoading.value = false;
        unawaited(_loadSearchMedia(needle: needle, seq: seq));
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
        unawaited(_loadSearchMedia(needle: needle, seq: seq));
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
      if (exploreItems.isEmpty &&
          _explorePosts.isEmpty &&
          _exploreReels.isEmpty) {
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
        if (id.isEmpty || !_isBiteExplorePost(post) || !seenPosts.add(id)) {
          continue;
        }
        posts.add(post);
      }
    }

    void addReels(Iterable<HomePostModel> incoming) {
      for (final reel in incoming) {
        final id = reel.id.trim();
        if (id.isEmpty || !_isBiteExplorePost(reel) || !seenReels.add(id)) {
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

  Future<void> _loadSearchMedia({
    required String needle,
    required int seq,
  }) async {
    isMediaLoading.value = true;
    try {
      final restaurants = uniqueRestaurants;
      HomePostModel? owner;
      if (restaurants.isNotEmpty) {
        owner = restaurants.first;
        mediaOwnerRestaurant.value = owner.restaurant.trim().isNotEmpty
            ? owner.restaurant.trim()
            : owner.displayLocation;
      }

      final ownerKey = owner == null ? '' : _restaurantKey(owner);
      final fromRestaurant = <HomePostModel>[];
      final related = <HomePostModel>[];
      for (final post in posts) {
        if (ownerKey.isNotEmpty && _restaurantKey(post) == ownerKey) {
          fromRestaurant.add(post);
        } else {
          related.add(post);
        }
      }

      final encoded = Uri.encodeQueryComponent(needle);
      final extraFeed = await _tryFetchFeed(
        'feed/home?type=food&discover_type=for_you&page=1&per_page=$_explorePerPage&q=$encoded&query=$encoded&restaurant=$encoded',
      );
      final extraReels = await _tryFetchReels('reels?type=food&page=1');
      if (seq != _requestSeq) {
        return;
      }

      if (extraFeed != null) {
        for (final post in extraFeed.feed.where(_isBitePost)) {
          if (ownerKey.isNotEmpty && _restaurantKey(post) == ownerKey) {
            fromRestaurant.add(post);
            continue;
          }
          if (_matches(post, needle) ||
              ExploreMediaMapper.matchesQuery(post, needle)) {
            related.add(post);
          }
        }
      }
      if (extraReels != null) {
        related.addAll(
          extraReels.reels
              .map(ExploreMediaMapper.fromReel)
              .where(_isBitePost)
              .where((post) => ExploreMediaMapper.matchesQuery(post, needle)),
        );
      }

      for (final item in exploreItems) {
        if (_isBitePost(item) &&
            ExploreMediaMapper.matchesQuery(item, needle)) {
          related.add(item);
        }
      }

      final restaurantIds = fromRestaurant.map((item) => item.id).toSet();
      restaurantMedia.assignAll(ExploreMediaMapper.dedupe(fromRestaurant));
      relatedMedia.assignAll(
        ExploreMediaMapper.dedupe(related).where((post) {
          if (restaurantIds.contains(post.id)) {
            return false;
          }
          if (ownerKey.isNotEmpty && _restaurantKey(post) == ownerKey) {
            return false;
          }
          return true;
        }),
      );
    } finally {
      if (seq == _requestSeq) {
        isMediaLoading.value = false;
      }
    }
  }

  List<HomePostModel> _localMatches(String needle) {
    if (!Get.isRegistered<HomeController>()) {
      return const <HomePostModel>[];
    }
    return Get.find<HomeController>().visiblePosts
        .where((post) => _isBitePost(post) && _matches(post, needle))
        .toList(growable: false);
  }

  Future<void> _collectFromSearchApi({
    required String needle,
    required int seq,
    required List<HomePostModel> collected,
    required int startPage,
  }) async {
    final endpoints = <String>[
      'search/posts?type=food&page=$startPage&per_page=$_perPage&q=${Uri.encodeQueryComponent(needle)}',
      'feed/home?type=food&discover_type=for_you&page=$startPage&per_page=$_perPage&q=${Uri.encodeQueryComponent(needle)}&query=${Uri.encodeQueryComponent(needle)}&restaurant=${Uri.encodeQueryComponent(needle)}',
    ];

    for (final endpoint in endpoints) {
      if (seq != _requestSeq) {
        return;
      }
      final parsed = await _fetchPosts(endpoint);
      if (parsed == null) {
        continue;
      }
      _currentPage = parsed.pagination.currentPage == 0
          ? startPage
          : parsed.pagination.currentPage;
      hasMore.value = parsed.pagination.hasMorePages;
      final bitePosts = parsed.feed.where(_isBitePost).toList(growable: false);
      final matched = bitePosts
          .where((post) => _matches(post, needle))
          .toList(growable: false);
      if (matched.isNotEmpty) {
        collected.addAll(matched);
        return;
      }
      if (endpoint.contains('search/posts') && bitePosts.isNotEmpty) {
        collected.addAll(bitePosts);
        return;
      }
    }
  }

  Future<void> _collectFromFoodFeed({
    required String needle,
    required int seq,
    required List<HomePostModel> collected,
    required int startPage,
  }) async {
    var page = startPage;
    var pagesFetched = 0;
    while (pagesFetched < _maxScanPages) {
      if (seq != _requestSeq) {
        return;
      }
      final parsed = await _fetchPosts(
        'feed/home?type=food&discover_type=for_you&page=$page&per_page=$_perPage',
      );
      if (parsed == null) {
        hasMore.value = false;
        return;
      }
      _currentPage = parsed.pagination.currentPage == 0
          ? page
          : parsed.pagination.currentPage;
      hasMore.value = parsed.pagination.hasMorePages;
      pagesFetched++;
      collected.addAll(
        parsed.feed.where((post) => _isBitePost(post) && _matches(post, needle)),
      );
      if (!parsed.pagination.hasMorePages) {
        hasMore.value = false;
        return;
      }
      page = _currentPage + 1;
    }
  }

  Future<HomeFeedResponse?> _fetchFoodFeed(int page) async {
    final first = await _fetchPosts(
      'feed/home?type=food&page=$page&per_page=10&discover_type=for_you',
    );
    if (first != null && first.feed.isNotEmpty) {
      return first;
    }
    return _fetchPosts(
      'feed/home?type=food&discover_type=for_you&page=$page&per_page=10',
    );
  }

  Future<HomeFeedResponse?> _tryFetchFeed(String endpoint) =>
      _fetchPosts(endpoint);

  Future<ReelResponse?> _tryFetchReels(String endpoint) async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }
      final payload = Map<String, dynamic>.from(decoded);
      if (payload['status_code'] != 1 && payload['status_code'] != '1') {
        return null;
      }
      final type = (payload['type'] ?? 'food').toString();
      final candidates = <dynamic>[
        payload['reels'],
        payload['feed'],
        payload['posts'],
        payload['items'],
        payload['data'],
      ];
      if (payload['data'] is Map) {
        final data = payload['data'] as Map;
        candidates.addAll([
          data['reels'],
          data['feed'],
          data['posts'],
          data['items'],
        ]);
      }
      final reels = <ReelItemModel>[];
      for (final candidate in candidates) {
        if (candidate is! List) {
          continue;
        }
        for (final item in candidate) {
          if (item is! Map) {
            continue;
          }
          try {
            reels.add(
              ReelItemModel.fromJson(
                Map<String, dynamic>.from(item),
                responseType: type.isEmpty ? 'food' : type,
              ),
            );
          } catch (_) {}
        }
        if (reels.isNotEmpty) {
          break;
        }
      }
      if (reels.isEmpty) {
        return null;
      }
      return ReelResponse(
        statusCode: 1,
        message: (payload['message'] ?? '').toString(),
        type: type.isEmpty ? 'food' : type,
        reels: reels,
        pagination: ReelPagination.fromJson(_paginationFrom(payload)),
      );
    } catch (_) {
      return null;
    }
  }

  void _addExplorePosts(Iterable<HomePostModel> incoming) {
    final seen = _explorePosts.map((item) => item.id).toSet();
    for (final post in incoming) {
      final id = post.id.trim();
      if (id.isEmpty || !_isBiteExplorePost(post) || !seen.add(id)) {
        continue;
      }
      _explorePosts.add(post);
    }
  }

  void _addExploreReels(Iterable<HomePostModel> incoming) {
    final seen = _exploreReels.map((item) => item.id).toSet();
    for (final reel in incoming) {
      final id = reel.id.trim();
      if (id.isEmpty || !_isBiteExplorePost(reel) || !seen.add(id)) {
        continue;
      }
      _exploreReels.add(reel);
    }
  }

  void _seedExploreFromHome() {
    if (Get.isRegistered<HomeController>()) {
      final home = Get.find<HomeController>();
      _addExplorePosts(home.cachedPostsFor(HomeFeedType.bite));
      _addExplorePosts(home.visiblePosts.where(_isBitePost));
    }
    if (Get.isRegistered<ReelController>()) {
      _addExploreReels(
        Get.find<ReelController>()
            .cachedReelsFor(ReelFeedType.bite)
            .map(ExploreMediaMapper.fromReel),
      );
    }
  }

  Future<HomeFeedResponse?> _fetchPosts(String endpoint) async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
      if (response == null || response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return null;
      }
      final payload = Map<String, dynamic>.from(decoded);
      if (payload['status_code'] != 1 && payload['status_code'] != '1') {
        return null;
      }
      final forcedType = endpoint.contains('type=food')
          ? 'food'
          : (payload['type'] ?? 'food').toString();
      var feed = const <HomePostModel>[];
      try {
        feed = HomeFeedResponse.fromJson({
          ...payload,
          'type': forcedType,
        }).feed;
      } catch (_) {}
      if (feed.isEmpty) {
        feed = _postsFromPayload({...payload, 'type': forcedType});
      }
      return HomeFeedResponse(
        statusCode: 1,
        message: (payload['message'] ?? '').toString(),
        type: forcedType,
        feed: feed,
        pagination: HomeFeedPagination.fromJson(_paginationFrom(payload)),
      );
    } catch (_) {
      return null;
    }
  }

  List<HomePostModel> _postsFromPayload(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'food').toString();
    final candidates = <dynamic>[
      json['feed'],
      json['posts'],
      json['items'],
      json['reels'],
      json['data'],
    ];
    if (json['data'] is Map) {
      final data = json['data'] as Map;
      candidates.addAll([
        data['feed'],
        data['posts'],
        data['items'],
        data['reels'],
        data['data'],
      ]);
    }

    for (final candidate in candidates) {
      if (candidate is! List) {
        continue;
      }
      final posts = <HomePostModel>[];
      for (final item in candidate) {
        if (item is! Map) {
          continue;
        }
        try {
          final map = Map<String, dynamic>.from(item);
          map['id'] = (map['id'] ?? map['post_id'] ?? map['_id'] ?? '').toString();
          posts.add(
            HomePostModel.fromJson(map, responseType: type),
          );
        } catch (_) {}
      }
      if (posts.isNotEmpty) {
        return posts;
      }
    }
    return const <HomePostModel>[];
  }

  Map<String, dynamic> _paginationFrom(Map<String, dynamic> json) {
    final root = json['pagination'];
    if (root is Map) {
      return Map<String, dynamic>.from(root);
    }
    final data = json['data'];
    if (data is Map && data['pagination'] is Map) {
      return Map<String, dynamic>.from(data['pagination'] as Map);
    }
    return const <String, dynamic>{};
  }

  List<HomePostModel> _dedupeAndSort(List<HomePostModel> source, String needle) {
    final seen = <String>{};
    final unique = <HomePostModel>[];
    for (final post in source) {
      if (post.id.trim().isEmpty || !seen.add(post.id)) {
        continue;
      }
      unique.add(post);
    }
    unique.sort((a, b) {
      final rank = _rank(a, needle).compareTo(_rank(b, needle));
      if (rank != 0) {
        return rank;
      }
      return a.restaurant.toLowerCase().compareTo(b.restaurant.toLowerCase());
    });
    return unique;
  }

  bool _isBiteExplorePost(HomePostModel post) {
    return post.feedType == HomeFeedType.bite || post.isFoodPost;
  }

  bool _isBitePost(HomePostModel post) {
    return _isBiteExplorePost(post);
  }

  bool _matches(HomePostModel post, String needle) {
    final blob = [
      post.restaurant,
      post.dishName,
      post.location,
      post.displayLocation,
      post.caption,
    ].join(' ').toLowerCase();
    return blob.contains(needle);
  }

  int _rank(HomePostModel post, String needle) {
    final restaurant = post.restaurant.trim().toLowerCase();
    if (restaurant == needle) {
      return 0;
    }
    if (restaurant.startsWith(needle)) {
      return 1;
    }
    if (restaurant.contains(needle)) {
      return 2;
    }
    if (post.dishName.toLowerCase().contains(needle)) {
      return 3;
    }
    if (post.location.toLowerCase().contains(needle) ||
        post.displayLocation.toLowerCase().contains(needle)) {
      return 4;
    }
    return 5;
  }

  String _restaurantKey(HomePostModel post) {
    final restaurant = post.restaurant.trim().toLowerCase();
    if (restaurant.isNotEmpty) {
      return restaurant;
    }
    return post.displayLocation.trim().toLowerCase();
  }

  String _normalize(String value) => value.trim().toLowerCase();

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
      return;
    }
    if (position.pixels < position.maxScrollExtent - 240) {
      return;
    }
    if (_normalize(query.value).isEmpty) {
      unawaited(loadExplore(reset: false));
      return;
    }
    if (isHashtagSearch) {
      return;
    }
    searchRestaurants(reset: false);
  }
}
