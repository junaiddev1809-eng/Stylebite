import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../home/models/home_post_model.dart';
import '../models/restaurant_review_model.dart';

class RestaurantReviewStore extends GetxController {
  RestaurantReviewStore();

  static const _storageKey = 'restaurantCommunityReviews';

  final RxMap<String, List<RestaurantReview>> reviewsByKey =
      <String, List<RestaurantReview>>{}.obs;
  final RxMap<String, RestaurantRatingSummary> summaries =
      <String, RestaurantRatingSummary>{}.obs;

  final Map<String, DateTime> _fetchedAt = <String, DateTime>{};
  final Set<String> _fetchingKeys = <String>{};

  static RestaurantReviewStore get instance {
    if (!Get.isRegistered<RestaurantReviewStore>()) {
      Get.put(RestaurantReviewStore(), permanent: true);
    }
    return Get.find<RestaurantReviewStore>();
  }

  @override
  void onInit() {
    super.onInit();
    _loadSubmitted();
  }

  String keyFor(String restaurant) => normalizeRestaurantKey(restaurant);

  RestaurantRatingSummary? summaryFor(String restaurant) {
    final key = keyFor(restaurant);
    if (key.isEmpty) {
      return null;
    }
    return summaries[key];
  }

  List<RestaurantReview> reviewsFor(String restaurant) {
    final key = keyFor(restaurant);
    if (key.isEmpty) {
      return const <RestaurantReview>[];
    }
    final reviews = List<RestaurantReview>.from(
      reviewsByKey[key] ?? const <RestaurantReview>[],
    );
    reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reviews;
  }

  RestaurantReview? myReviewFor(String restaurant) {
    final userKey = normalizeReviewUsername(LocalStorage.getUsername() ?? '');
    if (userKey.isEmpty) {
      return null;
    }
    for (final review in reviewsFor(restaurant)) {
      if (review.userKey == userKey) {
        return review;
      }
    }
    return null;
  }

  bool hasReviewed(String restaurant) => myReviewFor(restaurant) != null;

  void ingestPosts(Iterable<HomePostModel> posts) {
    var changed = false;
    for (final post in posts) {
      if (_ingestPost(post)) {
        changed = true;
      }
    }
    if (changed) {
      reviewsByKey.refresh();
      summaries.refresh();
    }
  }

  Future<void> ensureRestaurantLoaded(HomePostModel post) async {
    ingestPosts(<HomePostModel>[post]);
    final restaurant = post.restaurant.trim();
    final key = keyFor(restaurant);
    if (key.isEmpty) {
      return;
    }

    final fetchedAt = _fetchedAt[key];
    if (fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < const Duration(seconds: 45)) {
      return;
    }
    if (!_fetchingKeys.add(key)) {
      return;
    }

    try {
      final remoteReviews = await _fetchRemoteReviews(
        restaurant: restaurant,
        postId: post.id,
      );
      for (final review in remoteReviews) {
        _upsert(review, persist: false);
      }

      final relatedPosts = await _fetchRelatedFoodPosts(restaurant);
      ingestPosts(relatedPosts);
      _fetchedAt[key] = DateTime.now();
    } finally {
      _fetchingKeys.remove(key);
      reviewsByKey.refresh();
      summaries.refresh();
    }
  }

  Future<void> submitReview({
    required HomePostModel post,
    required double food,
    required double service,
    required double staff,
    required double ambience,
  }) async {
    final restaurant = post.restaurant.trim();
    if (restaurant.isEmpty) {
      throw Exception('This post has no restaurant to review.');
    }

    final username = (LocalStorage.getUsername() ?? '').trim();
    if (username.isEmpty) {
      throw Exception('Please sign in to add a restaurant review.');
    }

    final review = RestaurantReview(
      restaurantName: restaurant,
      username: username.startsWith('@') ? username : '@$username',
      food: food.clamp(1, 5),
      service: service.clamp(1, 5),
      staff: staff.clamp(1, 5),
      ambience: ambience.clamp(1, 5),
      createdAt: DateTime.now(),
      source: RestaurantReviewSource.submitted,
      postId: post.id,
      avatarUrl: (LocalStorage.getAvatarUrl() ?? '').trim(),
    );

    _upsert(review, persist: true);
    reviewsByKey.refresh();
    summaries.refresh();
    unawaited(_pushRemote(review));
  }

  bool _ingestPost(HomePostModel post) {
    if (!post.isFoodPost && post.feedType != HomeFeedType.bite) {
      return false;
    }
    if (post.restaurant.trim().isEmpty || !post.hasFoodRatings) {
      return false;
    }

    final username = post.profileUsername.trim().isNotEmpty
        ? post.profileUsername.trim()
        : post.username.trim();
    if (username.isEmpty) {
      return false;
    }

    return _upsert(
      RestaurantReview(
        restaurantName: post.restaurant.trim(),
        username: username.startsWith('@') ? username : '@$username',
        food: post.foodRating ?? 0,
        service: post.serviceRating ?? 0,
        staff: post.staffRating ?? 0,
        ambience: post.ambienceRating ?? 0,
        createdAt: DateTime.now(),
        source: RestaurantReviewSource.post,
        postId: post.id,
        avatarUrl: post.avatarUrl.trim(),
      ),
      persist: false,
    );
  }

  bool _upsert(RestaurantReview review, {required bool persist}) {
    final key = keyFor(review.restaurantName);
    if (key.isEmpty || review.userKey.isEmpty) {
      return false;
    }

    final current = List<RestaurantReview>.from(
      reviewsByKey[key] ?? const <RestaurantReview>[],
    );
    final index = current.indexWhere((item) => item.userKey == review.userKey);
    if (index >= 0) {
      final existing = current[index];
      if (!_shouldReplace(existing, review)) {
        if (existing.avatarUrl.trim().isEmpty &&
            review.avatarUrl.trim().isNotEmpty) {
          current[index] = existing.copyWith(avatarUrl: review.avatarUrl);
          reviewsByKey[key] = current;
          return true;
        }
        return false;
      }
      current[index] = review.copyWith(
        avatarUrl: review.avatarUrl.trim().isNotEmpty
            ? review.avatarUrl
            : existing.avatarUrl,
      );
    } else {
      current.add(review);
    }

    reviewsByKey[key] = current;
    summaries[key] = _summaryFrom(current);
    if (persist) {
      _persistSubmitted();
    }
    return true;
  }

  bool _shouldReplace(RestaurantReview existing, RestaurantReview incoming) {
    const rank = <RestaurantReviewSource, int>{
      RestaurantReviewSource.submitted: 3,
      RestaurantReviewSource.remote: 2,
      RestaurantReviewSource.post: 1,
    };
    final existingRank = rank[existing.source] ?? 0;
    final incomingRank = rank[incoming.source] ?? 0;
    if (incomingRank > existingRank) {
      return true;
    }
    if (incomingRank < existingRank) {
      return false;
    }
    return !incoming.createdAt.isBefore(existing.createdAt);
  }

  RestaurantRatingSummary _summaryFrom(List<RestaurantReview> reviews) {
    if (reviews.isEmpty) {
      return const RestaurantRatingSummary(
        food: 0,
        service: 0,
        staff: 0,
        ambience: 0,
        overall: 0,
        count: 0,
      );
    }

    var food = 0.0;
    var service = 0.0;
    var staff = 0.0;
    var ambience = 0.0;
    var foodCount = 0;
    var serviceCount = 0;
    var staffCount = 0;
    var ambienceCount = 0;
    var overall = 0.0;

    for (final review in reviews) {
      if (review.food > 0) {
        food += review.food;
        foodCount++;
      }
      if (review.service > 0) {
        service += review.service;
        serviceCount++;
      }
      if (review.staff > 0) {
        staff += review.staff;
        staffCount++;
      }
      if (review.ambience > 0) {
        ambience += review.ambience;
        ambienceCount++;
      }
      overall += review.overall;
    }

    return RestaurantRatingSummary(
      food: foodCount == 0 ? 0 : food / foodCount,
      service: serviceCount == 0 ? 0 : service / serviceCount,
      staff: staffCount == 0 ? 0 : staff / staffCount,
      ambience: ambienceCount == 0 ? 0 : ambience / ambienceCount,
      overall: overall / reviews.length,
      count: reviews.length,
    );
  }

  void _loadSubmitted() {
    final raw = LocalStorage.prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        final review = RestaurantReview.fromJson(
          Map<String, dynamic>.from(item),
        );
        _upsert(
          review.copyWithSource(RestaurantReviewSource.submitted),
          persist: false,
        );
      }
      reviewsByKey.refresh();
      summaries.refresh();
    } catch (_) {
      // Ignore corrupt local cache and rebuild from live posts.
    }
  }

  void _persistSubmitted() {
    final submitted = <RestaurantReview>[];
    for (final reviews in reviewsByKey.values) {
      submitted.addAll(
        reviews.where(
          (review) => review.source == RestaurantReviewSource.submitted,
        ),
      );
    }
    LocalStorage.prefs.setString(
      _storageKey,
      jsonEncode(submitted.map((review) => review.toJson()).toList()),
    );
  }

  Future<void> _pushRemote(RestaurantReview review) async {
    final body = <String, dynamic>{
      'restaurant': review.restaurantName,
      'food_rating': review.food,
      'service_rating': review.service,
      'staff_rating': review.staff,
      'ambience_rating': review.ambience,
      if (review.postId.isNotEmpty) 'post_id': review.postId,
    };
    final endpoints = <String>[
      'restaurants/reviews',
      if (review.postId.isNotEmpty) 'feed/posts/${review.postId}/food-review',
      'food/reviews',
    ];
    for (final endpoint in endpoints) {
      try {
        final response = await ApiHelper.postRequestWithAuthorization(
          endpoint,
          body: body,
          interceptAuthFailure: false,
        );
        if (response == null) {
          continue;
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return;
        }
      } catch (_) {
        // Try the next known review endpoint.
      }
    }
  }

  Future<List<RestaurantReview>> _fetchRemoteReviews({
    required String restaurant,
    required String postId,
  }) async {
    final encoded = Uri.encodeQueryComponent(restaurant);
    final endpoints = <String>[
      'restaurants/reviews?restaurant=$encoded&q=$encoded',
      if (postId.isNotEmpty) 'feed/posts/$postId/food-reviews',
      'food/reviews?restaurant=$encoded&q=$encoded',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
        if (response == null ||
            response.statusCode < 200 ||
            response.statusCode >= 300) {
          continue;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          continue;
        }
        final reviews = _reviewsFromPayload(
          Map<String, dynamic>.from(decoded),
          restaurant,
        );
        if (reviews.isNotEmpty) {
          return reviews;
        }
      } catch (_) {
        continue;
      }
    }
    return const <RestaurantReview>[];
  }

  Future<List<HomePostModel>> _fetchRelatedFoodPosts(String restaurant) async {
    final encoded = Uri.encodeQueryComponent(restaurant);
    final endpoints = <String>[
      'search/posts?type=food&page=1&per_page=20&q=$encoded',
      'feed/home?type=food&discover_type=for_you&page=1&per_page=20&q=$encoded&query=$encoded&restaurant=$encoded',
    ];

    for (final endpoint in endpoints) {
      try {
        final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
        if (response == null ||
            response.statusCode < 200 ||
            response.statusCode >= 300) {
          continue;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map) {
          continue;
        }
        final posts = _postsFromPayload(Map<String, dynamic>.from(decoded));
        final key = keyFor(restaurant);
        final matched = posts
            .where((post) => keyFor(post.restaurant) == key)
            .toList(growable: false);
        if (matched.isNotEmpty) {
          return matched;
        }
      } catch (_) {
        continue;
      }
    }
    return const <HomePostModel>[];
  }

  List<RestaurantReview> _reviewsFromPayload(
    Map<String, dynamic> json,
    String restaurant,
  ) {
    final candidates = <dynamic>[
      json['reviews'],
      json['items'],
      json['data'],
    ];
    if (json['data'] is Map) {
      final data = json['data'] as Map;
      candidates.addAll([
        data['reviews'],
        data['items'],
        data['data'],
      ]);
    }

    for (final candidate in candidates) {
      if (candidate is! List) {
        continue;
      }
      return candidate
          .whereType<Map>()
          .map((item) {
            final mapped = Map<String, dynamic>.from(item);
            mapped['restaurant'] ??= restaurant;
            mapped['source'] ??= 'remote';
            return RestaurantReview.fromJson(mapped);
          })
          .where((review) => review.userKey.isNotEmpty && review.overall > 0)
          .toList(growable: false);
    }
    return const <RestaurantReview>[];
  }

  List<HomePostModel> _postsFromPayload(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'food').toString();
    final candidates = <dynamic>[
      json['feed'],
      json['posts'],
      json['items'],
      json['data'],
    ];
    if (json['data'] is Map) {
      final data = json['data'] as Map;
      candidates.addAll([
        data['feed'],
        data['posts'],
        data['items'],
        data['data'],
      ]);
    }

    for (final candidate in candidates) {
      if (candidate is! List) {
        continue;
      }
      return candidate
          .whereType<Map>()
          .map(
            (item) => HomePostModel.fromJson(
              Map<String, dynamic>.from(item),
              responseType: type,
            ),
          )
          .toList(growable: false);
    }
    return const <HomePostModel>[];
  }
}

extension on RestaurantReview {
  RestaurantReview copyWith({
    RestaurantReviewSource? source,
    String? avatarUrl,
  }) {
    return RestaurantReview(
      restaurantName: restaurantName,
      username: username,
      food: food,
      service: service,
      staff: staff,
      ambience: ambience,
      createdAt: createdAt,
      source: source ?? this.source,
      postId: postId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  RestaurantReview copyWithSource(RestaurantReviewSource source) {
    return copyWith(source: source);
  }
}
