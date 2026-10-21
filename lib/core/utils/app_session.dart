import '../../modules/messages/services/chat_presence_service.dart';
import '../../modules/messages/services/chat_socket_service.dart';
import 'config.dart';
import 'local_storage.dart';

class AppSession {
  static String? tokenFromAuthPayload(dynamic payload) {
    if (payload is! Map) {
      return null;
    }
    final raw = payload['access_token'] ?? payload['bearer_token'];
    final token = raw?.toString().trim() ?? '';
    if (token.isEmpty) {
      return null;
    }
    return token;
  }

  static Future<void> attachRealtimeIfNeeded() async {
    final token = LocalStorage.getAccessKey();
    if (token == null || token.isEmpty) {
      return;
    }

    await ChatPresenceService.instance.markOnline();
    if (realtimeEnabled) {
      await ChatSocketService.instance.connect();
    }
  }
}
