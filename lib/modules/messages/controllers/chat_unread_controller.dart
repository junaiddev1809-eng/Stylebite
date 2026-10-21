import 'dart:async';

import 'package:get/get.dart';

import '../services/chat_api_service.dart';
import '../services/chat_socket_service.dart';

/// Home-top-bar-scoped unread message badge. Distinct from [MessagesController],
/// which is tagged per chat-list screen instance and disposed on close — this
/// one is meant to be put once (mirrors [NotificationsController]'s role) and
/// stay alive for the app session so the badge is correct even before the
/// messages screen has ever been opened.
class ChatUnreadController extends GetxController {
  ChatUnreadController({ChatApiService? apiService})
    : _apiService = apiService ?? const ChatApiService();

  final ChatApiService _apiService;
  final RxInt unreadCount = 0.obs;

  StreamSubscription<Map<String, dynamic>>? _chatUpdatedSubscription;

  @override
  void onInit() {
    super.onInit();
    _chatUpdatedSubscription = ChatSocketService.instance.chatUpdated.listen(
      _handleChatUpdated,
    );
    Future<void>.delayed(const Duration(milliseconds: 2000), () {
      if (isClosed) {
        return;
      }
      refreshUnreadCount();
    });
  }

  @override
  void onClose() {
    _chatUpdatedSubscription?.cancel();
    super.onClose();
  }

  Future<void> refreshUnreadCount() async {
    try {
      final response = await _apiService.getChats();
      unreadCount.value = response.totalUnreadCount;
    } catch (_) {
      // Badge staying stale on a transient failure is fine — the next
      // chat.updated event or screen visit will correct it.
    }
  }

  void _handleChatUpdated(Map<String, dynamic> payload) {
    final total = payload['total_unread_count'];
    if (total == null) {
      return;
    }
    unreadCount.value = total is int
        ? total
        : int.tryParse(total.toString()) ?? unreadCount.value;
  }
}
