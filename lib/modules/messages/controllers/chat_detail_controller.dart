import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../reports/api/reports_api.dart';
import '../models/chat_models.dart';
import '../services/chat_api_service.dart';
import '../services/chat_event_bus.dart';
import '../services/chat_socket_service.dart';
import 'chat_unread_controller.dart';

class ChatDetailController extends GetxController {
  ChatDetailController({
    required this.username,
    required this.conversationId,
    required bool initialIsMessagingStopped,
    bool initialIsBlockedByMe = false,
    bool initialIsBlockedByOther = false,
    ChatApiService? apiService,
  }) : _apiService = apiService ?? const ChatApiService(),
       _initialIsMessagingStopped = initialIsMessagingStopped,
       _initialIsBlockedByMe = initialIsBlockedByMe,
       _initialIsBlockedByOther = initialIsBlockedByOther;

  final String username;
  int conversationId;
  final ChatApiService _apiService;
  final bool _initialIsMessagingStopped;
  final bool _initialIsBlockedByMe;
  final bool _initialIsBlockedByOther;

  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final RxList<ChatMessageModel> messages = <ChatMessageModel>[].obs;
  final Rxn<ChatUserModel> user = Rxn<ChatUserModel>();
  final RxBool isInitialLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isSending = false.obs;
  final RxBool isMessagingStopped = false.obs;
  final RxBool isWaitingForReply = false.obs;
  final RxBool isIncomingChatRequest = false.obs;
  final RxBool isRespondingToRequest = false.obs;
  // Once the other participant has accepted (or replied), the initial
  // message cap never applies again for this conversation.
  bool _isChatAccepted = false;
  final RxString stoppedBannerText = ''.obs;
  final RxString inputText = ''.obs;
  // Whether *this conversation* is currently blocked (either direction) —
  // distinct from isBlocking, which is the loading state of the "block
  // user" action itself.
  final RxBool isBlocked = false.obs;
  // True only when *we* are the one who blocked them (vs. them blocking us).
  final RxBool isBlockedByMe = false.obs;
  final RxBool isBlocking = false.obs;
  final RxBool otherUserTyping = false.obs;

  int _currentPage = 0;
  StreamSubscription<ChatPushEvent>? _pushSubscription;
  final List<StreamSubscription<dynamic>> _socketSubscriptions =
      <StreamSubscription<dynamic>>[];
  Timer? _typingStopTimer;
  Timer? _typingIndicatorTimeout;
  Timer? _seenRefreshTimer;
  bool _seenRefreshInFlight = false;

  /// Number of live socket-stream listeners registered by [_initSocket].
  /// Should always be either 0 (not subscribed) or 6 (subscribed exactly
  /// once) — used by tests to guard against the subscribe-twice leak that
  /// [unblockUser] used to trigger by calling [_initSocket] again without
  /// cancelling the listeners [onInit] had already set up.
  @visibleForTesting
  int get debugSocketSubscriptionCount => _socketSubscriptions.length;

  bool get isComposerDisabled =>
      isMessagingStopped.value ||
      isWaitingForReply.value ||
      isIncomingChatRequest.value;

  bool get canSend =>
      !isSending.value &&
      !isComposerDisabled &&
      inputText.value.trim().isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    final initialIsBlocked = _initialIsBlockedByMe || _initialIsBlockedByOther;
    isMessagingStopped.value = _initialIsMessagingStopped;
    if (initialIsBlocked) {
      isMessagingStopped.value = true;
      _applyBlockBanner(
        isBlockedByMe: _initialIsBlockedByMe,
        isBlockedByOther: _initialIsBlockedByOther,
      );
    } else if (isMessagingStopped.value) {
      stoppedBannerText.value = 'Messaging has been stopped for this chat.';
    }
    scrollController.addListener(_onScroll);
    messageController.addListener(_handleInputChanged);
    _pushSubscription = ChatEventBus.instance.stream.listen(_handlePushEvent);
    fetchMessages(reset: true);
    // Backend rejects presence-conversation channel auth with a 403 for a
    // blocked pair, deliberately — subscribing anyway would just log an
    // auth error on every open of a blocked thread for no benefit, since
    // REST already covers reading/sending here.
    if (!initialIsBlocked) {
      _initSocket();
    }
    _seenRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _refreshSeenState();
    });
  }

  @override
  void onClose() {
    _seenRefreshTimer?.cancel();
    _typingStopTimer?.cancel();
    _typingIndicatorTimeout?.cancel();
    ChatSocketService.instance.sendTyping(conversationId, false);
    ChatSocketService.instance.unsubscribeFromConversation(conversationId);
    messageController
      ..removeListener(_handleInputChanged)
      ..dispose();
    _pushSubscription?.cancel();
    _cancelSocketSubscriptions();
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  /// Subscribes to the conversation's socket streams. Safe to call more
  /// than once (e.g. [unblockUser] re-establishing the presence channel
  /// after it was dropped on a mid-session block) — always cancels any
  /// listeners from a previous call first, so re-entry never leaves
  /// duplicate subscriptions firing on [ChatSocketService]'s app-wide
  /// singleton streams.
  Future<void> _initSocket() async {
    _cancelSocketSubscriptions();
    await ChatSocketService.instance.subscribeToConversation(conversationId);

    _socketSubscriptions.addAll(<StreamSubscription<dynamic>>[
      ChatSocketService.instance.messages.listen(_handleSocketMessage),
      ChatSocketService.instance.deliveries.listen(_handleDelivery),
      ChatSocketService.instance.reads.listen(_handleRead),
      ChatSocketService.instance.messagingState.listen(_handleMessagingState),
      ChatSocketService.instance.typing.listen(_handleTyping),
      ChatSocketService.instance.onReconnected.listen(
        (_) => _syncAfterReconnect(),
      ),
    ]);
  }

  void _cancelSocketSubscriptions() {
    for (final subscription in _socketSubscriptions) {
      subscription.cancel();
    }
    _socketSubscriptions.clear();
  }

  bool _insertIfNew(ChatMessageModel message) {
    if (messages.any((existing) => existing.id == message.id)) {
      return false;
    }
    messages.insert(0, message);
    return true;
  }

  /// Used for the REST send response, which is authoritative for a message
  /// we just sent ourselves. The socket echo of the same message (broadcasts
  /// go to both participants) can arrive first and race ahead of the REST
  /// response — if it computed isMine incorrectly (e.g. sender id fields the
  /// backend didn't include), this replaces that entry instead of silently
  /// keeping the earlier, possibly-wrong one.
  void _insertOrReconcile(ChatMessageModel message) {
    final existingIndex = messages.indexWhere(
      (existing) => existing.id == message.id,
    );
    if (existingIndex >= 0) {
      messages[existingIndex] = message;
    } else {
      messages.insert(0, message);
    }
  }

  Future<void> _ingestIncomingMessage(
    ChatMessageModel message, {
    required bool jumpToBottom,
  }) async {
    if (!_insertIfNew(message)) {
      return;
    }
    _checkChatRequestState();
    if (jumpToBottom) {
      _jumpToBottom();
    }
    if (!message.isMine) {
      try {
        await _apiService.markRead(conversationId, upToMessageId: message.id);
      } catch (_) {
        // Read receipts are best-effort.
      }
      _refreshUnreadBadge();
    }
  }

  /// Keeps the home top-bar unread badge in sync locally right after we
  /// mark something read, instead of waiting on a `chat.updated` socket
  /// push that may only fire for new messages, not read receipts.
  void _refreshUnreadBadge() {
    if (Get.isRegistered<ChatUnreadController>()) {
      Get.find<ChatUnreadController>().refreshUnreadCount();
    }
  }

  void _handleSocketMessage(ChatSocketMessageEvent event) {
    if (event.conversationId != conversationId) {
      return;
    }

    var message = ChatMessageModel.fromJson(
      event.message,
      currentUsername: LocalStorage.getUsername() ?? '',
    );

    final myUserId = LocalStorage.getUserId();
    final senderUserId = _readSenderUserId(event.message);
    if (myUserId != null && senderUserId > 0) {
      message = message.copyWith(isMine: senderUserId == myUserId);
    }

    _ingestIncomingMessage(message, jumpToBottom: true);
  }

  int _readSenderUserId(Map<String, dynamic> json) {
    final sender = json['sender'];
    return _readInt(
      json['sender_user_id'] ??
          json['sender_id'] ??
          (sender is Map ? sender['id'] : null),
    );
  }

  void _handleDelivery(ChatDeliveryEvent event) {
    if (event.conversationId != conversationId) {
      return;
    }
    _applyStatusToIds(event.messageIds, status: 'delivered');
  }

  void _handleRead(ChatReadEvent event) {
    if (event.conversationId != conversationId) {
      return;
    }
    final myUserId = LocalStorage.getUserId();
    if (myUserId != null &&
        event.readerUserId > 0 &&
        event.readerUserId == myUserId) {
      return;
    }

    final ids = event.messageIds.isNotEmpty
        ? event.messageIds
        : (event.lastReadMessageId > 0
              ? <int>[event.lastReadMessageId]
              : const <int>[]);
    _applyStatusToIds(ids, status: 'read', isSeen: true);

    if (event.lastReadMessageId > 0) {
      for (var i = 0; i < messages.length; i++) {
        final message = messages[i];
        if (message.isMine &&
            message.id <= event.lastReadMessageId &&
            !message.isSeen) {
          messages[i] = message.copyWith(status: 'read', isSeen: true);
        }
      }
    }
  }

  void _applyStatusToIds(List<int> ids, {required String status, bool? isSeen}) {
    if (ids.isEmpty) {
      return;
    }
    final idSet = ids.toSet();
    for (var i = 0; i < messages.length; i++) {
      if (idSet.contains(messages[i].id)) {
        messages[i] = messages[i].copyWith(status: status, isSeen: isSeen);
      }
    }
  }

  void _handleMessagingState(ChatMessagingStateEvent event) {
    if (event.conversationId != conversationId) {
      return;
    }
    isMessagingStopped.value = event.isMessagingStopped;
    stoppedBannerText.value = event.isMessagingStopped
        ? 'Messaging has been stopped for this chat.'
        : '';
  }

  void _handleTyping(ChatTypingEvent event) {
    if (event.conversationId != conversationId) {
      return;
    }
    final myUserId = LocalStorage.getUserId()?.toString();
    if (event.userId == myUserId) {
      return;
    }

    _typingIndicatorTimeout?.cancel();
    otherUserTyping.value = event.isTyping;
    if (event.isTyping) {
      _typingIndicatorTimeout = Timer(const Duration(seconds: 6), () {
        otherUserTyping.value = false;
      });
    }
  }

  Future<void> _syncAfterReconnect() async {
    if (messages.isEmpty) {
      return;
    }
    final highestId = messages
        .map((message) => message.id)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (highestId <= 0) {
      return;
    }

    try {
      final response = await _apiService.syncMessages(
        conversationId,
        afterMessageId: highestId,
      );
      for (final message in response.messages) {
        await _ingestIncomingMessage(message, jumpToBottom: false);
      }
    } catch (_) {
      // Best-effort — pull-to-refresh/pagination remain available.
    }
  }

  void _handleTypingSignal(bool isComposing) {
    _typingStopTimer?.cancel();
    if (isComposing) {
      ChatSocketService.instance.sendTyping(conversationId, true);
      _typingStopTimer = Timer(const Duration(seconds: 3), () {
        ChatSocketService.instance.sendTyping(conversationId, false);
      });
    } else {
      ChatSocketService.instance.sendTyping(conversationId, false);
    }
  }

  void _handlePushEvent(ChatPushEvent event) {
    if (!event.isMessageEvent) {
      return;
    }

    final eventConversationId = _readInt(
      event.payload['conversation_id'] ??
          event.payload['chat_id'] ??
          event.payload['conversationId'],
    );
    final eventUsername = _normalize(
      _firstText(
        event.payload['username'],
        event.payload['sender_username'],
        event.payload['chat_username'],
      ),
    );

    if ((eventConversationId > 0 && eventConversationId == conversationId) ||
        (eventUsername.isNotEmpty && eventUsername == _normalize(username))) {
      refreshMessages();
    }
  }

  Future<void> refreshMessages() async {
    await fetchMessages(reset: true);
  }

  /// Marks everything currently loaded as read on open — covers messages
  /// that were already unread before the chat was opened. Live incoming
  /// messages while the screen stays open are separately marked read as
  /// they arrive (see `_ingestIncomingMessage`).
  Future<void> _markConversationRead() async {
    final highestId = messages
        .map((message) => message.id)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (highestId <= 0) {
      return;
    }
    try {
      await _apiService.markRead(conversationId, upToMessageId: highestId);
    } catch (_) {
      // Opening the thread already records the read on the server. A failed
      // follow-up post should still refresh the badge from that result.
    }
    _refreshUnreadBadge();
  }

  /// Copies seen ticks onto messages already on screen. The sender's open
  /// chat otherwise keeps the status from when the message was sent.
  Future<void> _refreshSeenState() async {
    if (isClosed || _seenRefreshInFlight || isInitialLoading.value) {
      return;
    }
    var highestSeen = 0;
    final hasUnseenMine = messages.any((message) {
      if (message.isMine && message.isSeen && message.id > highestSeen) {
        highestSeen = message.id;
      }
      return message.isMine && !message.isSeen;
    });
    if (!hasUnseenMine || conversationId <= 0) {
      return;
    }

    _seenRefreshInFlight = true;
    try {
      final response = await _apiService.getMessages(username, page: 1);
      if (isClosed) {
        return;
      }
      for (final fresh in response.messages) {
        if (fresh.isMine && fresh.isSeen && fresh.id > highestSeen) {
          highestSeen = fresh.id;
        }
      }
      if (highestSeen <= 0) {
        return;
      }
      for (var i = 0; i < messages.length; i++) {
        final message = messages[i];
        if (message.isMine && !message.isSeen && message.id <= highestSeen) {
          messages[i] = message.copyWith(status: 'seen', isSeen: true);
        }
      }
    } catch (_) {
      // The next pass retries.
    } finally {
      _seenRefreshInFlight = false;
    }
  }

  /// Backend now tells us directly which side blocked which via
  /// is_blocked_by_me / is_blocked_by_other on the 403 body and on chat
  /// list/initialize/messages responses — no more guessing from profile
  /// data. Falls back to a neutral message if neither flag is set despite
  /// a 403 (shouldn't happen per the backend's own rule, but don't assert
  /// a direction we don't actually know).
  void _applyBlockBanner({
    required bool isBlockedByMe,
    required bool isBlockedByOther,
  }) {
    isBlocked.value = true;
    this.isBlockedByMe.value = isBlockedByMe;
    if (isBlockedByMe) {
      stoppedBannerText.value = 'You have blocked this user.';
    } else if (isBlockedByOther) {
      stoppedBannerText.value = 'This user has blocked you.';
    } else {
      stoppedBannerText.value = 'You can\'t message this user.';
    }
  }

  Future<void> fetchMessages({required bool reset}) async {
    if (reset) {
      isInitialLoading.value = true;
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
      final response = await _apiService.getMessages(
        username,
        page: reset ? 1 : _currentPage + 1,
      );

      user.value = response.user;
      isMessagingStopped.value = response.isMessagingStopped;
      if (response.isMessagingStopped) {
        stoppedBannerText.value = 'Messaging has been stopped for this chat.';
      } else if (stoppedBannerText.value ==
          'Messaging has been stopped for this chat.') {
        stoppedBannerText.value = '';
      }

      if (reset) {
        messages.assignAll(response.messages);
      } else {
        messages.addAll(response.messages);
      }

      // More than the unaccepted cap means this conversation is already
      // established — even if the current page is only our messages.
      if (response.isAccepted ||
          response.pagination.total > kChatRequestMessageLimit) {
        _isChatAccepted = true;
      }

      _checkChatRequestState(
        apiIsPending: response.isPendingRequest,
        apiIsIncoming: response.isIncomingRequest,
        apiIsAccepted: response.isAccepted,
      );

      _currentPage = response.pagination.currentPage;
      hasMore.value = response.pagination.hasMorePages;

      if (response.conversationId > 0 &&
          response.conversationId != conversationId) {
        ChatSocketService.instance.unsubscribeFromConversation(conversationId);
        conversationId = response.conversationId;
        if (!isBlocked.value) {
          _initSocket();
        }
      }

      if (reset && messages.isNotEmpty) {
        _jumpToBottom();
        _markConversationRead();
      }
    } on ChatApiException catch (error) {
      if (error.httpStatusCode == 403) {
        isMessagingStopped.value = true;
        _applyBlockBanner(
          isBlockedByMe: error.isBlockedByMe,
          isBlockedByOther: error.isBlockedByOther,
        );
        ChatSocketService.instance.unsubscribeFromConversation(conversationId);
      } else {
        hasError.value = true;
        errorMessage.value = error.message;
        if (!reset) {
          errorSnackBar(message: error.message);
        }
      }
    } catch (_) {
      hasError.value = true;
      errorMessage.value = 'Unable to load messages right now.';
      if (!reset) {
        errorSnackBar(message: errorMessage.value);
      }
    } finally {
      if (reset) {
        isInitialLoading.value = false;
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> reactToMessage(ChatMessageModel message, String emoji) async {
    final trimmed = emoji.trim();
    if (trimmed.isEmpty || conversationId <= 0 || message.id <= 0) {
      return;
    }
    try {
      final updated = await _apiService.toggleReaction(
        conversationId: conversationId,
        messageId: message.id,
        emoji: trimmed,
      );
      _insertOrReconcile(updated);
      messages.refresh();
    } on ChatApiException catch (error) {
      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Could not update reaction.');
    }
  }

  Future<void> sendCurrentMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isSending.value || isComposerDisabled) {
      return;
    }

    isSending.value = true;
    try {
      final response = await _apiService.sendMessage(conversationId, text);
      isMessagingStopped.value = response.isMessagingStopped;
      final nextMessage = response.chatMessage;
      if (nextMessage != null) {
        _insertOrReconcile(nextMessage.copyWith(isMine: true));
      } else {
        _insertOrReconcile(
          ChatMessageModel(
            id: DateTime.now().millisecondsSinceEpoch,
            body: text,
            senderUsername: '',
            isMine: true,
            createdAt: DateTime.now().toIso8601String(),
            timeLabel: 'Now',
            status: 'sent',
            isSeen: false,
          ),
        );
      }

      messageController.clear();
      _typingStopTimer?.cancel();
      ChatSocketService.instance.sendTyping(conversationId, false);
      stoppedBannerText.value = '';
      _checkChatRequestState();
      _jumpToBottom();
    } on ChatApiException catch (error) {
      if (error.httpStatusCode == 403) {
        isMessagingStopped.value = true;
        _applyBlockBanner(
          isBlockedByMe: error.isBlockedByMe,
          isBlockedByOther: error.isBlockedByOther,
        );
        // A block discovered mid-session (we were already subscribed) —
        // channel auth will just 403 on any future reconnect, so drop it.
        ChatSocketService.instance.unsubscribeFromConversation(conversationId);
        return;
      }

      if (error.httpStatusCode == 422 &&
          (error.message.toLowerCase().contains('wait') ||
              error.message.toLowerCase().contains('limit') ||
              error.message.toLowerCase().contains('chat request'))) {
        isWaitingForReply.value = true;
        infoSnackBar(message: error.message);
        return;
      }

      if (error.httpStatusCode == 422 &&
          error.message == 'Messaging has been stopped for this chat.') {
        isMessagingStopped.value = true;
        stoppedBannerText.value = error.message;
        errorSnackBar(message: error.message);
        return;
      }

      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Unable to send message right now.');
    } finally {
      isSending.value = false;
    }
  }

  void _checkChatRequestState({
    bool apiIsPending = false,
    bool apiIsIncoming = false,
    bool apiIsAccepted = false,
  }) {
    if (isBlocked.value || isMessagingStopped.value) {
      isIncomingChatRequest.value = false;
      isWaitingForReply.value = false;
      return;
    }

    if (apiIsAccepted) {
      _isChatAccepted = true;
    }

    final myCount = messages.where((message) => message.isMine).length;
    final theirCount = messages.where((message) => !message.isMine).length;

    if (theirCount > 0 && myCount > 0) {
      _isChatAccepted = true;
    }

    if (_isChatAccepted) {
      isIncomingChatRequest.value = false;
      isWaitingForReply.value = false;
      return;
    }

    final incoming = apiIsIncoming || (theirCount > 0 && myCount == 0);
    isIncomingChatRequest.value = incoming;
    if (incoming) {
      isWaitingForReply.value = false;
      return;
    }

    final pendingOutgoing = apiIsPending || myCount > 0;
    isWaitingForReply.value =
        pendingOutgoing && myCount >= kChatRequestMessageLimit;
  }

  Future<void> acceptChatRequest() async {
    if (isRespondingToRequest.value || !isIncomingChatRequest.value) {
      return;
    }

    isRespondingToRequest.value = true;
    try {
      await _apiService.acceptChatRequest(conversationId);
      _markRequestAccepted();
      successSnackBar(message: 'Chat request accepted.');
    } on ChatApiException catch (error) {
      if (error.httpStatusCode == 404) {
        _markRequestAccepted();
        successSnackBar(message: 'Chat request accepted.');
      } else {
        errorSnackBar(message: error.message);
      }
    } catch (_) {
      errorSnackBar(message: 'Unable to accept this chat request.');
    } finally {
      isRespondingToRequest.value = false;
    }
  }

  Future<void> rejectChatRequest() async {
    if (isRespondingToRequest.value || !isIncomingChatRequest.value) {
      return;
    }

    isRespondingToRequest.value = true;
    try {
      await _apiService.rejectChatRequest(conversationId);
      _removeThreadFromInbox();
      successSnackBar(message: 'Chat request rejected.');
      Get.back<void>();
    } on ChatApiException catch (error) {
      if (error.httpStatusCode == 404) {
        _removeThreadFromInbox();
        successSnackBar(message: 'Chat request rejected.');
        Get.back<void>();
      } else {
        errorSnackBar(message: error.message);
      }
    } catch (_) {
      errorSnackBar(message: 'Unable to reject this chat request.');
    } finally {
      isRespondingToRequest.value = false;
    }
  }

  void _markRequestAccepted() {
    _isChatAccepted = true;
    isIncomingChatRequest.value = false;
    isWaitingForReply.value = false;
  }

  void _removeThreadFromInbox() {
    ChatEventBus.instance.publish(
      ChatPushEvent(
        type: 'conversation.removed',
        payload: <String, dynamic>{'conversation_id': conversationId},
      ),
    );
  }

  Future<void> toggleChatMessaging() async {
    if (isSending.value) {
      return;
    }

    try {
      final response = isMessagingStopped.value
          ? await _apiService.resumeMessaging(conversationId)
          : await _apiService.stopMessaging(conversationId);
      isMessagingStopped.value = response.isMessagingStopped;
      stoppedBannerText.value = response.isMessagingStopped
          ? 'Messaging has been stopped for this chat.'
          : '';
      infoSnackBar(
        message: response.message.isNotEmpty
            ? response.message
            : (response.isMessagingStopped
                  ? 'Messaging has been stopped for this chat.'
                  : 'You can start again now.'),
      );
    } on ChatApiException catch (error) {
      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Unable to update this chat right now.');
    }
  }

  Future<void> blockUser() async {
    if (isBlocking.value) {
      return;
    }

    isBlocking.value = true;
    try {
      await _apiService.blockUser(username);
      successSnackBar(message: 'User blocked successfully.');
      Get.back();
    } on ChatApiException catch (error) {
      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Unable to block user right now.');
    } finally {
      isBlocking.value = false;
    }
  }

  Future<void> unblockUser() async {
    if (isBlocking.value) {
      return;
    }

    isBlocking.value = true;
    try {
      await _apiService.unblockUser(username);
      successSnackBar(message: 'User unblocked successfully.');
      isBlocked.value = false;
      isBlockedByMe.value = false;
      isMessagingStopped.value = false;
      stoppedBannerText.value = '';
      // We deliberately skipped the presence channel while blocked — pick
      // it back up now that messaging works again.
      _initSocket();
    } on ChatApiException catch (error) {
      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Unable to unblock user right now.');
    } finally {
      isBlocking.value = false;
    }
  }

  Future<void> reportMessage(
    int messageId,
    String reasonCode,
    String? details,
  ) async {
    try {
      final result = await ReportsApi.submitReport(
        targetType: 'message',
        targetId: messageId,
        reason: reasonCode,
        description: details,
      );
      if (result.alreadyReported) {
        infoSnackBar(
          message: 'You already reported this. Our team is reviewing it.',
        );
      } else {
        successSnackBar(message: 'Message reported. Thanks for letting us know.');
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> stopMessaging() => toggleChatMessaging();

  Future<void> resumeMessaging() => toggleChatMessaging();

  void _handleInputChanged() {
    // TextEditingController notifies listeners on selection changes too
    // (e.g. tapping the field to place the cursor), not just text edits —
    // only treat an actual text change as a typing signal.
    final text = messageController.text;
    if (text == inputText.value) {
      return;
    }
    inputText.value = text;
    _handleTypingSignal(text.trim().isNotEmpty);
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }

    final position = scrollController.position;
    // In a reversed ListView, reaching the top (older messages) means reaching maxScrollExtent
    if (position.pixels >= position.maxScrollExtent - 200) {
      fetchMessages(reset: false);
    }
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) {
        return;
      }
      // In a reversed ListView, 0 is the bottom (latest message)
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  String _normalize(String raw) =>
      raw.trim().replaceFirst('@', '').toLowerCase();

  String _firstText(dynamic first, [dynamic second, dynamic third]) {
    final values = <dynamic>[first, second, third];
    for (final value in values) {
      final resolved = value?.toString().trim();
      if (resolved != null && resolved.isNotEmpty && resolved != 'null') {
        return resolved;
      }
    }
    return '';
  }
}
