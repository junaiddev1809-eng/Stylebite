import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_helper.dart';
import '../../../core/utils/verified_badge_hydrator.dart';
import '../models/chat_models.dart';
import '../screen/chat_detail_screen.dart';
import '../services/chat_api_service.dart';
import '../services/chat_event_bus.dart';
import '../services/chat_socket_service.dart';
import '../utils/chat_block_navigation.dart';

class MessagesController extends GetxController {
  MessagesController({ChatApiService? apiService})
    : _apiService = apiService ?? const ChatApiService();

  final ChatApiService _apiService;
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final RxList<ChatThreadModel> chats = <ChatThreadModel>[].obs;
  final RxBool isInitialLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString query = ''.obs;

  Timer? _debounce;
  StreamSubscription<ChatPushEvent>? _pushSubscription;
  StreamSubscription<Map<String, dynamic>>? _chatUpdatedSubscription;
  int _currentPage = 0;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    _pushSubscription = ChatEventBus.instance.stream.listen(_handlePushEvent);
    _chatUpdatedSubscription = ChatSocketService.instance.chatUpdated.listen(
      _handleChatUpdated,
    );
    fetchChats(reset: true);
  }

  @override
  void onClose() {
    _debounce?.cancel();
    _pushSubscription?.cancel();
    _chatUpdatedSubscription?.cancel();
    searchController.dispose();
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  void _handlePushEvent(ChatPushEvent event) {
    if (event.type.toLowerCase() == 'conversation.removed') {
      final rawId = event.payload['conversation_id'] ?? event.payload['chat_id'];
      final conversationId = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '') ?? 0;
      if (conversationId > 0) {
        chats.removeWhere((thread) => thread.conversationId == conversationId);
      }
      return;
    }
    if (event.isMessageEvent) {
      fetchChats(reset: true);
    }
  }

  void _handleChatUpdated(Map<String, dynamic> payload) {
    log('MessagesController: chat.updated received :: $payload');
    final chatJson = payload['chat'];
    if (chatJson is! Map<String, dynamic>) {
      log('MessagesController: chat.updated payload missing "chat" object.');
      return;
    }

    final updated = ChatThreadModel.fromJson(chatJson);
    if (updated.conversationId <= 0) {
      log('MessagesController: chat.updated resolved conversationId <= 0.');
      return;
    }

    final existingIndex = chats.indexWhere(
      (thread) => thread.conversationId == updated.conversationId,
    );
    if (existingIndex >= 0) {
      chats.removeAt(existingIndex);
    }
    chats.insert(0, updated);
  }

  void onQueryChanged(String value) {
    query.value = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      fetchChats(reset: true);
    });
  }

  Future<void> refreshChats() async {
    await fetchChats(reset: true);
  }

  Future<void> fetchChats({required bool reset, bool silent = false}) async {
    final showInitialLoading = reset && !silent;
    if (reset) {
      if (showInitialLoading) {
        isInitialLoading.value = true;
      }
      hasError.value = false;
      errorMessage.value = '';
      _currentPage = 0;
      hasMore.value = false;
    } else {
      if (isInitialLoading.value || isLoadingMore.value || !hasMore.value) {
        return;
      }
      isLoadingMore.value = true;
    }

    try {
      final response = await _apiService.getChats(
        search: query.value.trim().isEmpty ? null : query.value.trim(),
        page: reset ? 1 : _currentPage + 1,
      );

      if (reset) {
        chats.assignAll(response.chats);
      } else {
        chats.addAll(response.chats);
      }

      _currentPage = response.pagination.currentPage;
      hasMore.value = response.pagination.hasMorePages;
      VerifiedBadgeHydrator.hydrate(
        response.chats.map((thread) => thread.user.username),
      );

      log(
        'MessagesController: fetched ${response.chats.length} chat(s), '
        'totalUnreadCount=${response.totalUnreadCount}, '
        'page=${response.pagination.currentPage}/${response.pagination.lastPage}',
      );
      for (final thread in response.chats) {
        log(
          '  chat: conversationId=${thread.conversationId} '
          'username=${thread.user.username} '
          'unreadCount=${thread.unreadCount} '
          'isBlockedByMe=${thread.isBlockedByMe} '
          'isBlockedByOther=${thread.isBlockedByOther} '
          'isStopped=${thread.isStopped} '
          'isOnline=${thread.user.isOnline} '
          'lastMessageTime=${thread.lastMessageTime}',
        );
      }
    } on ChatApiException catch (error) {
      hasError.value = true;
      errorMessage.value = error.message;
      if (!reset) {
        errorSnackBar(message: error.message);
      }
    } catch (_) {
      hasError.value = true;
      errorMessage.value = 'Unable to load chats right now.';
      if (!reset) {
        errorSnackBar(message: errorMessage.value);
      }
    } finally {
      if (showInitialLoading) {
        isInitialLoading.value = false;
      } else if (!reset) {
        isLoadingMore.value = false;
      }
    }
  }

  void markThreadRead(int conversationId) {
    if (conversationId <= 0) {
      return;
    }
    final index = chats.indexWhere(
      (thread) => thread.conversationId == conversationId,
    );
    if (index < 0 || chats[index].unreadCount == 0) {
      return;
    }
    chats[index] = chats[index].copyWith(unreadCount: 0);
  }

  Future<void> _pushChat({
    required String username,
    required int conversationId,
    required bool initialIsMessagingStopped,
    bool initialIsBlockedByMe = false,
    bool initialIsBlockedByOther = false,
  }) async {
    markThreadRead(conversationId);
    await Get.to<void>(
      () => ChatDetailScreen(
        username: username,
        conversationId: conversationId,
        initialIsMessagingStopped: initialIsMessagingStopped,
        initialIsBlockedByMe: initialIsBlockedByMe,
        initialIsBlockedByOther: initialIsBlockedByOther,
      ),
    );
    if (isClosed) {
      return;
    }
    await fetchChats(reset: true, silent: true);
  }

  Future<void> openChat(ChatThreadModel thread) async {
    try {
      final initialized = await _apiService.initializeChat(
        thread.user.username,
      );
      final resolvedConversationId = initialized.conversationId > 0
          ? initialized.conversationId
          : thread.conversationId;
      final isBlockedByMe = initialized.isBlockedByMe || thread.isBlockedByMe;
      final isBlockedByOther =
          initialized.isBlockedByOther || thread.isBlockedByOther;
      await _pushChat(
        username: thread.user.username,
        conversationId: resolvedConversationId,
        initialIsMessagingStopped:
            initialized.isMessagingStopped ||
            thread.isMessagingStopped ||
            isBlockedByMe ||
            isBlockedByOther,
        initialIsBlockedByMe: isBlockedByMe,
        initialIsBlockedByOther: isBlockedByOther,
      );
    } on ChatApiException catch (error) {
      if (error.httpStatusCode == 403 && thread.conversationId > 0) {
        await _pushChat(
          username: thread.user.username,
          conversationId: thread.conversationId,
          initialIsMessagingStopped: true,
          initialIsBlockedByMe: error.isBlockedByMe,
          initialIsBlockedByOther: error.isBlockedByOther,
        );
        return;
      }
      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Unable to open this chat right now.');
    }
  }

  Future<void> openFromPayload({
    required String username,
    int? conversationId,
  }) async {
    final normalizedUsername = username.trim().replaceFirst('@', '');
    if (normalizedUsername.isEmpty) {
      return;
    }

    if (conversationId != null && conversationId > 0) {
      await _pushChat(
        username: normalizedUsername,
        conversationId: conversationId,
        initialIsMessagingStopped: false,
      );
      return;
    }

    try {
      final initialized = await _apiService.initializeChat(normalizedUsername);
      await _pushChat(
        username: normalizedUsername,
        conversationId: initialized.conversationId,
        initialIsMessagingStopped:
            initialized.isMessagingStopped || initialized.isBlocked,
        initialIsBlockedByMe: initialized.isBlockedByMe,
        initialIsBlockedByOther: initialized.isBlockedByOther,
      );
    } on ChatApiException catch (error) {
      final blocked = resolveBlockedChatNavigation(
        error,
        username: normalizedUsername,
      );
      if (blocked != null) {
        await _pushChat(
          username: blocked.username,
          conversationId: blocked.conversationId,
          initialIsMessagingStopped: true,
          initialIsBlockedByMe: blocked.isBlockedByMe,
          initialIsBlockedByOther: blocked.isBlockedByOther,
        );
        return;
      }
      errorSnackBar(message: error.message);
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }

    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      fetchChats(reset: false);
    }
  }
}
