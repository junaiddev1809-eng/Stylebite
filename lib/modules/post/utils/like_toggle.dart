import 'dart:async';
import 'dart:convert';

import '../../../core/utils/api_helper.dart';

class LikeToggleResult {
  const LikeToggleResult({required this.isLiked, this.likeCount});

  final bool isLiked;
  final int? likeCount;
}

/// Sends like toggles without blocking the heart on the network.
///
/// Extra taps while a request is in flight are folded into one follow-up
/// call, so the icon can change immediately and still match the server.
class LikeToggleSync {
  final _FlagToggleSync _sync = _FlagToggleSync(
    flagKey: 'is_liked',
    countKey: 'like_count',
    failureMessage: 'Unable to update like',
  );

  void run({
    required String id,
    required String endpoint,
    required bool Function() desiredLiked,
    required void Function(LikeToggleResult result) onConfirmed,
    required void Function(Object error) onError,
  }) {
    _sync.run(
      id: id,
      endpoint: endpoint,
      desired: desiredLiked,
      onConfirmed: (isOn, count) {
        onConfirmed(LikeToggleResult(isLiked: isOn, likeCount: count));
      },
      onError: onError,
    );
  }
}

/// Same immediate-tap behavior for the save bookmark.
class SaveToggleSync {
  final _FlagToggleSync _sync = _FlagToggleSync(
    flagKey: 'is_saved',
    countKey: 'save_count',
    failureMessage: 'Unable to update save',
  );

  void run({
    required String id,
    required String endpoint,
    required bool Function() desiredSaved,
    required void Function(bool isSaved, int? saveCount) onConfirmed,
    required void Function(Object error) onError,
  }) {
    _sync.run(
      id: id,
      endpoint: endpoint,
      desired: desiredSaved,
      onConfirmed: onConfirmed,
      onError: onError,
    );
  }
}

class _FlagToggleSync {
  _FlagToggleSync({
    required this.flagKey,
    required this.countKey,
    required this.failureMessage,
  });

  final String flagKey;
  final String countKey;
  final String failureMessage;
  final Map<String, int> _generation = {};
  final Set<String> _running = {};

  void run({
    required String id,
    required String endpoint,
    required bool Function() desired,
    required void Function(bool isOn, int? count) onConfirmed,
    required void Function(Object error) onError,
  }) {
    _generation[id] = (_generation[id] ?? 0) + 1;
    if (!_running.add(id)) {
      return;
    }
    unawaited(
      _drain(
        id: id,
        endpoint: endpoint,
        desired: desired,
        onConfirmed: onConfirmed,
        onError: onError,
      ).whenComplete(() => _running.remove(id)),
    );
  }

  Future<void> _drain({
    required String id,
    required String endpoint,
    required bool Function() desired,
    required void Function(bool isOn, int? count) onConfirmed,
    required void Function(Object error) onError,
  }) async {
    var handled = 0;
    var attempts = 0;
    try {
      while (handled != (_generation[id] ?? 0) && attempts < 4) {
        attempts++;
        handled = _generation[id] ?? 0;
        final result = await _send(endpoint);
        if (desired() != result.$1 || handled != (_generation[id] ?? 0)) {
          continue;
        }
        onConfirmed(result.$1, result.$2);
      }
    } catch (error) {
      onError(error);
    }
  }

  Future<(bool, int?)> _send(String endpoint) async {
    final response = await ApiHelper.postRequestWithAuthorization(endpoint);
    if (response == null) {
      throw Exception('No response returned from server.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw Exception(failureMessage);
    }
    final payload = decoded.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    if (response.statusCode != 200 || payload['status_code'] != 1) {
      throw Exception((payload['message'] ?? failureMessage).toString());
    }
    final flagRaw = payload[flagKey];
    final isOn = flagRaw == true || flagRaw == 1 || flagRaw == '1';
    final count = payload.containsKey(countKey)
        ? int.tryParse('${payload[countKey]}')
        : null;
    return (isOn, count);
  }
}

int parseLikeCount(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(',', '');
  if (normalized.isEmpty) {
    return 0;
  }
  final multiplier = normalized.endsWith('k')
      ? 1000
      : normalized.endsWith('m')
      ? 1000000
      : 1;
  final raw = multiplier == 1
      ? normalized
      : normalized.substring(0, normalized.length - 1);
  final parsed = double.tryParse(raw);
  if (parsed == null) {
    return 0;
  }
  return (parsed * multiplier).round();
}

String formatLikeCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}m';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
  }
  return value.toString();
}
