import 'dart:async';

import '../../../core/utils/local_storage.dart';
import 'chat_api_service.dart';

class ChatPresenceService {
  ChatPresenceService._();

  static final ChatPresenceService instance = ChatPresenceService._();

  // Server-side is_online expires 2 minutes after the last ping, so a
  // foreground heartbeat well under that keeps it from lapsing.
  static const Duration _heartbeatInterval = Duration(seconds: 60);

  final ChatApiService _apiService = const ChatApiService();
  bool? _lastPresence;
  bool _isSyncing = false;
  Timer? _heartbeatTimer;

  Future<void> markOnline() => _syncPresence(true);

  Future<void> markOffline() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    return _syncPresence(false);
  }

  Future<void> _syncPresence(bool isOnline, {bool force = false}) async {
    final token = LocalStorage.getAccessKey();
    if (token == null || token.trim().isEmpty) {
      return;
    }
    if (_isSyncing || (!force && _lastPresence == isOnline)) {
      return;
    }

    _isSyncing = true;
    try {
      await _apiService.updatePresence(isOnline);
      _lastPresence = isOnline;
      if (isOnline) {
        _startHeartbeat();
      }
    } catch (_) {
      // Presence updates should stay silent.
    } finally {
      _isSyncing = false;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _syncPresence(true, force: true);
    });
  }
}
