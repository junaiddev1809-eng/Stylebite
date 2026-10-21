import '../../../core/utils/verified_flag.dart';

class BlockedUserModel {
  const BlockedUserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.displayName,
    required this.bio,
    required this.city,
    required this.country,
    required this.avatarUrl,
    required this.blockedAt,
    this.isVerifiedBadge = false,
  });

  final int id;
  final String username;
  final String fullName;
  final String displayName;
  final String bio;
  final String city;
  final String country;
  final String avatarUrl;
  final String blockedAt;
  final bool isVerifiedBadge;

  String get title {
    if (displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    if (fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    return username;
  }

  String get locationLabel {
    final parts = <String>[
      city,
      country,
    ].where((item) => item.trim().isNotEmpty).toList(growable: false);
    return parts.join(', ');
  }

  factory BlockedUserModel.fromJson(Map<String, dynamic> json) {
    final user =
        (json['user'] as Map<String, dynamic>?) ??
        (json['blocked_user'] as Map<String, dynamic>?) ??
        (json['target_user'] as Map<String, dynamic>?) ??
        (json['blocked'] as Map<String, dynamic>?) ??
        json;
    final profile =
        (user['profile'] as Map<String, dynamic>?) ??
        (json['profile'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    return BlockedUserModel(
      id: _asInt(user['id'] ?? json['id']),
      username: _resolveUsername(user, json),
      fullName: _asString(user['full_name']),
      displayName: _asString(profile['display_name'] ?? user['display_name']),
      bio: _asString(profile['bio'] ?? user['bio']),
      city: _asString(profile['city'] ?? user['city']),
      country: _asString(profile['country'] ?? user['country']),
      avatarUrl: _avatar(user, profile),
      blockedAt: _asString(json['blocked_at'] ?? json['created_at']),
      isVerifiedBadge: VerifiedBadgeCache.resolve(
        user['username']?.toString() ?? json['username']?.toString(),
        parseVerifiedFlag(user, profile) || parseVerifiedFlag(json),
      ),
    );
  }

  static String _avatar(
    Map<String, dynamic> user,
    Map<String, dynamic> profile,
  ) {
    for (final candidate in <dynamic>[
      user['avatar_url'],
      profile['avatar_url'],
    ]) {
      final value = _nullableString(candidate);
      if (value != null) {
        return value;
      }
    }
    return '';
  }

  static String _resolveUsername(
    Map<String, dynamic> user,
    Map<String, dynamic> root,
  ) {
    for (final candidate in <dynamic>[
      user['username'],
      root['username'],
      (root['blocked_user'] as Map<String, dynamic>?)?['username'],
      (root['target_user'] as Map<String, dynamic>?)?['username'],
      (root['blocked'] as Map<String, dynamic>?)?['username'],
      (root['user'] as Map<String, dynamic>?)?['username'],
    ]) {
      final value = _nullableString(candidate);
      if (value != null) {
        return value.replaceFirst('@', '');
      }
    }
    return '';
  }
}

class BlockedUsersPaginationModel {
  const BlockedUsersPaginationModel({
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

  factory BlockedUsersPaginationModel.fromJson(Map<String, dynamic> json) {
    final currentPage = _asInt(
      json['current_page'] ?? json['page'],
      fallback: 1,
    );
    final lastPage = _asInt(json['last_page'], fallback: 1);

    return BlockedUsersPaginationModel(
      currentPage: currentPage <= 0 ? 1 : currentPage,
      perPage: _asInt(json['per_page'], fallback: 20),
      total: _asInt(json['total']),
      lastPage: lastPage <= 0 ? 1 : lastPage,
      hasMorePages:
          _asBool(json['has_more_pages']) ||
          (currentPage > 0 && lastPage > 0 && currentPage < lastPage),
    );
  }
}

class BlockedUsersResponseModel {
  const BlockedUsersResponseModel({
    required this.statusCode,
    required this.message,
    required this.users,
    required this.pagination,
  });

  final int statusCode;
  final String message;
  final List<BlockedUserModel> users;
  final BlockedUsersPaginationModel pagination;

  factory BlockedUsersResponseModel.fromJson(Map<String, dynamic> json) {
    final items = _resolveItems(
      json,
    ).map(BlockedUserModel.fromJson).toList(growable: false);

    return BlockedUsersResponseModel(
      statusCode: _asInt(json['status_code']),
      message: _asString(json['message']),
      users: items,
      pagination: BlockedUsersPaginationModel.fromJson(
        (json['pagination'] as Map<String, dynamic>?) ??
            _fallbackPagination(json, items.length),
      ),
    );
  }

  static List<Map<String, dynamic>> _resolveItems(Map<String, dynamic> json) {
    for (final key in <String>['blocked_users', 'users', 'data', 'items']) {
      final value = json[key];
      if (value is List) {
        return value.whereType<Map<String, dynamic>>().toList(growable: false);
      }
    }
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _fallbackPagination(
    Map<String, dynamic> json,
    int itemCount,
  ) {
    return <String, dynamic>{
      'current_page': json['current_page'] ?? 1,
      'per_page': json['per_page'] ?? itemCount,
      'total': json['total'] ?? itemCount,
      'last_page': json['last_page'] ?? 1,
      'has_more_pages': json['has_more_pages'] ?? false,
    };
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

String _asString(dynamic value) => value?.toString().trim() ?? '';

String? _nullableString(dynamic value) {
  final resolved = value?.toString().trim();
  if (resolved == null || resolved.isEmpty || resolved == 'null') {
    return null;
  }
  return resolved;
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final raw = value?.toString().trim().toLowerCase() ?? '';
  return raw == '1' || raw == 'true' || raw == 'yes';
}
