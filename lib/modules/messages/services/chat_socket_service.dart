import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:pusher_client_socket/pusher_client_socket.dart';

import '../../../core/utils/config.dart';
import '../../../core/utils/local_storage.dart';
import 'chat_event_bus.dart';

class ChatSocketMessageEvent {
  const ChatSocketMessageEvent({
    required this.conversationId,
    required this.message,
  });

  final int conversationId;
  final Map<String, dynamic> message;
}

class ChatDeliveryEvent {
  const ChatDeliveryEvent({
    required this.conversationId,
    required this.recipientUserId,
    required this.messageIds,
    required this.deliveredAt,
  });

  final int conversationId;
  final int recipientUserId;
  final List<int> messageIds;
  final String deliveredAt;
}

class ChatReadEvent {
  const ChatReadEvent({
    required this.conversationId,
    required this.readerUserId,
    required this.lastReadMessageId,
    required this.messageIds,
    required this.readAt,
  });

  final int conversationId;
  final int readerUserId;
  final int lastReadMessageId;
  final List<int> messageIds;
  final String readAt;
}

class ChatMessagingStateEvent {
  const ChatMessagingStateEvent({
    required this.conversationId,
    required this.isMessagingStopped,
    required this.stoppedByUserId,
  });

  final int conversationId;
  final bool isMessagingStopped;
  final int stoppedByUserId;
}

class ChatTypingEvent {
  const ChatTypingEvent({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
  });

  final int conversationId;
  final String userId;
  final bool isTyping;
}

/// Wraps the Pusher Channels connection used for realtime chat. REST remains
/// the source of truth (see `Backend_socket_requirements.md`) — this service
/// is purely a live speed layer on top of it, so every failure here is caught
/// and logged rather than surfaced to the UI.
class ChatSocketService {
  ChatSocketService._();

  static final ChatSocketService instance = ChatSocketService._();

  static const Duration _typingThrottle = Duration(seconds: 3);

  static const List<String> _userEventNames = [
    'chat.updated',
    'notification.created',
    'notification.updated',
    'notifications.updated',
    'post.liked',
    'post.like',
    'like.created',
    'Illuminate\\Notifications\\Events\\BroadcastNotificationCreated',
    '.Illuminate\\Notifications\\Events\\BroadcastNotificationCreated',
    '*',
  ];

  static const List<String> _conversationEventNames = [
    'message.sent',
    'messages.delivered',
    'messages.read',
    'messaging.state',
    'client-typing',
  ];

  PusherClient? _client;

  final StreamController<Map<String, dynamic>> _chatUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<ChatSocketMessageEvent> _messageController =
      StreamController<ChatSocketMessageEvent>.broadcast();
  final StreamController<ChatDeliveryEvent> _deliveryController =
      StreamController<ChatDeliveryEvent>.broadcast();
  final StreamController<ChatReadEvent> _readController =
      StreamController<ChatReadEvent>.broadcast();
  final StreamController<ChatMessagingStateEvent> _messagingStateController =
      StreamController<ChatMessagingStateEvent>.broadcast();
  final StreamController<ChatTypingEvent> _typingController =
      StreamController<ChatTypingEvent>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get chatUpdated => _chatUpdatedController.stream;
  Stream<ChatSocketMessageEvent> get messages => _messageController.stream;
  Stream<ChatDeliveryEvent> get deliveries => _deliveryController.stream;
  Stream<ChatReadEvent> get reads => _readController.stream;
  Stream<ChatMessagingStateEvent> get messagingState =>
      _messagingStateController.stream;
  Stream<ChatTypingEvent> get typing => _typingController.stream;

  /// Fires `true` whenever the connection transitions into CONNECTED after
  /// having been in any other state — the cue to run reconnect-sync.
  Stream<bool> get onReconnected => _connectionController.stream;

  bool _isConnecting = false;
  bool _wasConnected = false;
  PrivateChannel? _userChannel;
  final Map<int, PresenceChannel> _conversationChannels = <int, PresenceChannel>{};
  final Set<int> _confirmedConversationSubscriptions = <int>{};

  /// Test-only seam: lets tests simulate a confirmed conversation
  /// subscription without going through the real Pusher plugin, and read
  /// it back to verify [disconnect] actually clears it.
  @visibleForTesting
  void debugMarkConversationConfirmed(int conversationId) {
    _confirmedConversationSubscriptions.add(conversationId);
  }

  @visibleForTesting
  bool debugIsConversationConfirmed(int conversationId) =>
      _confirmedConversationSubscriptions.contains(conversationId);

  Timer? _pendingTypingTimer;
  DateTime? _lastTypingSentAt;
  bool? _lastTypingSentValue;
  int? _lastTypingConversationId;

  Future<void> connect() async {
    if (!realtimeEnabled) {
      return;
    }
    final token = LocalStorage.getAccessKey();
    if (token == null || token.trim().isEmpty || _isConnecting) {
      return;
    }
    _isConnecting = true;

    try {
      var client = _client;
      if (client == null) {
        client = PusherClient(
          options: PusherOptions(
            key: pusherAppKey,
            host: pusherHost,
            cluster: pusherCluster,
            wsPort: pusherPort,
            wssPort: pusherPort,
            encrypted: pusherUseTLS,
            autoConnect: false,
            enableLogging: kDebugMode,
            authOptions: PusherAuthOptions(
              '${kcBaseAPIUrl}broadcasting/auth',
              headers: () async => <String, String>{
                'Accept': 'application/json',
                'Authorization':
                    'Bearer ${LocalStorage.getAccessKey() ?? ''}',
              },
            ),
          ),
        );
        client.onConnectionStateChange(_handleConnectionStateChange);
        client.onConnectionError((dynamic error) {
          log('Pusher connection error :: $error');
        });
        client.onError((dynamic error) {
          log('Pusher error :: $error');
        });
        _client = client;
      }

      if (!client.connected) {
        client.connect();
      }
      await _subscribeToUserChannel();
    } catch (e, stackTrace) {
      log('ChatSocketService.connect failed: $e', stackTrace: stackTrace);
    } finally {
      _isConnecting = false;
    }
  }

  Future<void> disconnect() async {
    try {
      _pendingTypingTimer?.cancel();

      for (final channel in _conversationChannels.values) {
        _teardownChannel(channel, _conversationEventNames);
      }
      _conversationChannels.clear();
      _confirmedConversationSubscriptions.clear();

      final userChannel = _userChannel;
      if (userChannel != null) {
        _teardownChannel(userChannel, _userEventNames);
        _userChannel = null;
      }

      _wasConnected = false;

      final client = _client;
      if (client != null) {
        client.disconnect();
      }
    } catch (e) {
      log('ChatSocketService.disconnect failed: $e');
    }
  }

  void _teardownChannel(Channel channel, List<String> eventNames) {
    try {
      channel.unsubscribe();
    } catch (e) {
      log('Unable to unsubscribe from ${channel.name}: $e');
      for (final eventName in eventNames) {
        channel.unbind(eventName);
      }
    }
  }

  Future<void> _subscribeToUserChannel() async {
    final client = _client;
    if (client == null) {
      return;
    }

    final userId = LocalStorage.getUserId();
    if (userId == null || userId <= 0) {
      log('ChatSocketService: no local userId — private-user channel not subscribed.');
      return;
    }

    if (_userChannel != null) {
      log('ChatSocketService: private-user.$userId already subscribed.');
      return;
    }

    final channelName = 'private-user.$userId';
    try {
      final channel = client.private(channelName, subscribe: true);
      channel.onSubscriptionSuccess((dynamic data) {
        log('ChatSocketService: subscribed to $channelName.');
      });
      channel.bind('chat.updated', (dynamic data) {
        final payload = _decodeEventData(data);
        if (payload == null) {
          log('ChatSocketService: chat.updated payload failed to decode.');
          return;
        }
        if (!_chatUpdatedController.isClosed) {
          _chatUpdatedController.add(payload);
        }
      });
      channel.bind('*', (dynamic event) {
        if (event is! Map) {
          return;
        }
        final eventName = (event['event'] ?? '').toString();
        _forwardUserNotificationEvent(eventName, event['data']);
      });
      for (final eventName in _userEventNames) {
        if (eventName == 'chat.updated' || eventName == '*') {
          continue;
        }
        channel.bind(eventName, (dynamic data) {
          _forwardUserNotificationEvent(eventName, data);
        });
      }
      _userChannel = channel;
    } catch (e) {
      log('Unable to subscribe to $channelName: $e');
    }
  }

  Future<void> subscribeToConversation(int conversationId) async {
    final client = _client;
    if (client == null ||
        conversationId <= 0 ||
        _conversationChannels.containsKey(conversationId)) {
      return;
    }

    final channelName = 'presence-conversation.$conversationId';
    try {
      final channel = client.presence(channelName, subscribe: true);
      channel.onSubscriptionSuccess((dynamic data) {
        _confirmedConversationSubscriptions.add(conversationId);
      });
      for (final eventName in _conversationEventNames) {
        channel.bind(
          eventName,
          (dynamic data) => _handleConversationEvent(
            conversationId,
            eventName,
            data,
          ),
        );
      }
      _conversationChannels[conversationId] = channel;
    } catch (e) {
      log('Unable to subscribe to $channelName: $e');
    }
  }

  Future<void> unsubscribeFromConversation(int conversationId) async {
    final channel = _conversationChannels.remove(conversationId);
    _confirmedConversationSubscriptions.remove(conversationId);
    if (channel == null) {
      return;
    }
    _teardownChannel(channel, _conversationEventNames);
  }

  /// Throttled to a minimum 3s gap between sends per backend requirement.
  /// Sends are coalesced (trailing edge) so the final desired state is
  /// always eventually delivered even if it arrives inside the throttle
  /// window of a previous send.
  Future<void> sendTyping(int conversationId, bool isTyping) async {
    if (_lastTypingConversationId == conversationId &&
        _lastTypingSentValue == isTyping) {
      return;
    }

    final now = DateTime.now();
    final elapsed = _lastTypingSentAt == null
        ? null
        : now.difference(_lastTypingSentAt!);

    if (elapsed != null &&
        elapsed < _typingThrottle &&
        _lastTypingConversationId == conversationId) {
      final remaining = _typingThrottle - elapsed;
      _pendingTypingTimer?.cancel();
      _pendingTypingTimer = Timer(
        remaining,
        () => _emitTyping(conversationId, isTyping),
      );
      return;
    }

    _pendingTypingTimer?.cancel();
    await _emitTyping(conversationId, isTyping);
  }

  Future<void> _emitTyping(int conversationId, bool isTyping) async {
    final channel = _conversationChannels[conversationId];
    if (channel == null ||
        !_confirmedConversationSubscriptions.contains(conversationId)) {
      return;
    }

    _lastTypingSentAt = DateTime.now();
    _lastTypingSentValue = isTyping;
    _lastTypingConversationId = conversationId;

    try {
      channel.trigger('client-typing', <String, dynamic>{
        'user_id': LocalStorage.getUserId(),
        'is_typing': isTyping,
      });
    } catch (e) {
      log('Unable to send typing event on ${channel.name}: $e');
    }
  }

  void _handleConnectionStateChange(ConnectionState state) {
    final isConnected = state is Connected || state is Reconnected;
    if (isConnected && !_wasConnected) {
      _connectionController.add(true);
    }
    _wasConnected = isConnected;
  }

  void _handleConversationEvent(
    int conversationId,
    String eventName,
    dynamic data,
  ) {
    final payload = _decodeEventData(data);
    if (payload == null) {
      return;
    }

    switch (eventName) {
      case 'message.sent':
        final message = payload['message'];
        if (message is Map<String, dynamic>) {
          _messageController.add(
            ChatSocketMessageEvent(
              conversationId: conversationId,
              message: message,
            ),
          );
        }
        break;
      case 'messages.delivered':
        _deliveryController.add(
          ChatDeliveryEvent(
            conversationId: conversationId,
            recipientUserId: _readInt(payload['recipient_user_id']),
            messageIds: _readIntList(payload['message_ids']),
            deliveredAt: (payload['delivered_at'] ?? '').toString(),
          ),
        );
        break;
      case 'messages.read':
        _readController.add(
          ChatReadEvent(
            conversationId: conversationId,
            readerUserId: _readInt(payload['reader_user_id']),
            lastReadMessageId: _readInt(payload['last_read_message_id']),
            messageIds: _readIntList(payload['message_ids']),
            readAt: (payload['read_at'] ?? '').toString(),
          ),
        );
        break;
      case 'messaging.state':
        _messagingStateController.add(
          ChatMessagingStateEvent(
            conversationId: conversationId,
            isMessagingStopped: payload['is_messaging_stopped'] == true,
            stoppedByUserId: _readInt(
              payload['messaging_stopped_by_user_id'],
            ),
          ),
        );
        break;
      case 'client-typing':
        _typingController.add(
          ChatTypingEvent(
            conversationId: conversationId,
            userId: (payload['user_id'] ?? '').toString(),
            isTyping: payload['is_typing'] == true,
          ),
        );
        break;
    }
  }

  void _forwardUserNotificationEvent(String eventName, dynamic data) {
    final normalized = eventName.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'chat.updated' ||
        normalized.startsWith('pusher:') ||
        normalized.startsWith('client-')) {
      return;
    }

    final payload = _decodeEventData(data) ?? <String, dynamic>{};
    final nested = payload['notification'] ?? payload['data'] ?? payload;
    final map = nested is Map
        ? Map<String, dynamic>.from(nested)
        : payload;
    final type = (map['type'] ??
            payload['type'] ??
            payload['notification_type'] ??
            eventName)
        .toString();
    log(
      'ChatSocketService: user event $eventName type=$type payload=$map',
    );
    ChatEventBus.instance.publish(
      ChatPushEvent(
        type: type,
        payload: <String, dynamic>{
          ...payload,
          ...map,
          'event': eventName,
        },
      ),
    );
  }

  Map<String, dynamic>? _decodeEventData(dynamic data) {
    if (data == null) {
      return null;
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    try {
      final decoded = jsonDecode(data.toString());
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore malformed payloads — REST stays the source of truth.
    }
    return null;
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  List<int> _readIntList(dynamic value) {
    if (value is! List) {
      return const <int>[];
    }
    return value.map(_readInt).where((id) => id > 0).toList(growable: false);
  }
}
