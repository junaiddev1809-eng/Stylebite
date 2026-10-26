import 'profile_model.dart';
import '../../../core/utils/verified_flag.dart';

class FollowerListResponseModel {
  const FollowerListResponseModel({
    required this.statusCode,
    required this.message,
    required this.data,
    required this.pagination,
  });

  final int statusCode;
  final String message;
  final List<FollowerModel> data;
  final ProfilePaginationModel pagination;

  factory FollowerListResponseModel.fromJson(Map<String, dynamic> json) {
    final list = _extractUsers(json);

    return FollowerListResponseModel(
      statusCode: (json['status_code'] as num?)?.toInt() ?? 0,
      message: (json['message'] as String?) ?? '',
      data: list,
      pagination: ProfilePaginationModel.fromMap(
        asStringKeyedMap(
          json['pagination'] ??
              asStringKeyedMap(json['data'])['pagination'] ??
              const <String, dynamic>{},
        ),
      ),
    );
  }

  static List<FollowerModel> _extractUsers(dynamic json, [int depth = 0]) {
    if (json == null || depth > 4) {
      return const <FollowerModel>[];
    }
    if (json is List) {
      return json
          .whereType<Map>()
          .map((item) => FollowerModel.fromJson(asStringKeyedMap(item)))
          .toList();
    }
    if (json is Map) {
      for (final key in <String>[
        'followers',
        'following',
        'likes',
        'likers',
        'users',
        'items',
        'data',
      ]) {
        final nested = json[key];
        if (nested == null) {
          continue;
        }
        final parsed = _extractUsers(nested, depth + 1);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      }
    }
    return const <FollowerModel>[];
  }
}

class FollowerModel {
  const FollowerModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.fullName,
    required this.avatarUrl,
    required this.bio,
    required this.isPrivate,
    required this.isFollowing,
    required this.followsYou,
    required this.isMutualFollow,
    required this.isSelf,
    required this.isVerified,
    required this.followerCount,
    required this.followingCount,
  });

  final int id;
  final String username;
  final String displayName;
  final String fullName;
  final String avatarUrl;
  final String bio;
  final bool isPrivate;
  final bool isFollowing;
  final bool followsYou;
  final bool isMutualFollow;
  final bool isSelf;
  final bool isVerified;
  final int followerCount;
  final int followingCount;

  factory FollowerModel.fromJson(Map<String, dynamic> json) {
    final nested = _nestedUser(json);
    final merged = <String, dynamic>{...nested, ...json};
    final relationship = asStringKeyedMap(
      merged['relationship'] ?? json['relationship'] ?? nested['relationship'],
    );

    final rawBio = merged['bio'] ?? nested['bio'];
    final bioString =
        (rawBio == null || rawBio == 'null') ? '' : rawBio.toString();
    final username = (merged['username'] ?? nested['username'] ?? '')
        .toString()
        .trim()
        .replaceFirst('@', '');

    return FollowerModel(
      id: (merged['id'] as num?)?.toInt() ??
          (nested['id'] as num?)?.toInt() ??
          0,
      username: username,
      displayName: (merged['display_name'] ?? nested['display_name'] ?? '')
          .toString(),
      fullName:
          (merged['full_name'] ?? nested['full_name'] ?? '').toString(),
      avatarUrl:
          (merged['avatar_url'] ?? nested['avatar_url'] ?? '').toString(),
      bio: bioString,
      isPrivate: _asBool(merged['is_private'] ?? nested['is_private']),
      isFollowing: _asBool(
        relationship['is_following'] ?? merged['is_following'],
      ),
      followsYou: _asBool(
        relationship['follows_you'] ?? merged['follows_you'],
      ),
      isMutualFollow: _asBool(
        relationship['is_mutual_follow'] ?? merged['is_mutual_follow'],
      ),
      isSelf: _asBool(merged['is_self'] ?? nested['is_self']),
      isVerified: VerifiedBadgeCache.resolve(
        username,
        parseVerifiedFlag(json) || parseVerifiedFlag(nested, relationship),
      ),
      followerCount: (merged['follower_count'] as num?)?.toInt() ?? 0,
      followingCount: (merged['following_count'] as num?)?.toInt() ?? 0,
    );
  }

  static Map<String, dynamic> _nestedUser(Map<String, dynamic> json) {
    for (final key in <String>[
      'user',
      'profile',
      'author',
      'follower',
      'following',
      'account',
    ]) {
      final nested = asStringKeyedMap(json[key]);
      if (nested.isNotEmpty) {
        return nested;
      }
    }
    return const <String, dynamic>{};
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final raw = (value ?? '').toString().trim().toLowerCase();
    return raw == 'true' || raw == '1' || raw == 'yes';
  }

  FollowerModel copyWith({
    int? id,
    String? username,
    String? displayName,
    String? fullName,
    String? avatarUrl,
    String? bio,
    bool? isPrivate,
    bool? isFollowing,
    bool? followsYou,
    bool? isMutualFollow,
    bool? isSelf,
    bool? isVerified,
    int? followerCount,
    int? followingCount,
  }) {
    return FollowerModel(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isPrivate: isPrivate ?? this.isPrivate,
      isFollowing: isFollowing ?? this.isFollowing,
      followsYou: followsYou ?? this.followsYou,
      isMutualFollow: isMutualFollow ?? this.isMutualFollow,
      isSelf: isSelf ?? this.isSelf,
      isVerified: isVerified ?? this.isVerified,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
    );
  }
}
