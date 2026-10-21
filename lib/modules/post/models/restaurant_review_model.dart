class RestaurantReview {
  const RestaurantReview({
    required this.restaurantName,
    required this.username,
    required this.food,
    required this.service,
    required this.staff,
    required this.ambience,
    required this.createdAt,
    required this.source,
    this.postId = '',
    this.avatarUrl = '',
  });

  final String restaurantName;
  final String username;
  final double food;
  final double service;
  final double staff;
  final double ambience;
  final DateTime createdAt;
  final RestaurantReviewSource source;
  final String postId;
  final String avatarUrl;

  String get userKey => normalizeReviewUsername(username);

  double get overall {
    final values = <double>[food, service, staff, ambience]
        .where((value) => value > 0)
        .toList(growable: false);
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((sum, item) => sum + item) / values.length;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'restaurant': restaurantName,
      'username': username,
      'food_rating': food,
      'service_rating': service,
      'staff_rating': staff,
      'ambience_rating': ambience,
      'created_at': createdAt.toIso8601String(),
      'source': source.name,
      'post_id': postId,
      'avatar_url': avatarUrl,
    };
  }

  factory RestaurantReview.fromJson(Map<String, dynamic> json) {
    return RestaurantReview(
      restaurantName: _asString(
        json['restaurant'] ?? json['restaurant_name'] ?? json['name'],
      ),
      username: _asString(
        json['username'] ??
            json['user_name'] ??
            _nestedName(json['user']) ??
            _nestedName(json['author']) ??
            json['display_name'],
      ),
      food: _asRating(
        json['food'] ?? json['food_rating'] ?? json['foodRating'],
      ),
      service: _asRating(
        json['service'] ?? json['service_rating'] ?? json['serviceRating'],
      ),
      staff: _asRating(
        json['staff'] ?? json['staff_rating'] ?? json['staffRating'],
      ),
      ambience: _asRating(
        json['ambience'] ?? json['ambience_rating'] ?? json['ambienceRating'],
      ),
      createdAt:
          DateTime.tryParse(_asString(json['created_at'] ?? json['createdAt'])) ??
          DateTime.now(),
      source: RestaurantReviewSource.parse(json['source']),
      postId: _asString(json['post_id'] ?? json['postId']),
      avatarUrl: _asString(
        json['avatar_url'] ??
            json['avatar'] ??
            json['profile_picture'] ??
            _nestedAvatar(json['user']) ??
            _nestedAvatar(json['author']),
      ),
    );
  }
}

enum RestaurantReviewSource {
  submitted,
  remote,
  post;

  static RestaurantReviewSource parse(Object? raw) {
    final value = raw?.toString().trim().toLowerCase() ?? '';
    return switch (value) {
      'submitted' || 'local' || 'user' => RestaurantReviewSource.submitted,
      'remote' || 'api' || 'community' => RestaurantReviewSource.remote,
      _ => RestaurantReviewSource.post,
    };
  }
}

class RestaurantRatingSummary {
  const RestaurantRatingSummary({
    required this.food,
    required this.service,
    required this.staff,
    required this.ambience,
    required this.overall,
    required this.count,
  });

  final double food;
  final double service;
  final double staff;
  final double ambience;
  final double overall;
  final int count;

  bool get hasRatings => count > 0;
}

String normalizeRestaurantKey(String raw) {
  var value = raw.trim().toLowerCase();
  value = value.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
  value = value.replaceAll(
    RegExp(r'\b(restaurant|cafe|café|grill|kitchen|dhaba|hotel)\b'),
    ' ',
  );
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String normalizeReviewUsername(String raw) {
  return raw.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
}

String _asString(Object? raw) {
  if (raw is Map) {
    return '';
  }
  return raw?.toString().trim() ?? '';
}

String? _nestedName(Object? raw) {
  if (raw is! Map) {
    return raw?.toString();
  }
  final map = Map<Object?, Object?>.from(raw);
  final value = map['username'] ?? map['user_name'] ?? map['display_name'] ?? map['name'];
  if (value == null || value is Map) {
    return null;
  }
  return value.toString();
}

String? _nestedAvatar(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final map = Map<Object?, Object?>.from(raw);
  final value = map['avatar_url'] ?? map['avatar'] ?? map['profile_picture'];
  if (value == null || value is Map) {
    return null;
  }
  return value.toString();
}

double _asRating(Object? raw) {
  if (raw == null) {
    return 0;
  }
  final parsed = raw is num ? raw.toDouble() : double.tryParse(raw.toString());
  if (parsed == null || parsed <= 0) {
    return 0;
  }
  return parsed.clamp(1, 5);
}
