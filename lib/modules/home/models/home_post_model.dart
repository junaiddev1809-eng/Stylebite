import '../../../core/media/media_type_resolver.dart';
import '../../../core/utils/app_time_formatter.dart';
import '../../../core/utils/verified_flag.dart';
import '../../contest/services/contest_enrollment_store.dart';
import '../../upload/services/carousel_media_store.dart';

enum HomeFeedType { style, bite }

enum HomeMediaType { image, video }

enum HomeContentType { fashion, food }

class HomeFeedResponse {
  const HomeFeedResponse({
    required this.statusCode,
    required this.message,
    required this.type,
    required this.feed,
    required this.pagination,
  });

  final int statusCode;
  final String message;
  final String type;
  final List<HomePostModel> feed;
  final HomeFeedPagination pagination;

  factory HomeFeedResponse.fromJson(Map<String, dynamic> json) {
    return HomeFeedResponse(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      feed: (json['feed'] as List<dynamic>? ?? const [])
          .map(
            (item) => HomePostModel.fromJson(
              item as Map<String, dynamic>,
              responseType: (json['type'] ?? '').toString(),
            ),
          )
          .toList(growable: false),
      pagination: HomeFeedPagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}

class HomeFeedPagination {
  const HomeFeedPagination({
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

  factory HomeFeedPagination.fromJson(Map<String, dynamic> json) {
    return HomeFeedPagination(
      currentPage: _asInt(json['current_page']),
      perPage: _asInt(json['per_page']),
      total: _asInt(json['total']),
      lastPage: _asInt(json['last_page']),
      hasMorePages: _asBool(json['has_more_pages']),
    );
  }
}

class HomePostModel {
  const HomePostModel({
    required this.id,
    required this.feedType,
    required this.mediaType,
    required this.contentType,
    required this.username,
    required this.location,
    required this.streakLabel,
    required this.avatarUrl,
    required this.imageUrl,
    required this.displayRating,
    required this.likes,
    required this.comments,
    required this.defaultSelectedRate,
    this.ratingCount = 0,
    this.caption = '',
    this.postedAt = 'Just now',
    this.mediaUrl = '',
    this.thumbnailUrl,
    this.isSaved = false,
    this.isLiked = false,
    this.authorName = '',
    this.media = const [],
    this.tags = const [],
    this.tagsIncluded = false,
    this.shareCount = 0,
    this.saveCount = 0,
    this.viewCount = 0,
    this.allowComments = true,
    this.allowShares = true,
    this.ratingEnabled = false,
    this.dishName = '',
    this.restaurant = '',
    this.foodRating,
    this.serviceRating,
    this.staffRating,
    this.ambienceRating,
    this.profileUsername = '',
    this.authorCity = '',
    this.isFollowingAuthor = false,
    this.isVerifiedBadge = false,
    this.latitude,
    this.longitude,
    this.contestId = 0,
    this.contestTitle = '',
    this.isContestWinner = false,
    this.visibility = '',
    this.publishedAt,
  });

  final String id;
  final HomeFeedType feedType;
  final HomeMediaType mediaType;
  final HomeContentType contentType;
  final String username;
  final String location;
  final String streakLabel;
  final String avatarUrl;
  final String imageUrl;
  final double displayRating;
  final String likes;
  final String comments;
  final int defaultSelectedRate;
  final int ratingCount;
  final String caption;
  final String postedAt;
  final String mediaUrl;
  final String? thumbnailUrl;
  final bool isSaved;
  final bool isLiked;
  final String authorName;
  final List<HomePostMedia> media;
  final List<String> tags;

  /// True when the payload contained a `tags` key, including an empty list.
  final bool tagsIncluded;

  /// Detail hydration is only for payloads that omitted tags entirely.
  /// Caption hashtags are already parsed, and an empty list means the post
  /// has no hashtags.
  bool get needsHashtagHydration => !tagsIncluded && tags.isEmpty;

  final int shareCount;
  final int saveCount;
  final int viewCount;
  final bool allowComments;
  final bool allowShares;
  final bool ratingEnabled;
  final String dishName;
  final String restaurant;
  final double? foodRating;
  final double? serviceRating;
  final double? staffRating;
  final double? ambienceRating;
  final String profileUsername;
  final String authorCity;
  final double? latitude;
  final double? longitude;
  final bool isFollowingAuthor;
  final bool isVerifiedBadge;

  /// Contest this post is entered in (0 / empty when not in a contest).
  final int contestId;
  final String contestTitle;
  final bool isContestWinner;

  /// `public`, `followers_only` or `private`; empty when the payload did
  /// not include it.
  final String visibility;

  /// Raw publish time used by trending. [postedAt] is the display label.
  final DateTime? publishedAt;

  bool get isInContest => contestId > 0 || contestTitle.trim().isNotEmpty;

  bool get hasAvatar => avatarUrl.isNotEmpty;
  bool get isFoodPost => contentType == HomeContentType.food;
  String get displayLocation {
    return _extractCity(location);
  }

  String get headerSubtitle {
    final loc = displayLocation;
    if (loc.isEmpty) {
      return postedAt;
    }
    return '$loc • $postedAt';
  }

  String get biteHeaderSubtitle {
    final name = restaurant.trim();
    if (name.isEmpty) {
      return postedAt;
    }
    if (postedAt.trim().isEmpty) {
      return name;
    }
    return '$name • $postedAt';
  }

  String get bitePinLocation {
    final restaurantName = restaurant.trim().toLowerCase();
    final city = displayLocation.trim();
    if (city.isNotEmpty && city.toLowerCase() != restaurantName) {
      return city;
    }
    final cityFromAuthor = authorCity.trim();
    if (cityFromAuthor.isNotEmpty &&
        cityFromAuthor.toLowerCase() != restaurantName &&
        !_isProvinceName(cityFromAuthor.toLowerCase())) {
      return cityFromAuthor;
    }
    return city;
  }

  bool get hasFoodRatings =>
      foodRating != null ||
      serviceRating != null ||
      staffRating != null ||
      ambienceRating != null;

  List<String> get displayTags {
    final seen = <String>{};
    final result = <String>[];
    for (final tag in [...tags, ...hashtagsFromCaption(caption)]) {
      final normalized = normalizeHashtag(tag);
      final key = normalized.toLowerCase();
      if (normalized.isEmpty || !seen.add(key)) {
        continue;
      }
      result.add(normalized);
      if (result.length >= 5) {
        break;
      }
    }
    return result;
  }

  bool containsHashtag(String rawTag) {
    final needle = normalizeHashtag(rawTag).toLowerCase();
    if (needle.isEmpty) {
      return false;
    }
    for (final tag in tags) {
      if (normalizeHashtag(tag).toLowerCase() == needle) {
        return true;
      }
    }
    return caption.toLowerCase().contains(needle);
  }

  String get primaryMediaUrl => mediaUrl.isEmpty ? imageUrl : mediaUrl;

  List<String> get carouselImageUrls {
    final seen = <String>{};
    final urls = <String>[];
    for (final item in media) {
      if (item.type != HomeMediaType.image) {
        continue;
      }
      final url = item.fileUrl.trim();
      if (url.isEmpty || !seen.add(url)) {
        continue;
      }
      urls.add(url);
    }
    if (urls.length >= 2) {
      return urls;
    }
    final local = CarouselMediaStore.pathsFor(id);
    if (local.length >= 2) {
      return local;
    }
    return const <String>[];
  }

  bool get isCarousel => carouselImageUrls.length >= 2;

  AppMediaType get resolvedMediaType {
    if (mediaType == HomeMediaType.video) {
      return AppMediaType.video;
    }
    return MediaTypeResolver.resolve(
      primaryMediaUrl,
      fallback: AppMediaType.image,
    );
  }

  HomePostModel copyWith({
    String? id,
    HomeFeedType? feedType,
    HomeMediaType? mediaType,
    HomeContentType? contentType,
    String? username,
    String? location,
    String? streakLabel,
    String? avatarUrl,
    String? imageUrl,
    double? displayRating,
    String? likes,
    String? comments,
    int? defaultSelectedRate,
    int? ratingCount,
    String? caption,
    String? postedAt,
    String? mediaUrl,
    String? thumbnailUrl,
    bool? isSaved,
    bool? isLiked,
    String? authorName,
    List<HomePostMedia>? media,
    List<String>? tags,
    bool? tagsIncluded,
    int? shareCount,
    int? saveCount,
    int? viewCount,
    bool? allowComments,
    bool? allowShares,
    bool? ratingEnabled,
    String? dishName,
    String? restaurant,
    double? foodRating,
    double? serviceRating,
    double? staffRating,
    double? ambienceRating,
    String? profileUsername,
    String? authorCity,
    bool? isFollowingAuthor,
    bool? isVerifiedBadge,
    double? latitude,
    double? longitude,
    int? contestId,
    String? contestTitle,
    bool? isContestWinner,
    String? visibility,
    DateTime? publishedAt,
  }) {
    return HomePostModel(
      id: id ?? this.id,
      feedType: feedType ?? this.feedType,
      mediaType: mediaType ?? this.mediaType,
      contentType: contentType ?? this.contentType,
      username: username ?? this.username,
      location: location ?? this.location,
      streakLabel: streakLabel ?? this.streakLabel,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      displayRating: displayRating ?? this.displayRating,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      defaultSelectedRate: defaultSelectedRate ?? this.defaultSelectedRate,
      ratingCount: ratingCount ?? this.ratingCount,
      caption: caption ?? this.caption,
      postedAt: postedAt ?? this.postedAt,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      isSaved: isSaved ?? this.isSaved,
      isLiked: isLiked ?? this.isLiked,
      authorName: authorName ?? this.authorName,
      media: media ?? this.media,
      tags: tags ?? this.tags,
      tagsIncluded: tagsIncluded ?? this.tagsIncluded,
      shareCount: shareCount ?? this.shareCount,
      saveCount: saveCount ?? this.saveCount,
      viewCount: viewCount ?? this.viewCount,
      allowComments: allowComments ?? this.allowComments,
      allowShares: allowShares ?? this.allowShares,
      ratingEnabled: ratingEnabled ?? this.ratingEnabled,
      dishName: dishName ?? this.dishName,
      restaurant: restaurant ?? this.restaurant,
      foodRating: foodRating ?? this.foodRating,
      serviceRating: serviceRating ?? this.serviceRating,
      staffRating: staffRating ?? this.staffRating,
      ambienceRating: ambienceRating ?? this.ambienceRating,
      profileUsername: profileUsername ?? this.profileUsername,
      authorCity: authorCity ?? this.authorCity,
      isFollowingAuthor: isFollowingAuthor ?? this.isFollowingAuthor,
      isVerifiedBadge: isVerifiedBadge ?? this.isVerifiedBadge,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      contestId: contestId ?? this.contestId,
      contestTitle: contestTitle ?? this.contestTitle,
      isContestWinner: isContestWinner ?? this.isContestWinner,
      visibility: visibility ?? this.visibility,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }

  factory HomePostModel.fromJson(
    Map<String, dynamic> json, {
    required String responseType,
  }) {
    // Support both slim (flat) and legacy (nested) payloads with safe checks
    final authorJson = json['author'] is Map ? asStringKeyedMap(json['author']) : null;
    final locationJson = json['location'] is Map ? asStringKeyedMap(json['location']) : null;
    final engagementJson =
        json['engagement'] is Map ? asStringKeyedMap(json['engagement']) : null;
    final viewerStateJson = json['viewer_state'] is Map
        ? asStringKeyedMap(json['viewer_state'])
        : null;
    final foodJson = json['food'] is Map
        ? asStringKeyedMap(json['food'])
        : json['food_details'] is Map
            ? asStringKeyedMap(json['food_details'])
            : null;

    final author = HomePostAuthor.fromJson(authorJson ?? const {});
    final location = HomePostLocation.fromJson(locationJson ?? const {});
    final engagement = HomePostEngagement.fromJson(engagementJson ?? const {});
    final viewerState = HomePostViewerState.fromJson(viewerStateJson ?? const {});
    final locationCoords = locationJson != null && locationJson['coords'] is Map
        ? asStringKeyedMap(locationJson['coords'])
        : const <String, dynamic>{};

    // Contest badge: prefer the API's `contest` object, fall back to the
    // client-side enrollment store (live feed has no contest metadata).
    final postIdText = _asInt(json['id']).toString();
    final contestJson =
        json['contest'] is Map ? asStringKeyedMap(json['contest']) : null;
    final storedEnrollment = ContestEnrollmentStore.instance.infoFor(postIdText);
    final contestId = contestJson != null
        ? _asInt(contestJson['id'])
        : (storedEnrollment?.contestId ?? 0);
    final contestTitle = contestJson != null
        ? (contestJson['title'] ?? '').toString().trim()
        : (storedEnrollment?.contestTitle ?? '');

    final media = parsePostMedia(json);

    final primaryMedia = media.isNotEmpty ? media.first : null;
    final feedType = _parseFeedType(responseType, json['post_type'] ?? json['type']);
    final contentType = _parseContentType(responseType, json['content_type'] ?? json['type']);

    // Media handling for slim payload (flat media_url/type)
    final mediaType = _parseMediaType(
      json['media_type'] ??
          json['primary_media_type'] ??
          json['media_kind'] ??
          (primaryMedia?.type.name),
    );

    final String rawMediaUrl = (json['media_url'] ??
            primaryMedia?.fileUrl ??
            json['image_url'] ??
            '')
        .toString();
    final String rawImageUrl = (json['image_url'] ??
            primaryMedia?.previewUrl ??
            json['preview_url'] ??
            '')
        .toString();

    return HomePostModel(
      id: (json['id'] ?? '').toString(),
      feedType: feedType,
      mediaType: mediaType,
      contentType: contentType,
      username: _normalizeUsername(
          (json['username'] ?? author.username).toString()),
      location: _composeLocationLabel(
        raw: json['location'] is String
            ? json['location'] as String
            : location.displayLabel,
        city: (json['city'] ?? locationJson?['city'] ?? location.city).toString(),
      ),
      streakLabel: (json['streak_label'] ?? '').toString(),
      avatarUrl: (json['avatar_url'] ?? author.avatarUrl).toString(),
      imageUrl: rawImageUrl,
      mediaUrl: mediaType == HomeMediaType.video ? rawMediaUrl : '',
      thumbnailUrl:
          _nullableString(json['thumbnail_url'] ?? primaryMedia?.thumbnailUrl),
      displayRating: _asDouble(json['rating_avg'] ?? engagement.ratingAverage),
      likes: _formatCount(_asInt(json['likes_count'] ?? engagement.likeCount)),
      comments:
          _formatCount(_asInt(json['comments_count'] ?? engagement.commentCount)),
      defaultSelectedRate:
          _asInt(json['viewer_rating'] ?? viewerState.viewerRating ?? 0)
              .clamp(0, 5),
      ratingCount: _asInt(
        json['rating_count'] ?? engagement.ratingCount,
      ),
      caption: (json['caption'] ?? '').toString(),
      postedAt: _resolvePostedAt(json),
      isSaved: _asBool(json['is_saved'] ?? viewerState.isSaved),
      isLiked: _asBool(json['is_liked'] ?? viewerState.isLiked),
      authorName: (json['author_name'] ?? author.displayName).toString(),
      media: media,
      tags: _uniqueHashtags([
        ...parsePostTags(json),
        ...hashtagsFromCaption((json['caption'] ?? '').toString()),
      ]),
      tagsIncluded: json.containsKey('tags'),
      shareCount: _asInt(json['share_count'] ?? engagement.shareCount),
      saveCount: _asInt(json['save_count'] ?? engagement.saveCount),
      viewCount: _asInt(json['view_count'] ?? engagement.viewCount),
      allowComments: _asBool(json['allow_comments'], fallback: true),
      allowShares: _asBool(json['allow_shares'], fallback: true),
      // Contest voting only — never trust legacy rating_enabled on normal posts.
      ratingEnabled: _asBool(json['in_contest'], fallback: false) ||
          storedEnrollment != null,
      dishName: (json['dish_name'] ??
              json['dish'] ??
              foodJson?['dish_name'] ??
              foodJson?['name'] ??
              '')
          .toString(),
      restaurant: (json['restaurant'] ??
              json['restaurant_name'] ??
              foodJson?['restaurant'] ??
              foodJson?['restaurant_name'] ??
              '')
          .toString(),
      foodRating: _nullableRating(
          _asNullableDouble(json['food_rating'] ??
              foodJson?['food_rating'] ??
              engagement.foodRating)),
      serviceRating: _nullableRating(_asNullableDouble(
          json['service_rating'] ??
              foodJson?['service_rating'] ??
              engagement.serviceRating)),
      staffRating: _nullableRating(
          _asNullableDouble(json['staff_rating'] ??
              foodJson?['staff_rating'] ??
              engagement.staffRating)),
      ambienceRating: _nullableRating(_asNullableDouble(
          json['ambience_rating'] ??
              foodJson?['ambience_rating'] ??
              engagement.ambienceRating)),
      profileUsername: (json['username'] ?? author.username).toString(),
      authorCity: (json['author_city'] ?? author.city).toString(),
      isFollowingAuthor: _asBool(json['is_following'] ?? author.isFollowing),
      isVerifiedBadge: VerifiedBadgeCache.resolve(
        (json['username'] ?? author.username).toString(),
        parseVerifiedFlag(json) ||
            parseVerifiedFlag(authorJson) ||
            author.isVerifiedBadge,
      ),
      latitude: _asNullableDouble(
        json['lat'] ??
            json['latitude'] ??
            locationJson?['lat'] ??
            locationJson?['latitude'] ??
            locationCoords['lat'] ??
            location.latitude,
      ),
      longitude: _asNullableDouble(
        json['lng'] ??
            json['longitude'] ??
            locationJson?['lng'] ??
            locationJson?['longitude'] ??
            locationCoords['lng'] ??
            location.longitude,
      ),
      contestId: contestId,
      contestTitle: contestTitle,
      isContestWinner: _asBool(json['is_contest_winner']),
      visibility: (json['visibility'] ?? '').toString().trim().toLowerCase(),
      publishedAt: AppTimeFormatter.parse(
        (json['published_at'] ?? json['created_at'] ?? json['posted_at'])
            ?.toString(),
      ),
    );
  }
}

class HomePostMedia {
  const HomePostMedia({
    required this.fileUrl,
    required this.type,
    this.thumbnailUrl,
  });

  final String fileUrl;
  final HomeMediaType type;
  final String? thumbnailUrl;

  String get previewUrl =>
      thumbnailUrl?.isNotEmpty == true ? thumbnailUrl! : fileUrl;

  factory HomePostMedia.fromJson(Map<String, dynamic> json) {
    return HomePostMedia(
      fileUrl: _firstMediaUrl(json),
      thumbnailUrl: _nullableString(
        json['thumbnail_url'] ?? json['preview_url'] ?? json['thumb_url'],
      ),
      type: _parseMediaType(
        json['media_type'] ?? json['mime_type'] ?? json['type'],
      ),
    );
  }
}

List<HomePostMedia> parsePostMedia(Map<String, dynamic> json) {
  final seen = <String>{};
  final items = <HomePostMedia>[];

  void add(HomePostMedia item) {
    final url = item.fileUrl.trim();
    if (url.isEmpty || url == 'null' || !seen.add(url)) {
      return;
    }
    if (item.type != HomeMediaType.image && item.type != HomeMediaType.video) {
      return;
    }
    items.add(item);
  }

  void walk(dynamic raw) {
    if (raw == null) {
      return;
    }
    if (raw is String) {
      final value = raw.trim();
      if (value.isEmpty || value == 'null') {
        return;
      }
      add(HomePostMedia(fileUrl: value, type: HomeMediaType.image));
      return;
    }
    if (raw is List) {
      for (final item in raw) {
        walk(item);
      }
      return;
    }
    if (raw is Map) {
      final map = raw.map((key, value) => MapEntry(key.toString(), value));
      final nested = map['data'] ?? map['items'];
      if (nested is List || nested is Map) {
        walk(nested);
        return;
      }
      final looksLikeMedia = map.containsKey('file_url') ||
          map.containsKey('original_url') ||
          map.containsKey('url') ||
          map.containsKey('image_url') ||
          map.containsKey('media_url');
      if (!looksLikeMedia &&
          map.values.any((value) => value is Map || value is List)) {
        for (final value in map.values) {
          walk(value);
        }
        return;
      }
      add(HomePostMedia.fromJson(map));
    }
  }

  for (final key in <String>[
    'media',
    'images',
    'gallery',
    'files',
    'photos',
    'attachments',
  ]) {
    walk(json[key]);
  }
  return items;
}

String _firstMediaUrl(Map<String, dynamic> json) {
  for (final key in <String>[
    'file_url',
    'original_url',
    'url',
    'image_url',
    'media_url',
    'full_url',
    'src',
    'path',
  ]) {
    final value = (json[key] ?? '').toString().trim();
    if (value.isNotEmpty && value != 'null') {
      return value;
    }
  }
  final nested = json['file'];
  if (nested is Map) {
    return _firstMediaUrl(
      nested.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
  return '';
}

class HomePostAuthor {
  const HomePostAuthor({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.city,
    required this.isFollowing,
    required this.isVerifiedBadge,
  });

  final String username;
  final String displayName;
  final String avatarUrl;
  final String city;
  final bool isFollowing;
  final bool isVerifiedBadge;

  factory HomePostAuthor.fromJson(Map<String, dynamic> json) {
    return HomePostAuthor(
      username: (json['username'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['full_name'] ?? '').toString(),
      avatarUrl: _nullableString(json['avatar_url']) ?? '',
      city: (json['city'] ?? json['current_city'] ?? '').toString(),
      isFollowing: _asBool(json['is_following']),
      isVerifiedBadge: VerifiedBadgeCache.resolve(
        json['username']?.toString(),
        parseVerifiedFlag(json),
      ),
    );
  }
}

class HomePostLocation {
  const HomePostLocation({
    required this.name,
    required this.city,
    required this.country,
    this.latitude,
    this.longitude,
  });

  final String name;
  final String city;
  final String country;
  final double? latitude;
  final double? longitude;

  String get displayLabel {
    final parts = [
      name,
      city,
      country,
    ].where((item) => item.trim().isNotEmpty).toSet().toList(growable: false);
    if (parts.isEmpty) {
      return '';
    }
    return parts.join(', ');
  }

  factory HomePostLocation.fromJson(Map<String, dynamic> json) {
    return HomePostLocation(
      name: (json['name'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      country: (json['country'] ?? '').toString(),
      latitude: _asNullableDouble(json['lat'] ?? json['latitude']),
      longitude: _asNullableDouble(json['lng'] ?? json['longitude']),
    );
  }
}

String _composeLocationLabel({required String raw, required String city}) {
  final trimmedRaw = raw.trim();
  final trimmedCity = city.trim();
  if (trimmedCity.isEmpty) {
    return trimmedRaw;
  }
  if (trimmedRaw.isEmpty || _isProvinceName(trimmedRaw.toLowerCase())) {
    return trimmedRaw.isEmpty ? trimmedCity : '$trimmedCity, $trimmedRaw';
  }
  return trimmedRaw;
}

String _extractCity(String rawLocation) {
  final raw = rawLocation.trim();
  if (raw.isEmpty || raw.toLowerCase() == 'unknown location') {
    return '';
  }

  final parts = raw
      .split(RegExp(r'[,|]'))
      .map(_normalizePlacePart)
      .where((part) => part.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return '';
  }

  String? city;
  String? province;
  for (var i = parts.length - 1; i >= 0; i--) {
    final part = parts[i];
    final key = part.toLowerCase();
    if (_isCountryName(key)) {
      continue;
    }
    if (_isProvinceName(key)) {
      province ??= part;
      continue;
    }
    city = part;
    break;
  }

  return city ?? province ?? parts.first;
}

String _normalizePlacePart(String value) {
  return value
      .replaceAll(RegExp(r'\s+\d{3,6}\b.*$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isCountryName(String value) {
  return _countryNames.contains(value);
}

bool _isProvinceName(String value) {
  return _provinceNames.contains(value);
}

const _countryNames = <String>{
  'pakistan',
  'india',
  'united states',
  'united states of america',
  'usa',
  'uk',
  'united kingdom',
  'uae',
  'united arab emirates',
  'canada',
  'australia',
  'saudi arabia',
};

const _provinceNames = <String>{
  'punjab',
  'sindh',
  'balochistan',
  'baluchistan',
  'khyber pakhtunkhwa',
  'khyber-pakhtunkhwa',
  'kpk',
  'kp',
  'gilgit-baltistan',
  'gilgit baltistan',
  'azad kashmir',
  'azad jammu and kashmir',
  'ajk',
  'islamabad capital territory',
  'ict',
  'capital territory',
};

class HomePostEngagement {
  const HomePostEngagement({
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.saveCount,
    required this.viewCount,
    required this.ratingAverage,
    this.ratingCount = 0,
    required this.foodRating,
    required this.serviceRating,
    required this.staffRating,
    required this.ambienceRating,
  });

  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int saveCount;
  final int viewCount;
  final double ratingAverage;
  final int ratingCount;
  final double? foodRating;
  final double? serviceRating;
  final double? staffRating;
  final double? ambienceRating;

  factory HomePostEngagement.fromJson(Map<String, dynamic> json) {
    return HomePostEngagement(
      likeCount: _asInt(json['like_count']),
      commentCount: _asInt(json['comment_count']),
      shareCount: _asInt(json['share_count']),
      saveCount: _asInt(json['save_count']),
      viewCount: _asInt(json['view_count']),
      ratingAverage: _asDouble(json['rating_avg']),
      ratingCount: _asInt(json['rating_count']),
      foodRating: _asNullableDouble(json['food_rating']),
      serviceRating: _asNullableDouble(json['service_rating']),
      staffRating: _asNullableDouble(json['staff_rating']),
      ambienceRating: _asNullableDouble(json['ambience_rating']),
    );
  }
}

class HomePostViewerState {
  const HomePostViewerState({
    required this.isLiked,
    required this.isSaved,
    this.viewerRating,
  });

  final bool isLiked;
  final bool isSaved;
  final double? viewerRating;

  factory HomePostViewerState.fromJson(Map<String, dynamic> json) {
    return HomePostViewerState(
      isLiked: _asBool(json['is_liked']),
      isSaved: _asBool(json['is_saved']),
      viewerRating: json['viewer_rating'] == null
          ? null
          : _asDouble(json['viewer_rating']),
    );
  }
}

class HomeQuickAction {
  const HomeQuickAction({required this.icon, required this.showDot});

  final Object icon;
  final bool showDot;
}

HomeFeedType _parseFeedType(dynamic responseType, dynamic contentType) {
  final item = '${contentType ?? ''}'.toLowerCase().trim();
  if (item == '2' || item.contains('food') || item.contains('bite')) {
    return HomeFeedType.bite;
  }
  if (item == '1' ||
      item.contains('outfit') ||
      item.contains('style') ||
      item.contains('fashion')) {
    return HomeFeedType.style;
  }
  final raw = '${responseType ?? ''}'.toLowerCase().trim();
  if (raw == '2' || raw.contains('food') || raw.contains('bite')) {
    return HomeFeedType.bite;
  }
  return HomeFeedType.style;
}

HomeContentType _parseContentType(dynamic responseType, dynamic contentType) {
  final item = '${contentType ?? ''}'.toLowerCase();
  if (item.contains('food') || item.contains('bite')) {
    return HomeContentType.food;
  }
  if (item.contains('outfit') ||
      item.contains('style') ||
      item.contains('fashion')) {
    return HomeContentType.fashion;
  }
  final raw = '${responseType ?? ''}'.toLowerCase();
  if (raw.contains('food') || raw.contains('bite')) {
    return HomeContentType.food;
  }
  return HomeContentType.fashion;
}

HomeMediaType _parseMediaType(dynamic value) {
  final raw = (value ?? '').toString().toLowerCase();
  if (raw.contains('video')) {
    return HomeMediaType.video;
  }
  return HomeMediaType.image;
}

String _normalizeUsername(String value) {
  if (value.isEmpty) {
    return '@stylebite';
  }
  return value.startsWith('@') ? value : '@$value';
}

String _resolvePostedAt(Map<String, dynamic> json) {
  final publishedAt = _nullableString(json['published_at']);
  final postedAt = _nullableString(json['posted_at']);
  final createdAt = _nullableString(json['created_at']);
  return AppTimeFormatter.formatPostTime(publishedAt ?? postedAt ?? createdAt);
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

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return double.tryParse('${value ?? ''}')?.toInt() ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('${value ?? ''}') ?? fallback;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('${value ?? ''}');
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

String? _nullableString(dynamic value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty || normalized == 'null') {
    return null;
  }
  return normalized;
}

double? _nullableRating(double? value) {
  if (value == null) {
    return null;
  }
  if (value <= 0) {
    return null;
  }
  return value;
}

List<String> hashtagsFromCaption(String caption) {
  return parseTagValues(
    _hashtagCaptionPattern.allMatches(caption)
        .map((match) => match.group(0))
        .toList(),
  );
}

List<String> _uniqueHashtags(Iterable<String> values) {
  final seen = <String>{};
  final tags = <String>[];
  for (final value in values) {
    final normalized = normalizeHashtag(value);
    final key = normalized.toLowerCase();
    if (normalized.isEmpty || !seen.add(key)) {
      continue;
    }
    tags.add(normalized);
  }
  return tags;
}

final _hashtagCaptionPattern = RegExp(r'#[^\s#.,;:!?]+');

List<String> parsePostTags(Map<String, dynamic> json) {
  return parseTagValues(
    json['tags'] ??
        json['hashtags'] ??
        json['hash_tags'] ??
        json['post_tags'] ??
        json['tag_list'],
  );
}

List<String> parseTagValues(dynamic raw) {
  if (raw == null) {
    return const <String>[];
  }
  if (raw is String) {
    return parseTagValues(
      raw
          .split(RegExp(r'[,;]+'))
          .expand((part) => part.trim().split(RegExp(r'\s+')))
          .toList(),
    );
  }
  if (raw is Map) {
    return parseTagValues(raw['data'] ?? raw['tags'] ?? raw['hashtags']);
  }
  if (raw is! Iterable) {
    final normalized = normalizeHashtag(raw.toString());
    return normalized.isEmpty ? const <String>[] : <String>[normalized];
  }

  final seen = <String>{};
  final tags = <String>[];
  for (final item in raw) {
    String value;
    if (item is Map) {
      value = (item['name'] ??
              item['tag'] ??
              item['slug'] ??
              item['title'] ??
              item['label'] ??
              item['value'] ??
              '')
          .toString();
    } else {
      value = item.toString();
    }
    final normalized = normalizeHashtag(value);
    final key = normalized.toLowerCase();
    if (normalized.isEmpty || !seen.add(key)) {
      continue;
    }
    tags.add(normalized);
  }
  return tags;
}

String normalizeHashtag(String value) {
  final cleaned = value.trim().replaceFirst(RegExp(r'^#+'), '').trim();
  if (cleaned.isEmpty || cleaned.toLowerCase() == 'null') {
    return '';
  }
  return '#$cleaned';
}
