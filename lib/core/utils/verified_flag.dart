import 'package:get/get.dart';

const _flagKeys = <String>[
  'is_verified_badge',
  'is_verified',
  'verified',
  'isVerifiedBadge',
  'isVerified',
  'has_verified_badge',
  'verified_badge',
  'is_verified_account',
];

const _nestedUserKeys = <String>[
  'user',
  'profile',
  'author',
  'follower',
  'following',
  'actor',
  'account',
  'target',
  'owner',
  'member',
  'blocked_user',
  'target_user',
];

bool parseVerifiedFlag(dynamic json, [dynamic nested]) {
  return _scan(json, 0) || _scan(nested, 0);
}

Map<String, dynamic> asStringKeyedMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

class VerifiedBadgeCache {
  VerifiedBadgeCache._();

  static final RxInt revision = 0.obs;
  static final Set<String> _verifiedUsernames = <String>{};

  static String normalize(String? username) {
    return (username ?? '').trim().replaceFirst('@', '').toLowerCase();
  }

  static void remember(String? username, bool isVerified) {
    if (!isVerified) {
      return;
    }
    final key = normalize(username);
    if (key.isEmpty || _verifiedUsernames.contains(key)) {
      return;
    }
    _verifiedUsernames.add(key);
    revision.value++;
  }

  static bool isVerified(String? username) {
    final key = normalize(username);
    return key.isNotEmpty && _verifiedUsernames.contains(key);
  }

  static bool shown({String? username, bool fallback = false}) {
    if (fallback) {
      remember(username, true);
      return true;
    }
    return isVerified(username);
  }

  static bool resolve(String? username, bool parsed) {
    return shown(username: username, fallback: parsed);
  }
}

bool _scan(dynamic node, int depth) {
  if (node == null || depth > 6) {
    return false;
  }

  if (node is Map) {
    for (final key in _flagKeys) {
      if (_asVerifiedBool(node[key])) {
        return true;
      }
    }

    final status = (node['verification_status'] ?? node['badge_status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (status == 'verified' || status == 'badge') {
      return true;
    }

    final badges = node['badges'];
    if (badges is List) {
      for (final badge in badges) {
        final raw = badge is Map
            ? (badge['name'] ?? badge['type'] ?? badge['slug'] ?? badge['key'])
                .toString()
            : badge.toString();
        if (raw.toLowerCase().contains('verified')) {
          return true;
        }
      }
    }

    for (final key in _nestedUserKeys) {
      if (_scan(node[key], depth + 1)) {
        return true;
      }
    }
    return false;
  }

  return _asVerifiedBool(node);
}

bool _asVerifiedBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final raw = (value ?? '').toString().trim().toLowerCase();
  return raw == 'true' || raw == '1' || raw == 'yes';
}
