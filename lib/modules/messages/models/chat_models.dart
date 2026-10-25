import '../../../core/utils/app_time_formatter.dart';
import '../../../core/utils/verified_flag.dart';

/// How many messages the requester can send before the other person
/// must accept the chat request.
const int kChatRequestMessageLimit = 3;

class ChatApiMessage {
  const ChatApiMessage({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  factory ChatApiMessage.fromJson(Map<String, dynamic> json) {
    return ChatApiMessage(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
    );
  }
}

class ChatPaginationModel {
  const ChatPaginationModel({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.hasMorePages,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool hasMorePages;

  factory ChatPaginationModel.fromJson(Map<String, dynamic> json) {
    final currentPage = _asInt(json['current_page'] ?? json['page']);
    final lastPage = _asInt(json['last_page']);

    return ChatPaginationModel(
      currentPage: currentPage <= 0 ? 1 : currentPage,
      perPage: _asInt(json['per_page']) <= 0 ? 20 : _asInt(json['per_page']),
      total: _asInt(json['total']),
      lastPage: lastPage <= 0 ? 1 : lastPage,
      hasMorePages:
          _asBool(json['has_more_pages']) ||
          (lastPage > 0 && currentPage > 0 && currentPage < lastPage),
    );
  }
}

class ChatUserModel {
  const ChatUserModel({
    required this.id,
    required this.username,
    required this.name,
    required this.imageUrl,
    required this.isOnline,
    required this.isVerifiedBadge,
  });

  final int id;
  final String username;
  final String name;
  final String imageUrl;
  final bool isOnline;
  final bool isVerifiedBadge;

  String get displayName {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    if (username.trim().isNotEmpty) {
      return username.trim();
    }
    return 'User';
  }

  ChatUserModel copyWith({bool? isOnline}) {
    return ChatUserModel(
      id: id,
      username: username,
      name: name,
      imageUrl: imageUrl,
      isOnline: isOnline ?? this.isOnline,
      isVerifiedBadge: isVerifiedBadge,
    );
  }

  factory ChatUserModel.fromJson(Map<String, dynamic> json) {
    final profile =
        (json['profile'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return ChatUserModel(
      id: _asInt(json['id']),
      username: _firstText(
        json['username'],
        json['handle'],
        profile['username'],
      ),
      name: _firstText(
        json['name'],
        json['full_name'],
        json['display_name'],
        profile['display_name'],
        json['username'],
      ),
      imageUrl: _firstText(
        json['image'],
        json['image_url'],
        json['avatar_url'],
        profile['avatar_url'],
      ),
      isOnline: _asBool(
        json['is_online'] ?? json['online'] ?? profile['is_online'],
      ),
      isVerifiedBadge: VerifiedBadgeCache.resolve(
        _firstText(json['username'], json['handle'], profile['username']),
        parseVerifiedFlag(json) || parseVerifiedFlag(profile),
      ),
    );
  }
}

class ChatThreadModel {
  const ChatThreadModel({
    required this.conversationId,
    required this.user,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastMessageTimeLabel,
    required this.isStopped,
    required this.unreadCount,
    required this.isBlockedByMe,
    required this.isBlockedByOther,
    this.isPendingRequest = false,
    this.isIncomingRequest = false,
  });

  final int conversationId;
  final ChatUserModel user;
  final String lastMessage;
  final String lastMessageTime;
  final String lastMessageTimeLabel;
  final bool isStopped;
  final int unreadCount;
  final bool isBlockedByMe;
  final bool isBlockedByOther;
  final bool isPendingRequest;
  final bool isIncomingRequest;

  bool get isMessagingStopped => isStopped;
  bool get hasUnread => unreadCount > 0;
  bool get isBlocked => isBlockedByMe || isBlockedByOther;

  ChatThreadModel copyWith({int? unreadCount}) {
    return ChatThreadModel(
      conversationId: conversationId,
      user: user,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      lastMessageTimeLabel: lastMessageTimeLabel,
      isStopped: isStopped,
      unreadCount: unreadCount ?? this.unreadCount,
      isBlockedByMe: isBlockedByMe,
      isBlockedByOther: isBlockedByOther,
      isPendingRequest: isPendingRequest,
      isIncomingRequest: isIncomingRequest,
    );
  }

  factory ChatThreadModel.fromJson(Map<String, dynamic> json) {
    final user = _resolveUser(json);
    final time = _firstText(
      json['last_message_time'],
      json['last_time'],
      json['updated_at'],
      json['created_at'],
    );

    return ChatThreadModel(
      conversationId: _asInt(
        json['conversation_id'] ?? json['id'] ?? json['chat_id'],
      ),
      user: user,
      lastMessage: _firstText(
        json['last_message'],
        json['preview'],
        json['message'],
      ),
      lastMessageTime: time,
      lastMessageTimeLabel: _threadTimeLabel(time),
      isStopped: _asBool(
        json['is_messaging_stopped'] ??
            json['is_stopped'] ??
            json['messaging_stopped'] ??
            json['stopped'],
      ),
      unreadCount: _asInt(json['unread_count'] ?? json['unread']),
      isBlockedByMe: _asBool(json['is_blocked_by_me']),
      isBlockedByOther: _asBool(json['is_blocked_by_other']),
      isPendingRequest: _isPendingChatRequest(json),
      isIncomingRequest: _isIncomingChatRequest(json),
    );
  }

  static ChatUserModel _resolveUser(Map<String, dynamic> json) {
    final userMap =
        (json['user'] as Map<String, dynamic>?) ??
        (json['other_user'] as Map<String, dynamic>?) ??
        (json['participant'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    return ChatUserModel.fromJson(userMap);
  }
}

class ChatListResponseModel {
  const ChatListResponseModel({
    required this.statusCode,
    required this.message,
    required this.chats,
    required this.pagination,
    required this.totalUnreadCount,
  });

  final int statusCode;
  final String message;
  final List<ChatThreadModel> chats;
  final ChatPaginationModel pagination;
  final int totalUnreadCount;

  factory ChatListResponseModel.fromJson(Map<String, dynamic> json) {
    final chats = (json['chats'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ChatThreadModel.fromJson)
        .toList(growable: false);

    return ChatListResponseModel(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      chats: chats,
      pagination: ChatPaginationModel.fromJson(
        (json['pagination'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      totalUnreadCount: _asInt(json['total_unread_count']),
    );
  }
}

class ChatInitializeResponseModel {
  const ChatInitializeResponseModel({
    required this.statusCode,
    required this.message,
    required this.conversationId,
    required this.username,
    required this.isMessagingStopped,
    required this.isBlockedByMe,
    required this.isBlockedByOther,
    this.isPendingRequest = false,
    this.isIncomingRequest = false,
    this.isAccepted = false,
  });

  final int statusCode;
  final String message;
  final int conversationId;
  final String username;
  final bool isMessagingStopped;
  final bool isBlockedByMe;
  final bool isBlockedByOther;
  final bool isPendingRequest;
  final bool isIncomingRequest;
  final bool isAccepted;

  bool get isBlocked => isBlockedByMe || isBlockedByOther;

  factory ChatInitializeResponseModel.fromJson(Map<String, dynamic> json) {
    final chat =
        (json['chat'] as Map<String, dynamic>?) ??
        (json['conversation'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final user =
        (json['user'] as Map<String, dynamic>?) ??
        (chat['user'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    return ChatInitializeResponseModel(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      conversationId: _asInt(
        json['conversation_id'] ??
            chat['conversation_id'] ??
            chat['id'] ??
            json['id'],
      ),
      username: _firstText(
        json['username'],
        user['username'],
        chat['username'],
      ),
      isMessagingStopped: _asBool(
        json['is_messaging_stopped'] ??
            json['is_stopped'] ??
            json['messaging_stopped'] ??
            chat['is_messaging_stopped'] ??
            chat['is_stopped'] ??
            chat['messaging_stopped'],
      ),
      isBlockedByMe: _asBool(
        json['is_blocked_by_me'] ?? chat['is_blocked_by_me'],
      ),
      isBlockedByOther: _asBool(
        json['is_blocked_by_other'] ?? chat['is_blocked_by_other'],
      ),
      isPendingRequest: _isPendingChatRequest(json, chat),
      isIncomingRequest: _isIncomingChatRequest(json, chat),
      isAccepted: _isAcceptedChatRequest(json, chat),
    );
  }
}

class ChatMessageReactionGroup {
  const ChatMessageReactionGroup({
    required this.emoji,
    required this.count,
    this.userIds = const <int>[],
  });

  final String emoji;
  final int count;
  final List<int> userIds;

  factory ChatMessageReactionGroup.fromJson(Map<String, dynamic> json) {
    final rawIds = json['user_ids'];
    return ChatMessageReactionGroup(
      emoji: (json['emoji'] ?? '').toString(),
      count: _asInt(json['count']),
      userIds: rawIds is List
          ? [
              for (final id in rawIds) _asInt(id),
            ]
          : const <int>[],
    );
  }
}

class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.body,
    required this.senderUsername,
    required this.isMine,
    required this.createdAt,
    required this.timeLabel,
    required this.status,
    required this.isSeen,
    this.myReaction = '',
    this.reactions = const <ChatMessageReactionGroup>[],
  });

  final int id;
  final String body;
  final String senderUsername;
  final bool isMine;
  final String createdAt;
  final String timeLabel;
  final String status;
  final bool isSeen;
  final String myReaction;
  final List<ChatMessageReactionGroup> reactions;

  ChatMessageModel copyWith({
    String? status,
    bool? isSeen,
    bool? isMine,
    String? myReaction,
    List<ChatMessageReactionGroup>? reactions,
  }) {
    return ChatMessageModel(
      id: id,
      body: body,
      senderUsername: senderUsername,
      isMine: isMine ?? this.isMine,
      createdAt: createdAt,
      timeLabel: timeLabel,
      status: status ?? this.status,
      isSeen: isSeen ?? this.isSeen,
      myReaction: myReaction ?? this.myReaction,
      reactions: reactions ?? this.reactions,
    );
  }

  factory ChatMessageModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUsername,
  }) {
    final sender =
        (json['sender'] as Map<String, dynamic>?) ??
        (json['user'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final senderUsername = _firstText(
      sender['username'],
      json['sender_username'],
      json['username'],
    );
    final createdAt = _firstText(
      json['created_at'],
      json['sent_at'],
      json['time'],
    );
    final rawReactions = json['reactions'];

    return ChatMessageModel(
      id: _asInt(json['id']),
      body: _firstText(json['body'], json['message']),
      senderUsername: senderUsername,
      isMine: _asBool(
        json['is_mine'] ??
            (senderUsername.trim().toLowerCase() ==
                currentUsername.trim().toLowerCase()),
      ),
      createdAt: createdAt,
      timeLabel: _messageTimeLabel(createdAt),
      status: _firstText(json['status'], json['delivery_status']),
      isSeen: _asBool(json['is_seen'] ?? json['seen']),
      myReaction: (json['my_reaction'] ?? '').toString(),
      reactions: rawReactions is List
          ? [
              for (final item in rawReactions.whereType<Map>())
                ChatMessageReactionGroup.fromJson(
                  item.map((key, value) => MapEntry(key.toString(), value)),
                ),
            ]
          : const <ChatMessageReactionGroup>[],
    );
  }
}

class ChatMessagesResponseModel {
  const ChatMessagesResponseModel({
    required this.statusCode,
    required this.message,
    required this.conversationId,
    required this.user,
    required this.messages,
    required this.pagination,
    required this.isStopped,
    required this.isBlockedByMe,
    required this.isBlockedByOther,
    this.isPendingRequest = false,
    this.isIncomingRequest = false,
    this.isAccepted = false,
  });

  final int statusCode;
  final String message;
  final int conversationId;
  final ChatUserModel user;
  final List<ChatMessageModel> messages;
  final ChatPaginationModel pagination;
  final bool isStopped;
  final bool isBlockedByMe;
  final bool isBlockedByOther;
  final bool isPendingRequest;
  final bool isIncomingRequest;
  final bool isAccepted;

  bool get isMessagingStopped => isStopped;
  bool get isBlocked => isBlockedByMe || isBlockedByOther;

  factory ChatMessagesResponseModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUsername,
  }) {
    final conversation =
        (json['conversation'] as Map<String, dynamic>?) ??
        (json['chat'] as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final user =
        (json['user'] as Map<String, dynamic>?) ??
        (conversation['user'] as Map<String, dynamic>?) ??
        (conversation['other_user'] as Map<String, dynamic>?) ??
        <String, dynamic>{};

    // The backend returns each page in ascending (oldest-first)
    // chronological order, but the whole chat UI assumes messages[0] is the
    // newest (reversed ListView, insert(0, ...) on send, etc.) — reverse
    // here once so every consumer can rely on that invariant.
    final messages = (json['messages'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(
          (item) =>
              ChatMessageModel.fromJson(item, currentUsername: currentUsername),
        )
        .toList(growable: false)
        .reversed
        .toList(growable: false);

    return ChatMessagesResponseModel(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      conversationId: _asInt(
        json['conversation_id'] ??
            conversation['conversation_id'] ??
            conversation['id'],
      ),
      user: ChatUserModel.fromJson(user),
      messages: messages,
      pagination: ChatPaginationModel.fromJson(
        (json['pagination'] as Map<String, dynamic>?) ?? <String, dynamic>{},
      ),
      isStopped: _asBool(
        json['is_messaging_stopped'] ??
            json['is_stopped'] ??
            json['messaging_stopped'] ??
            conversation['is_stopped'] ??
            conversation['messaging_stopped'] ??
            conversation['is_messaging_stopped'],
      ),
      isBlockedByMe: _asBool(
        json['is_blocked_by_me'] ?? conversation['is_blocked_by_me'],
      ),
      isBlockedByOther: _asBool(
        json['is_blocked_by_other'] ?? conversation['is_blocked_by_other'],
      ),
      isPendingRequest: _isPendingChatRequest(json, conversation),
      isIncomingRequest: _isIncomingChatRequest(json, conversation),
      isAccepted: _isAcceptedChatRequest(json, conversation),
    );
  }
}

class ChatSyncResponseModel {
  const ChatSyncResponseModel({
    required this.statusCode,
    required this.message,
    required this.messages,
  });

  final int statusCode;
  final String message;
  final List<ChatMessageModel> messages;

  factory ChatSyncResponseModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUsername,
  }) {
    final rawMessages =
        (json['messages'] as List<dynamic>?) ??
        (json['data'] as List<dynamic>?) ??
        (json['items'] as List<dynamic>?) ??
        const <dynamic>[];

    return ChatSyncResponseModel(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      messages: rawMessages
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => ChatMessageModel.fromJson(
              item,
              currentUsername: currentUsername,
            ),
          )
          .toList(growable: false),
    );
  }
}

class ChatSendMessageResponseModel {
  const ChatSendMessageResponseModel({
    required this.statusCode,
    required this.message,
    required this.chatMessage,
    required this.isMessagingStopped,
  });

  final int statusCode;
  final String message;
  final ChatMessageModel? chatMessage;
  final bool isMessagingStopped;

  factory ChatSendMessageResponseModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUsername,
  }) {
    final message =
        (json['message_data'] as Map<String, dynamic>?) ??
        (json['chat_message'] as Map<String, dynamic>?) ??
        (json['data'] as Map<String, dynamic>?);

    return ChatSendMessageResponseModel(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      chatMessage: message == null
          ? null
          : ChatMessageModel.fromJson(
              message,
              currentUsername: currentUsername,
            ),
      isMessagingStopped: _asBool(
        json['is_messaging_stopped'] ??
            json['is_stopped'] ??
            json['messaging_stopped'] ??
            (json['chat'] as Map<String, dynamic>?)?['is_messaging_stopped'] ??
            (json['chat'] as Map<String, dynamic>?)?['is_stopped'] ??
            (json['chat'] as Map<String, dynamic>?)?['messaging_stopped'],
      ),
    );
  }
}

class ChatMessagingToggleResponseModel {
  const ChatMessagingToggleResponseModel({
    required this.statusCode,
    required this.message,
    required this.isMessagingStopped,
  });

  final int statusCode;
  final String message;
  final bool isMessagingStopped;

  factory ChatMessagingToggleResponseModel.fromJson(Map<String, dynamic> json) {
    final chat = (json['chat'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return ChatMessagingToggleResponseModel(
      statusCode: _asInt(json['status_code']),
      message: (json['message'] ?? '').toString(),
      isMessagingStopped: _asBool(
        json['is_messaging_stopped'] ??
            json['is_stopped'] ??
            json['messaging_stopped'] ??
            chat['is_messaging_stopped'] ??
            chat['is_stopped'] ??
            chat['messaging_stopped'],
      ),
    );
  }
}

class ChatApiException implements Exception {
  const ChatApiException({
    required this.message,
    this.statusCode,
    this.httpStatusCode,
    this.isBlockedByMe = false,
    this.isBlockedByOther = false,
  });

  final String message;
  final int? statusCode;
  final int? httpStatusCode;

  /// Only meaningful on a 403 from `chats/initialize` /
  /// `chats/{id}/messages` — whether the current user has blocked the
  /// other party.
  final bool isBlockedByMe;

  /// Only meaningful on a 403 from `chats/initialize` /
  /// `chats/{id}/messages` — whether the other party has blocked the
  /// current user.
  final bool isBlockedByOther;

  @override
  String toString() => message;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String _requestStatus(Map<String, dynamic> json, [Map<String, dynamic>? nested]) {
  return _firstText(
    json['request_status'],
    json['chat_request_status'],
    nested?['request_status'],
    nested?['chat_request_status'],
  ).trim().toLowerCase();
}

bool _isAcceptedChatRequest(
  Map<String, dynamic> json, [
  Map<String, dynamic>? nested,
]) {
  final status = _requestStatus(json, nested);
  if (status == 'accepted') {
    return true;
  }
  return _asBool(
    json['is_accepted'] ??
        json['chat_accepted'] ??
        nested?['is_accepted'] ??
        nested?['chat_accepted'],
  );
}

bool _isPendingChatRequest(
  Map<String, dynamic> json, [
  Map<String, dynamic>? nested,
]) {
  if (_isAcceptedChatRequest(json, nested)) {
    return false;
  }
  final status = _requestStatus(json, nested);
  if (status == 'pending' || status == 'requested') {
    return true;
  }
  return _asBool(
    json['is_pending_request'] ??
        json['is_chat_request'] ??
        json['is_request'] ??
        json['is_message_request'] ??
        nested?['is_pending_request'] ??
        nested?['is_chat_request'] ??
        nested?['is_request'] ??
        nested?['is_message_request'],
  );
}

bool _isIncomingChatRequest(
  Map<String, dynamic> json, [
  Map<String, dynamic>? nested,
]) {
  if (_asBool(
    json['is_incoming_request'] ??
        json['is_request_recipient'] ??
        nested?['is_incoming_request'] ??
        nested?['is_request_recipient'],
  )) {
    return true;
  }
  if (!_isPendingChatRequest(json, nested)) {
    return false;
  }
  final initiatedByMe = json['initiated_by_me'] ??
      json['is_requester'] ??
      nested?['initiated_by_me'] ??
      nested?['is_requester'];
  if (initiatedByMe == null) {
    return false;
  }
  return !_asBool(initiatedByMe);
}

String _firstText(
  dynamic first, [
  dynamic second,
  dynamic third,
  dynamic fourth,
  dynamic fifth,
]) {
  final values = <dynamic>[first, second, third, fourth, fifth];
  for (final value in values) {
    final resolved = value?.toString().trim();
    if (resolved != null && resolved.isNotEmpty && resolved != 'null') {
      return resolved;
    }
  }
  return '';
}

String _threadTimeLabel(String raw) {
  final parsed = AppTimeFormatter.parse(raw);
  if (parsed == null) {
    return '';
  }

  final now = DateTime.now();
  final difference = now.difference(parsed);
  if (difference.inMinutes < 1) {
    return 'Now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d';
  }
  return AppTimeFormatter.formatCompactDate(raw);
}

String _messageTimeLabel(String raw) {
  final parsed = AppTimeFormatter.parse(raw);
  if (parsed == null) {
    return 'Now';
  }

  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}
