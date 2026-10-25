import '../../../core/utils/app_time_formatter.dart';
import '../../../core/utils/verified_flag.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../../home/models/home_post_model.dart';

enum ReelFeedType { style, bite }

enum ReelMediaType { image, video }

class ReelResponse {
  const ReelResponse({
    required this.statusCode,
    required this.message,
    required this.type,
    required this.reels,
    required this.pagination,
  });

  final int statusCode;
  final String message;
  final String type;
  final List<ReelItemModel> reels;
  final ReelPagination pagination;

  factory ReelResponse.fromJson(Map<String, dynamic> json) {
    return ReelResponse(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      reels: (json['reels'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => ReelItemModel.fromJson(
              item,
              responseType: (json['type'] ?? '').toString(),
            ),
          )
      // TODO-sheezy : uncomment this line
      // .toList(growable: false),
          .toList(), // Growable list
      pagination: ReelPagination.fromJson(
        _asMap(json['pagination']),
      ),
    );
  }
}

class ReelPagination {
  const ReelPagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.hasMorePages,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool hasMorePages;

  factory ReelPagination.fromJson(Map<String, dynamic> json) {
    return ReelPagination(
      currentPage: _asInt(json['current_page']),
      perPage: _asInt(json['per_page']),
      total: _asInt(json['total']),
      lastPage: _asInt(json['last_page']),
      hasMorePages: _asBool(json['has_more_pages']),
    );
  }
}

class ReelItemModel {
  const ReelItemModel({
    required this.id,
    required this.feedType,
    required this.mediaType,
    required this.handle,
    required this.caption,
    required this.tags,
    required this.rating,
    required this.likes,
    required this.comments,
    required this.imageUrl,
    required this.imageAlt,
    this.avatarUrl = '',
    this.authorName = '',
    this.locationName = '',
    this.restaurant = '',
    this.dishName = '',
    this.foodRating,
    this.serviceRating,
    this.staffRating,
    this.ambienceRating,
    this.city = '',
    this.country = '',
    this.latitude,
    this.longitude,
    this.videoUrl = '',
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    this.saveCount = 0,
    this.viewCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.viewerRating,
    this.ratingCount = 0,
    this.profileUsername = '',
    this.isFollowingAuthor = false,
    this.isVerifiedBadge = false,
    this.showAd = false,
    this.adTriggerRatio = 0.4,
    this.ratingEnabled = false,
    this.publishedAt,
  });

  final String id;
  final ReelFeedType feedType;
  final ReelMediaType mediaType;
  final String handle;
  final String caption;
  final List<String> tags;
  final String rating;
  final String likes;
  final String comments;
  final String imageUrl;
  final String imageAlt;
  final String avatarUrl;
  final String authorName;
  final String locationName;
  final String restaurant;
  final String dishName;
  final double? foodRating;
  final double? serviceRating;
  final double? staffRating;
  final double? ambienceRating;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;
  final String videoUrl;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int saveCount;
  final int viewCount;
  final bool isLiked;
  final bool isSaved;
  final int? viewerRating;
  final int ratingCount;
  final String profileUsername;
  final bool isFollowingAuthor;
  final bool isVerifiedBadge;
  final bool showAd;
  final double adTriggerRatio;
  final bool ratingEnabled;
  final DateTime? publishedAt;

  bool get hasAvatar => avatarUrl.trim().isNotEmpty;

  String get views => _formatCount(viewCount);

  String get mediaUrl => mediaType == ReelMediaType.video
      ? (videoUrl.isEmpty ? imageUrl : videoUrl)
      : imageUrl;

  bool get isBite => feedType == ReelFeedType.bite;

  bool get hasFoodRatings =>
      foodRating != null ||
      serviceRating != null ||
      staffRating != null ||
      ambienceRating != null;

  bool get hasFoodDetails =>
      restaurant.trim().isNotEmpty ||
      dishName.trim().isNotEmpty ||
      hasFoodRatings;

  bool get needsBiteHydration =>
      !hasFoodDetails || locationName.trim().isEmpty;

  String get pinLocation {
    final restaurantName = restaurant.trim().toLowerCase();
    final loc = locationName.trim();
    if (loc.isNotEmpty && loc.toLowerCase() != restaurantName) {
      return loc;
    }
    if (city.isNotEmpty && city.toLowerCase() != restaurantName) {
      return city;
    }
    return loc.isNotEmpty ? loc : city;
  }

  double get foodOverall {
    final values = <double>[
      if (foodRating != null) foodRating!,
      if (serviceRating != null) serviceRating!,
      if (staffRating != null) staffRating!,
      if (ambienceRating != null) ambienceRating!,
    ];
    if (values.isEmpty) {
      return double.tryParse(rating) ?? 0;
    }
    return values.reduce((sum, value) => sum + value) / values.length;
  }

  ReelItemModel copyWith({
    String? id,
    ReelFeedType? feedType,
    ReelMediaType? mediaType,
    String? handle,
    String? caption,
    List<String>? tags,
    String? rating,
    String? likes,
    String? comments,
    String? imageUrl,
    String? imageAlt,
    String? avatarUrl,
    String? authorName,
    String? locationName,
    String? restaurant,
    String? dishName,
    double? foodRating,
    double? serviceRating,
    double? staffRating,
    double? ambienceRating,
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    String? videoUrl,
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? saveCount,
    int? viewCount,
    bool? isLiked,
    bool? isSaved,
    int? viewerRating,
    int? ratingCount,
    String? profileUsername,
    bool? isFollowingAuthor,
    bool? isVerifiedBadge,
    bool? showAd,
    double? adTriggerRatio,
    bool? ratingEnabled,
    DateTime? publishedAt,
    bool clearViewerRating = false,
  }) {
    return ReelItemModel(
      id: id ?? this.id,
      feedType: feedType ?? this.feedType,
      mediaType: mediaType ?? this.mediaType,
      handle: handle ?? this.handle,
      caption: caption ?? this.caption,
      tags: tags ?? this.tags,
      rating: rating ?? this.rating,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      imageUrl: imageUrl ?? this.imageUrl,
      imageAlt: imageAlt ?? this.imageAlt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authorName: authorName ?? this.authorName,
      locationName: locationName ?? this.locationName,
      restaurant: restaurant ?? this.restaurant,
      dishName: dishName ?? this.dishName,
      foodRating: foodRating ?? this.foodRating,
      serviceRating: serviceRating ?? this.serviceRating,
      staffRating: staffRating ?? this.staffRating,
      ambienceRating: ambienceRating ?? this.ambienceRating,
      city: city ?? this.city,
      country: country ?? this.country,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      videoUrl: videoUrl ?? this.videoUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      shareCount: shareCount ?? this.shareCount,
      saveCount: saveCount ?? this.saveCount,
      viewCount: viewCount ?? this.viewCount,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      viewerRating: clearViewerRating
          ? null
          : (viewerRating ?? this.viewerRating),
      ratingCount: ratingCount ?? this.ratingCount,
      profileUsername: profileUsername ?? this.profileUsername,
      isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
      isVerifiedBadge: isVerifiedBadge ?? this.isVerifiedBadge,
      showAd: showAd ?? this.showAd,
      adTriggerRatio: adTriggerRatio ?? this.adTriggerRatio,
      ratingEnabled: ratingEnabled ?? this.ratingEnabled,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }

  bool matchesCity(String query) {
    final key = query.trim().toLowerCase();
    if (key.isEmpty) {
      return true;
    }

    final fields = <String>[locationName, city, country, handle, authorName];

    return fields.any((field) => field.toLowerCase().contains(key));
  }

  ReelItemModel withFoodFrom(HomePostModel post) {
    final cityName = (city.trim().isNotEmpty ? city : post.authorCity).trim();
    var restaurantName = post.restaurant.trim().isNotEmpty
        ? post.restaurant.trim()
        : restaurant.trim();
    if (cityName.isNotEmpty &&
        restaurantName.toLowerCase() == cityName.toLowerCase()) {
      restaurantName = '';
    }
    if (restaurantName.isEmpty) {
      final location = post.location.trim();
      final pipe = location.indexOf('|');
      if (pipe > 0) {
        restaurantName = location.substring(0, pipe).trim();
      }
    }
    final next = copyWith(
      dishName: post.dishName.trim().isNotEmpty ? post.dishName : dishName,
      restaurant: restaurantName.isNotEmpty ? restaurantName : restaurant,
      foodRating: post.foodRating ?? foodRating,
      serviceRating: post.serviceRating ?? serviceRating,
      staffRating: post.staffRating ?? staffRating,
      ambienceRating: post.ambienceRating ?? ambienceRating,
      locationName: locationName.trim().isNotEmpty
          ? locationName
          : post.location,
      city: cityName,
      latitude: latitude ?? post.latitude,
      longitude: longitude ?? post.longitude,
    );
    if ((double.tryParse(next.rating) ?? 0) <= 0 && next.foodOverall > 0) {
      return next.copyWith(rating: next.foodOverall.toStringAsFixed(1));
    }
    return next;
  }

  factory ReelItemModel.fromJson(
    Map<String, dynamic> json, {
    required String responseType,
  }) {
    final author = _asMap(json['author']);
    final locationRaw = json['location'];
    final location = _asMap(locationRaw);
    final engagement = _asMap(json['engagement']);
    final viewerState = _asMap(json['viewer_state']);
    final media = (json['media'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final primaryMedia = media.isNotEmpty
        ? media.first
        : const <String, dynamic>{};
    final mediaType = _parseMediaType(
      json['primary_media_type'] ?? json['media_kind'],
    );
    final ratingAverage = _asDouble(engagement['rating_avg']);
    final username = (author['username'] ?? '').toString();
    final food = _asMap(json['food'] ?? json['food_details']);
    final restaurant = (json['restaurant'] ??
            json['restaurant_name'] ??
            food['restaurant'] ??
            food['restaurant_name'] ??
            '')
        .toString()
        .trim();
    final dishName = (json['dish_name'] ??
            json['dish'] ??
            food['dish_name'] ??
            food['name'] ??
            '')
        .toString()
        .trim();

    return ReelItemModel(
      id: (json['id'] ?? '').toString(),
      feedType: _parseFeedType(responseType, json['post_type']),
      mediaType: mediaType,
      handle: username.isEmpty ? '@stylebite' : '@$username',
      caption: (json['caption'] ?? '').toString(),
      tags: parsePostTags(json),
      rating: ratingAverage <= 0 ? '0.0' : ratingAverage.toStringAsFixed(1),
      likes: _formatCount(_asInt(engagement['like_count'])),
      comments: _formatCount(_asInt(engagement['comment_count'])),
      imageUrl: mediaType == ReelMediaType.video
          ? ((primaryMedia['thumbnail_url'] ?? primaryMedia['file_url'] ?? '')
                .toString())
          : ((primaryMedia['file_url'] ?? '').toString()),
      videoUrl: mediaType == ReelMediaType.video
          ? ((primaryMedia['file_url'] ?? '').toString())
          : '',
      imageAlt: (json['caption'] ?? 'Reel media').toString(),
      avatarUrl: (author['avatar_url'] ?? '').toString(),
      authorName: (author['display_name'] ?? author['username'] ?? '')
          .toString(),
      profileUsername: username,
      locationName: locationRaw is String
          ? locationRaw
          : (location['name'] ?? '').toString(),
      restaurant: restaurant,
      dishName: dishName,
      foodRating: _nullableDouble(
        json['food_rating'] ?? food['food_rating'] ?? engagement['food_rating'],
      ),
      serviceRating: _nullableDouble(
        json['service_rating'] ??
            food['service_rating'] ??
            engagement['service_rating'],
      ),
      staffRating: _nullableDouble(
        json['staff_rating'] ??
            food['staff_rating'] ??
            engagement['staff_rating'],
      ),
      ambienceRating: _nullableDouble(
        json['ambience_rating'] ??
            food['ambience_rating'] ??
            engagement['ambience_rating'],
      ),
      city: (location['city'] ?? '').toString(),
      country: (location['country'] ?? '').toString(),
      latitude: _nullableCoord(
        json['lat'] ??
            json['latitude'] ??
            location['lat'] ??
            location['latitude'] ??
            _asMap(location['coords'])['lat'],
      ),
      longitude: _nullableCoord(
        json['lng'] ??
            json['longitude'] ??
            location['lng'] ??
            location['longitude'] ??
            _asMap(location['coords'])['lng'],
      ),
      likeCount: _asInt(engagement['like_count']),
      commentCount: _asInt(engagement['comment_count']),
      shareCount: _asInt(engagement['share_count']),
      saveCount: _asInt(engagement['save_count']),
      viewCount: _asInt(engagement['view_count'] ?? json['view_count']),
      isLiked: _asBool(viewerState['is_liked']),
      isSaved: _asBool(viewerState['is_saved']),
      viewerRating: _nullableInt(viewerState['viewer_rating']),
      ratingCount: _asInt(engagement['rating_count'] ?? json['rating_count']),
      isFollowingAuthor: _asBool(author['is_following']),
      isVerifiedBadge: VerifiedBadgeCache.resolve(
        username,
        parseVerifiedFlag(json) || parseVerifiedFlag(author),
      ),
      showAd: _asBool(json['show_ad']),
      adTriggerRatio: _asDouble(json['ad_trigger_ratio'], fallback: 0.4),
      ratingEnabled: _asBool(json['in_contest']) ||
          ContestEnrollmentStore.instance.contains(
            (json['id'] ?? '').toString(),
          ),
      publishedAt: AppTimeFormatter.parse(
        (json['published_at'] ?? json['created_at'] ?? json['posted_at'])
            ?.toString(),
      ),
    );
  }

  HomePostModel toHomePost() {
    final username = profileUsername.trim().isNotEmpty
        ? profileUsername.trim()
        : handle.replaceFirst(RegExp(r'^@+'), '').trim();
    final isVideo = mediaType == ReelMediaType.video;
    final cover = imageUrl.trim().isNotEmpty ? imageUrl : videoUrl;
    return HomePostModel(
      id: id,
      feedType: isBite ? HomeFeedType.bite : HomeFeedType.style,
      mediaType: isVideo ? HomeMediaType.video : HomeMediaType.image,
      contentType: isBite ? HomeContentType.food : HomeContentType.fashion,
      username: username,
      location: locationName.trim().isNotEmpty ? locationName : city,
      restaurant: isBite
          ? (restaurant.trim().isNotEmpty ? restaurant.trim() : locationName.trim())
          : '',
      dishName: dishName,
      foodRating: foodRating,
      serviceRating: serviceRating,
      staffRating: staffRating,
      ambienceRating: ambienceRating,
      streakLabel: '',
      avatarUrl: avatarUrl,
      imageUrl: cover,
      displayRating: double.tryParse(rating) ?? 0,
      likes: likes,
      comments: comments,
      defaultSelectedRate: viewerRating ?? 0,
      ratingCount: ratingCount,
      caption: caption,
      mediaUrl: videoUrl,
      thumbnailUrl: imageUrl.trim().isEmpty ? null : imageUrl,
      isSaved: isSaved,
      isLiked: isLiked,
      authorName: authorName,
      media: [
        HomePostMedia(
          fileUrl: isVideo ? (videoUrl.isNotEmpty ? videoUrl : cover) : cover,
          type: isVideo ? HomeMediaType.video : HomeMediaType.image,
          thumbnailUrl: imageUrl.trim().isEmpty ? null : imageUrl,
        ),
      ],
      tags: tags,
      shareCount: shareCount,
      saveCount: saveCount,
      viewCount: viewCount,
      profileUsername: username,
      authorCity: city,
      isFollowingAuthor: isFollowingAuthor,
      isVerifiedBadge: isVerifiedBadge,
      ratingEnabled: ratingEnabled,
      latitude: latitude,
      longitude: longitude,
      publishedAt: publishedAt,
      postedAt: () {
        final published = publishedAt;
        if (published == null) {
          return 'Just now';
        }
        return AppTimeFormatter.formatPostTimeValue(published);
      }(),
    );
  }
}

ReelFeedType _parseFeedType(dynamic responseType, dynamic postType) {
  final item = (postType ?? '').toString().toLowerCase().trim();
  if (item == '2' || item.contains('food') || item.contains('bite')) {
    return ReelFeedType.bite;
  }
  if (item == '1' ||
      item.contains('outfit') ||
      item.contains('style') ||
      item.contains('fashion')) {
    return ReelFeedType.style;
  }
  final normalized = (responseType ?? '').toString().toLowerCase().trim();
  if (normalized == '2' ||
      normalized.contains('food') ||
      normalized.contains('bite')) {
    return ReelFeedType.bite;
  }
  return ReelFeedType.style;
}

ReelMediaType _parseMediaType(dynamic value) {
  final normalized = (value ?? '').toString().toLowerCase();
  if (normalized == 'video') {
    return ReelMediaType.video;
  }
  return ReelMediaType.image;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  return int.tryParse('${value ?? ''}') ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('${value ?? ''}') ?? fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final raw = (value ?? '').toString().toLowerCase();
  if (raw == 'true' || raw == '1') {
    return true;
  }
  if (raw == 'false' || raw == '0') {
    return false;
  }
  return fallback;
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

double? _nullableCoord(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value');
}

double? _nullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    final parsed = value.toDouble();
    return parsed <= 0 ? null : parsed;
  }
  final parsed = double.tryParse('$value');
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

int? _nullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  return int.tryParse('$value');
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const <String, dynamic>{};
}
