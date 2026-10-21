import 'package:get/get.dart';

import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../models/chat_models.dart' show ChatApiException;
import '../services/chat_api_service.dart' show ChatApiService;
import '../screen/chat_detail_screen.dart';
import 'chat_block_navigation.dart';

class ChatStartHelper {
  ChatStartHelper._();

  static Future<void> startChat(String username) async {
    final normalized = username.trim().replaceFirst('@', '');
    if (normalized.isEmpty) {
      return;
    }

    final currentUsername = LocalStorage.getUsername()?.trim().toLowerCase();
    if (currentUsername != null &&
        currentUsername == normalized.toLowerCase()) {
      errorSnackBar(message: 'You cannot start a chat with yourself.');
      return;
    }

    try {
      final initialized = await const ChatApiService().initializeChat(
        normalized,
      );
      Get.to<void>(
        () => ChatDetailScreen(
          username: initialized.username.isNotEmpty
              ? initialized.username
              : normalized,
          conversationId: initialized.conversationId,
          initialIsMessagingStopped:
              initialized.isMessagingStopped || initialized.isBlocked,
          initialIsBlockedByMe: initialized.isBlockedByMe,
          initialIsBlockedByOther: initialized.isBlockedByOther,
        ),
      );
    } on ChatApiException catch (error) {
      final blocked = resolveBlockedChatNavigation(
        error,
        username: normalized,
      );
      if (blocked != null) {
        Get.to<void>(
          () => ChatDetailScreen(
            username: blocked.username,
            conversationId: blocked.conversationId,
            initialIsMessagingStopped: true,
            initialIsBlockedByMe: blocked.isBlockedByMe,
            initialIsBlockedByOther: blocked.isBlockedByOther,
          ),
        );
        return;
      }
      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Unable to open this chat right now.');
    }
  }
}
