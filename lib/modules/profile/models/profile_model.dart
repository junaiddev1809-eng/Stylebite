import '../../contest/services/contest_enrollment_store.dart';
import '../../upload/services/carousel_media_store.dart';
import '../../home/models/home_post_model.dart';
import '../../../core/utils/app_time_formatter.dart';
import '../../../core/utils/verified_flag.dart';

enum ProfileContentTab { outfits, saved, food, more }

class ProfileOverviewResponseModel {
  const ProfileOverviewResponseModel({
    required this.statusCode,
    required this.message,
    required this.overview,
  });

  final int statusCode;
  final String message;
  final ProfileOverviewModel overview;

  factory ProfileOverviewResponseModel.fromMap(Map<String, dynamic> map) {
    return ProfileOverviewResponseModel(
      statusCode: _asInt(map['status_code']),
      message: _asString(map['message']),
      overview: ProfileOverviewModel.fromMap(map),
    );
  }
}

class ProfileOverviewModel {
  const ProfileOverviewModel({
    required this.user,
    required this.outfitPosts,
    required this.outfitPagination,
    required this.foodPosts,
    required this.foodPagination,
    required this.savedPosts,
    required this.savedPagination,
  });

  final ProfileUserModel user;
  final List<ProfilePostModel> outfitPosts;
  final ProfilePaginationModel outfitPagination;
  final List<ProfilePostModel> foodPosts;
  final ProfilePaginationModel foodPagination;
  final List<SavedProfilePostModel> savedPosts;
  final ProfilePaginationModel savedPagination;

  factory ProfileOverviewModel.fromMap(Map<String, dynamic> map) {
    return ProfileOverviewModel(
      user: ProfileUserModel.fromMap(
        (map['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
      outfitPosts: _mapList(
        map['outfit_posts'],
        (item) => ProfilePostModel.fromMap(item),
      ),
      outfitPagination: ProfilePaginationModel.fromMap(
        (map['outfit_pagination'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      foodPosts: _mapList(
        map['food_posts'],
        (item) => ProfilePostModel.fromMap(item),
      ),
      foodPagination: ProfilePaginationModel.fromMap(
        (map['food_pagination'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
      savedPosts: _mapList(
        map['saved_posts'],
        (item) => SavedProfilePostModel.fromMap(item),
      ),
      savedPagination: ProfilePaginationModel.fromMap(
        (map['saved_pagination'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
      ),
    );
  }
}

class ProfileUserModel {
  const ProfileUserModel({
    required this.id,
    required this.profileId,
    required this.username,
    required this.displayName,
    required this.fullName,
    required this.headline,
    required this.bio,
    required this.websiteUrl,
    required this.avatarUrl,
    required this.coverUrl,
    required this.city,
    required this.country,
    required this.gender,
    required this.birthDate,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.timezone,
    required this.visibility,
    required this.isPrivate,
    required this.isVerifiedBadge,
    required this.isSelf,
    required this.isFollowing,
    required this.followsYou,
    required this.isMutualFollow,
    required this.emailVerifiedAt,
    required this.phoneVerifiedAt,
    required this.vibeCount,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
    required this.reelCount,
    required this.stylePoints,
    required this.currentStreakDays,
    required this.currentStreakLabel,
    required this.contestWins,
    required this.contestEntries,
    required this.battleWins,
    required this.battleRankLabel,
    required this.memoryCount,
    required this.savedPostCount,
    required this.totalPostLikes,
  });

  final int id;
  final int profileId;
  final String username;
  final String displayName;
  final String fullName;
  final String headline;
  final String bio;
  final String websiteUrl;
  final String avatarUrl;
  final String coverUrl;
  final String city;
  final String country;
  final String gender;
  final String birthDate;
  final String phoneCountryCode;
  final String phoneNumber;
  final String timezone;
  final String visibility;
  final bool isPrivate;
  final bool isVerifiedBadge;
  final bool isSelf;
  final bool isFollowing;
  final bool followsYou;
  final bool isMutualFollow;
  final String emailVerifiedAt;
  final String phoneVerifiedAt;
  final int vibeCount;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final int reelCount;
  final int stylePoints;
  final int currentStreakDays;
  final String currentStreakLabel;
  final int contestWins;
  final int contestEntries;
  final int battleWins;
  final String battleRankLabel;
  final int memoryCount;
  final int savedPostCount;
  final int totalPostLikes;

  factory ProfileUserModel.fromMap(Map<String, dynamic> map) {
    final relationship =
        (map['relationship'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    return ProfileUserModel(
      id: _asInt(map['id']),
      profileId: _asInt(map['profile_id']),
      username: _asString(map['username']),
      displayName: _asString(map['display_name']),
      fullName: _asString(map['full_name']),
      headline: _asString(map['headline']),
      bio: _asString(map['bio']),
      websiteUrl: _asString(map['website_url']),
      avatarUrl: _asString(map['avatar_url']),
      coverUrl: _asString(map['cover_url']),
      city: _asString(map['city']),
      country: _asString(map['country']),
      gender: _asString(map['gender']),
      birthDate: _asString(map['birth_date']),
      phoneCountryCode: _asString(map['phone_country_code']),
      phoneNumber: _asString(map['phone_number']),
      timezone: _asString(map['timezone']),
      visibility: _asString(map['visibility']),
      isPrivate: _asBool(map['is_private']),
      isVerifiedBadge: _rememberVerified(
        map['username'],
        parseVerifiedFlag(map, relationship),
      ),
      isSelf: _asBool(map['is_self']),
      isFollowing: _asBool(relationship['is_following'] ?? map['is_following']),
      followsYou: _asBool(relationship['follows_you'] ?? map['follows_you']),
      isMutualFollow: _asBool(
        relationship['is_mutual_follow'] ?? map['is_mutual_follow'],
      ),
      emailVerifiedAt: _asString(map['email_verified_at']),
      phoneVerifiedAt: _asString(map['phone_verified_at']),
      vibeCount: _asInt(map['vibe_count']),
      followerCount: _asInt(map['follower_count']),
      followingCount: _asInt(map['following_count']),
      postCount: _asInt(map['post_count']),
      reelCount: _asInt(map['reel_count']),
      stylePoints: _asInt(map['style_points']),
      currentStreakDays: _asInt(map['current_streak_days']),
      currentStreakLabel: _asString(map['current_streak_label']),
      contestWins: _asInt(map['contest_wins']),
      contestEntries: _asInt(map['contest_entries']),
      battleWins: _asInt(map['battle_wins']),
      battleRankLabel: _asString(map['battle_rank_label']),
      memoryCount: _asInt(map['memory_count']),
      savedPostCount: _asInt(map['saved_post_count']),
      totalPostLikes: _asInt(map['total_post_likes']),
    );
  }

  bool get canRequestVerification {
    return emailVerifiedAt.trim().isNotEmpty ||
        phoneVerifiedAt.trim().isNotEmpty;
  }

  String get websiteUrlOrEmpty => websiteUrl;
  String get genderOrEmpty => gender;
  String get birthDateOrEmpty => birthDate;
  String get phoneCountryCodeOrEmpty => phoneCountryCode;
  String get phoneNumberOrEmpty => phoneNumber;
  String get timezoneOrEmpty => timezone;
  String get locationLabel {
    for (final candidate in <String>[
      city,
      country,
      headline,
      bio,
      displayName,
      fullName,
      username,
    ]) {
      final value = candidate.trim();
      if (value.isNotEmpty) {
        return _shortLabel(value);
      }
    }
    return '';
  }
}

class ProfilePostModel {
  const ProfilePostModel({
    required this.id,
    required this.postType,
    required this.caption,
    required this.mediaKind,
    required this.location,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.saveCount,
    required this.ratingAvg,
    required this.media,
    required this.createdAt,
    this.ratingEnabled = false,
    this.tags = const <String>[],
    this.contestId = 0,
    this.contestTitle = '',
    this.visibility = '',
    this.isSaved = false,
  });

  final int id;
  final String postType;
  final String caption;
  final String mediaKind;
  final String location;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final int saveCount;
  final double? ratingAvg;
  final List<ProfileMediaModel> media;
  final String createdAt;
  final bool ratingEnabled;
  final List<String> tags;
  final int contestId;
  final String contestTitle;
  final String visibility;
  final bool isSaved;

  factory ProfilePostModel.fromMap(Map<String, dynamic> map) {
    final postId = _asInt(map['id']);
    final contestMap = map['contest'] is Map
        ? Map<String, dynamic>.from(map['contest'] as Map)
        : null;
    final stored = ContestEnrollmentStore.instance.infoFor(postId.toString());
    return ProfilePostModel(
      id: postId,
      postType: _asString(map['post_type']),
      caption: _asString(map['caption']),
      mediaKind: _asString(map['media_kind']),
      location: _asString(map['location']),
      likeCount: _asInt(map['like_count']),
      commentCount: _asInt(map['comment_count']),
      shareCount: _asInt(map['share_count']),
      saveCount: _asInt(map['save_count']),
      ratingAvg: _asNullableDouble(map['rating_avg']),
      media: _mapList(
        map['media'] ?? map['images'] ?? map['gallery'],
        (item) => ProfileMediaModel.fromMap(item),
      ),
      createdAt: _asString(map['created_at']),
      // Voting when disabled 403s server-side, so an absent/unparseable
      // value must fail closed — _asBool here already defaults to false.
      ratingEnabled: _asBool(map['in_contest']) || stored != null,
      tags: parsePostTags(map),
      contestId: contestMap != null
          ? _asInt(contestMap['id'])
          : (stored?.contestId ?? 0),
      contestTitle: contestMap != null
          ? _asString(contestMap['title'])
          : (stored?.contestTitle ?? ''),
      visibility: _asString(map['visibility']).toLowerCase(),
      isSaved: _asBool(map['is_saved']),
    );
  }

  bool get isCarousel {
    if (CarouselMediaStore.pathsFor(id.toString()).length >= 2) {
      return true;
    }
    var images = 0;
    for (final item in media) {
      if (item.mediaType.trim().toLowerCase() == 'video') {
        continue;
      }
      if (item.fileUrl.trim().isNotEmpty) {
        images += 1;
      }
    }
    return images > 1;
  }

  /// Small image for the profile grid. The opened post still uses the full file.
  String get gridImageUrl {
    for (final item in media) {
      if (item.thumbnailUrl.isNotEmpty) {
        return item.thumbnailUrl;
      }
    }
    return primaryImageUrl;
  }

  String get primaryImageUrl {
    for (final item in media) {
      // A video's file_url points at the raw video file, not something
      // AppCachedImage can decode as an image — only its thumbnail (if any)
      // is image-displayable. Falling through to file_url here is what
      // shows up as the broken-image icon in the profile grid.
      if (item.mediaType.trim().toLowerCase() == 'video') {
        if (item.thumbnailUrl.isNotEmpty) {
          return item.thumbnailUrl;
        }
        continue;
      }
      if (item.fileUrl.isNotEmpty) {
        return item.fileUrl;
      }
      if (item.thumbnailUrl.isNotEmpty) {
        return item.thumbnailUrl;
      }
    }
    return '';
  }

  String get displayTitle {
    final trimmed = caption.trim();
    if (trimmed.isNotEmpty) {
      return trimmed;
    }
    if (postType == 'food') {
      return 'Food Post';
    }
    if (postType == 'outfit') {
      return 'Outfit Post';
    }
    return 'Post';
  }

  String get metricsLabel {
    final locationValue = location.trim();
    if (locationValue.isNotEmpty) {
      return locationValue;
    }
    return '$likeCount likes | $commentCount comments';
  }

  HomePostModel toHomePostModel({
    required String username,
    required String avatarUrl,
    required String profileUsername,
    required String authorName,
  }) {
    final normalizedPostType = postType.trim().toLowerCase();
    final isFood = normalizedPostType == 'food';
    final primaryMedia = media.isNotEmpty ? media.first : null;
    final resolvedMediaType = media.any((item) => item.mediaType == 'video')
        ? HomeMediaType.video
        : (mediaKind.trim().toLowerCase() == 'video'
              ? HomeMediaType.video
              : HomeMediaType.image);

    return HomePostModel(
      id: id.toString(),
      feedType: isFood ? HomeFeedType.bite : HomeFeedType.style,
      mediaType: resolvedMediaType,
      contentType: isFood ? HomeContentType.food : HomeContentType.fashion,
      username: username,
      location: location.trim(),
      streakLabel: '',
      avatarUrl: avatarUrl,
      imageUrl: primaryImageUrl,
      displayRating: ratingAvg ?? 0,
      likes: likeCount.toString(),
      comments: commentCount.toString(),
      defaultSelectedRate: 0,
      caption: caption,
      postedAt: AppTimeFormatter.formatPostTime(createdAt),
      mediaUrl: resolvedMediaType == HomeMediaType.video
          ? (primaryMedia?.fileUrl ?? primaryImageUrl)
          : '',
      thumbnailUrl: primaryMedia?.thumbnailUrl.isEmpty ?? true
          ? null
          : primaryMedia!.thumbnailUrl,
      isSaved: isSaved,
      isLiked: false,
      authorName: authorName,
      media: media
          .map(
            (item) => HomePostMedia(
              fileUrl: item.fileUrl,
              type: item.mediaType == 'video'
                  ? HomeMediaType.video
                  : HomeMediaType.image,
              thumbnailUrl: item.thumbnailUrl.isEmpty
                  ? null
                  : item.thumbnailUrl,
            ),
          )
          .toList(growable: false),
      tags: tags,
      shareCount: shareCount,
      saveCount: saveCount,
      viewCount: 0,
      allowComments: true,
      allowShares: true,
      ratingEnabled: ratingEnabled,
      contestId: contestId,
      contestTitle: contestTitle,
      visibility: visibility,
      dishName: isFood ? displayTitle : '',
      restaurant: '',
      foodRating: null,
      serviceRating: null,
      staffRating: null,
      ambienceRating: null,
      profileUsername: profileUsername,
      isFollowingAuthor: false,
      publishedAt: AppTimeFormatter.parse(createdAt),
    );
  }
}

class SavedProfilePostModel {
  const SavedProfilePostModel({
    required this.savedPostId,
    required this.savedAt,
    required this.post,
  });

  final int savedPostId;
  final String savedAt;
  final ProfilePostModel post;

  factory SavedProfilePostModel.fromMap(Map<String, dynamic> map) {
    final post = Map<String, dynamic>.from(
      (map['post'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
    post['is_saved'] = true;
    return SavedProfilePostModel(
      savedPostId: _asInt(map['saved_post_id']),
      savedAt: _asString(map['saved_at']),
      post: ProfilePostModel.fromMap(post),
    );
  }

  String get imageUrl => post.gridImageUrl;
}

class ProfileMediaModel {
  const ProfileMediaModel({
    required this.id,
    required this.mediaType,
    required this.fileUrl,
    required this.thumbnailUrl,
  });

  final int id;
  final String mediaType;
  final String fileUrl;
  final String thumbnailUrl;

  factory ProfileMediaModel.fromMap(Map<String, dynamic> map) {
    return ProfileMediaModel(
      id: _asInt(map['id']),
      mediaType: _asString(map['media_type']),
      fileUrl: _asString(
        map['file_url'] ??
            map['original_url'] ??
            map['url'] ??
            map['image_url'] ??
            map['media_url'] ??
            map['full_url'],
      ),
      thumbnailUrl: _asString(map['thumbnail_url']),
    );
  }
}

class ProfilePaginationModel {
  const ProfilePaginationModel({
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

  factory ProfilePaginationModel.fromMap(Map<String, dynamic> map) {
    return ProfilePaginationModel(
      currentPage: _asInt(map['current_page'], fallback: 1),
      perPage: _asInt(map['per_page'], fallback: 10),
      total: _asInt(map['total']),
      lastPage: _asInt(map['last_page'], fallback: 1),
      hasMorePages: _asBool(map['has_more_pages']),
    );
  }

  ProfilePaginationModel copyWith({
    int? currentPage,
    int? perPage,
    int? total,
    int? lastPage,
    bool? hasMorePages,
  }) {
    return ProfilePaginationModel(
      currentPage: currentPage ?? this.currentPage,
      perPage: perPage ?? this.perPage,
      total: total ?? this.total,
      lastPage: lastPage ?? this.lastPage,
      hasMorePages: hasMorePages ?? this.hasMorePages,
    );
  }
}

List<T> _mapList<T>(dynamic raw, T Function(Map<String, dynamic> map) builder) {
  if (raw is! List) {
    return <T>[];
  }
  return raw
      .whereType<Map>()
      .map((item) => builder(item.cast<String, dynamic>()))
      .toList(growable: false);
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _asNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}

String _asString(dynamic value) {
  if (value == null) {
    return '';
  }
  final text = value.toString().trim();
  return text == 'null' ? '' : text;
}

String _shortLabel(String value, {int maxLength = 20}) {
  if (value.length <= maxLength) {
    return value;
  }
  return '${value.substring(0, maxLength).trimRight()}...';
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = value?.toString().toLowerCase().trim();
  return normalized == 'true' || normalized == '1';
}

bool _rememberVerified(dynamic username, bool isVerified) {
  return VerifiedBadgeCache.resolve(username?.toString(), isVerified);
}
