import 'dart:convert';

import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';

enum FollowButtonState { none, requested, following }

class FollowStateController extends GetxController {
  final Map<String, FollowButtonState> _seededByUsername =
      <String, FollowButtonState>{};
  final RxMap<String, FollowButtonState> _stateByUsername =
      <String, FollowButtonState>{}.obs;
  final RxSet<String> loadingUsernames = <String>{}.obs;

  bool isFollowing(String username, {bool fallback = false}) {
    return stateOf(username, fallbackFollowing: fallback) ==
        FollowButtonState.following;
  }

  bool isRequested(String username, {bool fallback = false}) {
    return stateOf(username, fallbackRequested: fallback) ==
        FollowButtonState.requested;
  }

  FollowButtonState stateOf(
    String username, {
    bool fallbackFollowing = false,
    bool fallbackRequested = false,
  }) {
    final normalized = _normalize(username);
    if (normalized.isEmpty) {
      return FollowButtonState.none;
    }
    final live = _stateByUsername[normalized];
    if (live != null) {
      return live;
    }
    final seeded = _seededByUsername[normalized];
    if (seeded != null) {
      return seeded;
    }
    if (fallbackFollowing) {
      return FollowButtonState.following;
    }
    if (fallbackRequested) {
      return FollowButtonState.requested;
    }
    return FollowButtonState.none;
  }

  bool isLoading(String username) =>
      loadingUsernames.contains(_normalize(username));

  void seed(
    String username, {
    bool isFollowing = false,
    bool isRequested = false,
  }) {
    final normalized = _normalize(username);
    if (normalized.isEmpty) {
      return;
    }

    final state = isFollowing
        ? FollowButtonState.following
        : (isRequested ? FollowButtonState.requested : FollowButtonState.none);
    _seededByUsername.putIfAbsent(normalized, () => state);
  }

  void markUnfollowed(String username) {
    _setState(username, FollowButtonState.none);
  }

  void markFollowing(String username) {
    _setState(username, FollowButtonState.following);
  }

  void markRequested(String username) {
    _setState(username, FollowButtonState.requested);
  }

  Future<void> toggleFollow(
    String username, {
    required bool currentlyFollowing,
  }) async {
    final normalized = _normalize(username);
    if (normalized.isEmpty || loadingUsernames.contains(normalized)) {
      return;
    }

    final current = stateOf(normalized, fallbackFollowing: currentlyFollowing);
    loadingUsernames.add(normalized);
    try {
      final endpoint = 'profiles/${Uri.encodeComponent(normalized)}/follow';
      final shouldUnfollow = current == FollowButtonState.following ||
          current == FollowButtonState.requested;
      final response = shouldUnfollow
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

      final relationship =
          (payload['relationship'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
      if (_asBool(relationship['is_following'])) {
        _setState(normalized, FollowButtonState.following);
      } else if (_asBool(relationship['follow_request_pending'])) {
        _setState(normalized, FollowButtonState.requested);
      } else {
        _setState(normalized, FollowButtonState.none);
      }
    } finally {
      loadingUsernames.remove(normalized);
    }
  }

  Future<void> acceptFollowRequest(String username) async {
    await _respondToFollowRequest(username, accept: true);
  }

  Future<void> rejectFollowRequest(String username) async {
    await _respondToFollowRequest(username, accept: false);
  }

  Future<void> _respondToFollowRequest(
    String username, {
    required bool accept,
  }) async {
    final normalized = _normalize(username);
    if (normalized.isEmpty || loadingUsernames.contains(normalized)) {
      return;
    }

    loadingUsernames.add(normalized);
    try {
      final action = accept ? 'accept' : 'reject';
      final response = await ApiHelper.postRequestWithAuthorization(
        'profiles/${Uri.encodeComponent(normalized)}/follow-requests/$action',
      );
      if (response == null) {
        throw Exception('No response returned from follow request endpoint.');
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload['status_code'] != 1) {
        throw Exception(
          (payload['message'] ?? 'Unable to update follow request').toString(),
        );
      }
    } finally {
      loadingUsernames.remove(normalized);
    }
  }

  void _setState(String username, FollowButtonState state) {
    final normalized = _normalize(username);
    if (normalized.isEmpty) {
      return;
    }
    _stateByUsername[normalized] = state;
    _seededByUsername[normalized] = state;
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = (value ?? '').toString().trim().toLowerCase();
    return text == '1' || text == 'true' || text == 'yes';
  }

  String _normalize(String username) => username.trim().replaceFirst('@', '');
}
