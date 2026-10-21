import 'dart:convert';

import '../utils/api_helper.dart';
import '../utils/verified_flag.dart';

class VerifiedBadgeHydrator {
  VerifiedBadgeHydrator._();

  static const int _maxConcurrent = 3;
  static final Set<String> _checked = <String>{};
  static final Set<String> _inFlight = <String>{};

  static void hydrate(Iterable<String> usernames) {
    final pending = usernames
        .map(VerifiedBadgeCache.normalize)
        .where(
          (username) =>
              username.isNotEmpty &&
              username != 'you' &&
              username != 'stylebite' &&
              !VerifiedBadgeCache.isVerified(username) &&
              !_checked.contains(username) &&
              !_inFlight.contains(username),
        )
        .toSet()
        .toList();
    if (pending.isEmpty) {
      return;
    }

    Future<void>(() async {
      var index = 0;
      Future<void> runNext() async {
        if (index >= pending.length) {
          return;
        }
        final username = pending[index++];
        await _hydrateOne(username);
        await runNext();
      }

      final workers = List<Future<void>>.generate(
        _maxConcurrent.clamp(1, pending.length),
        (_) => runNext(),
      );
      await Future.wait(workers);
    });
  }

  static Future<void> _hydrateOne(String username) async {
    if (VerifiedBadgeCache.isVerified(username) ||
        _checked.contains(username) ||
        _inFlight.contains(username)) {
      return;
    }
    _inFlight.add(username);
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'profiles/${Uri.encodeComponent(username)}/overview?per_page=1',
      );
      if (response == null || response.statusCode < 200 || response.statusCode >= 300) {
        return;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return;
      }
      final user = asStringKeyedMap(payload['user']);
      final verified = parseVerifiedFlag(payload) || parseVerifiedFlag(user);
      VerifiedBadgeCache.remember(
        user['username']?.toString().isNotEmpty == true
            ? user['username'].toString()
            : username,
        verified,
      );
      _checked.add(username);
    } catch (_) {
      _checked.add(username);
    } finally {
      _inFlight.remove(username);
    }
  }
}
