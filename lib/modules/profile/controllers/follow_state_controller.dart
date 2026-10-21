import 'dart:convert';

import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';

class FollowStateController extends GetxController {
  final Map<String, bool> _seededFollowingByUsername = <String, bool>{};
  final RxMap<String, bool> _followingByUsername = <String, bool>{}.obs;
  final RxSet<String> loadingUsernames = <String>{}.obs;

  bool isFollowing(String username, {bool fallback = false}) {
    final normalized = _normalize(username);
    if (normalized.isEmpty) {
      return fallback;
    }
    return _followingByUsername[normalized] ??
        _seededFollowingByUsername[normalized] ??
        fallback;
  }

  bool isLoading(String username) =>
      loadingUsernames.contains(_normalize(username));

  void seed(String username, bool isFollowing) {
    final normalized = _normalize(username);
    if (normalized.isEmpty) {
      return;
    }

    // Seed initial backend state without notifying listeners during widget
    // mount. Follow buttons already render from their fallback value on the
    // first build, and interactive changes still go through the reactive map.
    _seededFollowingByUsername.putIfAbsent(normalized, () => isFollowing);
  }

  Future<void> toggleFollow(
    String username, {
    required bool currentlyFollowing,
  }) async {
    final normalized = _normalize(username);
    if (normalized.isEmpty || loadingUsernames.contains(normalized)) {
      return;
    }

    loadingUsernames.add(normalized);
    try {
      final endpoint = 'profiles/${Uri.encodeComponent(normalized)}/follow';
      final response = currentlyFollowing
          ? await ApiHelper.deleteRequestWithAuthorization(endpoint)
          : await ApiHelper.postRequestWithAuthorization(endpoint);

      if (response == null) {
        throw Exception('No response returned from follow endpoint.');
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to update follow').toString(),
        );
      }

      _followingByUsername[normalized] = !currentlyFollowing;
      _seededFollowingByUsername[normalized] = !currentlyFollowing;
    } finally {
      loadingUsernames.remove(normalized);
    }
  }

  String _normalize(String username) => username.trim().replaceFirst('@', '');
}
