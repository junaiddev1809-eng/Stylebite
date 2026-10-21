import '../../../core/utils/verified_flag.dart';

class SearchUserModel {
  const SearchUserModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.displayName,
    required this.bio,
    required this.city,
    required this.country,
    required this.avatarUrl,
    required this.isFollowing,
    required this.followsYou,
    required this.isMutualFollow,
    required this.isVerifiedBadge,
  });

  final int id;
  final String username;
  final String fullName;
  final String displayName;
  final String bio;
  final String city;
  final String country;
  final String avatarUrl;
  final bool isFollowing;
  final bool followsYou;
  final bool isMutualFollow;
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

  bool matchesPrefix(String query) => prefixRank(query) >= 0;

  /// Lower is a better match. `-1` means no prefix match.
  int prefixRank(String query) {
    final normalized = query.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
    if (normalized.isEmpty) {
      return -1;
    }

    final handle = username.trim().toLowerCase();
    final names = <String>{
      displayName.trim().toLowerCase(),
      fullName.trim().toLowerCase(),
      title.trim().toLowerCase(),
    }..removeWhere((name) => name.isEmpty);

    if (handle == normalized) {
      return 0;
    }
    if (names.contains(normalized)) {
      return 1;
    }
    if (handle.startsWith(normalized)) {
      return 2;
    }
    if (names.any((name) => name.startsWith(normalized))) {
      return 3;
    }
    if (names.any((name) => _wordsPrefixMatch(name, normalized))) {
      return 4;
    }
    return -1;
  }

  static bool _wordsPrefixMatch(String text, String query) {
    final queryParts = query
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    final textParts = text
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (queryParts.isEmpty || textParts.length < queryParts.length) {
      return false;
    }

    for (var start = 0; start <= textParts.length - queryParts.length; start++) {
      var matched = true;
      for (var i = 0; i < queryParts.length; i++) {
        if (!textParts[start + i].startsWith(queryParts[i])) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return true;
      }
    }
    return false;
  }

  factory SearchUserModel.fromJson(Map<String, dynamic> json) {
    final profile =
        (json['profile'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return SearchUserModel(
      id: _readInt(json['id']),
      username: (json['username'] ?? '').toString(),
      fullName: (json['full_name'] ?? '').toString(),
      displayName: (profile['display_name'] ?? json['display_name'] ?? '')
          .toString(),
      bio: (profile['bio'] ?? json['bio'] ?? '').toString(),
      city: (profile['city'] ?? json['city'] ?? '').toString(),
      country: (profile['country'] ?? json['country'] ?? '').toString(),
      avatarUrl: _readAvatar(json, profile),
      isFollowing: _asBool(json['is_following']),
      followsYou: _asBool(json['follows_you']),
      isMutualFollow: _asBool(json['is_mutual_follow']),
      isVerifiedBadge: VerifiedBadgeCache.resolve(
        json['username']?.toString(),
        parseVerifiedFlag(json) || parseVerifiedFlag(profile),
      ),
    );
  }

  static String _readAvatar(
    Map<String, dynamic> json,
    Map<String, dynamic> profile,
  ) {
    final direct = _nullableString(json['avatar_url']);
    if (direct != null) {
      return direct;
    }

    final profileAvatar = _nullableString(profile['avatar_url']);
    if (profileAvatar != null) {
      return profileAvatar;
    }

    final nested = profile['avatar'];
    if (nested is Map<String, dynamic>) {
      return _nullableString(nested['file_url']) ?? '';
    }

    return '';
  }

  static String? _nullableString(dynamic value) {
    final resolved = value?.toString().trim();
    if (resolved == null || resolved.isEmpty || resolved == 'null') {
      return null;
    }
    return resolved;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    final normalized = value?.toString().trim().toLowerCase() ?? '';
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }
}

class SearchUsersPaginationModel {
  const SearchUsersPaginationModel({
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

  factory SearchUsersPaginationModel.fromJson(Map<String, dynamic> json) {
    final currentPage = SearchUserModel._readInt(
      json['current_page'] ?? json['page'],
    );
    final lastPage = SearchUserModel._readInt(json['last_page']);
    final total = SearchUserModel._readInt(json['total']);
    final perPage = SearchUserModel._readInt(json['per_page']);

    return SearchUsersPaginationModel(
      currentPage: currentPage <= 0 ? 1 : currentPage,
      perPage: perPage <= 0 ? 20 : perPage,
      total: total,
      lastPage: lastPage <= 0 ? 1 : lastPage,
      hasMorePages:
          (json['has_more_pages'] as bool?) ??
          ((json['next_page_url']?.toString().trim().isNotEmpty ?? false) ||
              (lastPage > 0 && currentPage > 0 && currentPage < lastPage)),
    );
  }
}

class SearchUsersResponseModel {
  const SearchUsersResponseModel({
    required this.statusCode,
    required this.message,
    required this.users,
    required this.pagination,
  });

  final int statusCode;
  final String message;
  final List<SearchUserModel> users;
  final SearchUsersPaginationModel pagination;

  factory SearchUsersResponseModel.fromJson(Map<String, dynamic> json) {
    final container = _resolveContainer(json);
    final users = _resolveUsers(
      container,
    ).map(SearchUserModel.fromJson).toList(growable: false);

    final paginationSource = _resolvePagination(json, container, users.length);

    return SearchUsersResponseModel(
      statusCode: SearchUserModel._readInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      users: users,
      pagination: SearchUsersPaginationModel.fromJson(paginationSource),
    );
  }

  static Map<String, dynamic> _resolveContainer(Map<String, dynamic> json) {
    final users = json['users'];
    if (users is Map<String, dynamic>) {
      return users;
    }

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    return json;
  }

  static List<Map<String, dynamic>> _resolveUsers(Map<String, dynamic> json) {
    final directUsers = json['users'];
    if (directUsers is List) {
      return directUsers.whereType<Map<String, dynamic>>().toList();
    }

    final data = json['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }

    final items = json['items'];
    if (items is List) {
      return items.whereType<Map<String, dynamic>>().toList();
    }

    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic> _resolvePagination(
    Map<String, dynamic> root,
    Map<String, dynamic> container,
    int itemCount,
  ) {
    final rootPagination = root['pagination'];
    if (rootPagination is Map<String, dynamic>) {
      return rootPagination;
    }

    final containerPagination = container['pagination'];
    if (containerPagination is Map<String, dynamic>) {
      return containerPagination;
    }

    return <String, dynamic>{
      'current_page': container['current_page'] ?? root['current_page'] ?? 1,
      'per_page': container['per_page'] ?? root['per_page'] ?? itemCount,
      'total': container['total'] ?? root['total'] ?? itemCount,
      'last_page': container['last_page'] ?? root['last_page'] ?? 1,
      'has_more_pages':
          container['has_more_pages'] ?? root['has_more_pages'] ?? false,
      'next_page_url': container['next_page_url'] ?? root['next_page_url'],
    };
  }
}
