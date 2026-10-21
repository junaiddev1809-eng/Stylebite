import 'dart:convert';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../models/chat_models.dart';

class ChatApiService {
  const ChatApiService();

  Future<ChatListResponseModel> getChats({
    String? search,
    int? page,
    int? offset,
    int? skip,
  }) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      _buildEndpoint(
        'chats',
        queryParameters: <String, dynamic>{
          'search': search,
          'page': page,
          'offset': offset,
          'skip': skip,
        },
      ),
    );

    final payload = _decodeResponse(response);
    return ChatListResponseModel.fromJson(payload);
  }

  Future<ChatInitializeResponseModel> initializeChat(String username) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'chats/initialize',
      body: <String, dynamic>{'username': username},
    );

    final payload = _decodeResponse(response);
    return ChatInitializeResponseModel.fromJson(payload);
  }

  Future<ChatMessagesResponseModel> getMessages(
    String username, {
    int? page,
    int? offset,
    int? skip,
  }) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      _buildEndpoint(
        'chats/$username/messages',
        queryParameters: <String, dynamic>{
          'page': page,
          'offset': offset,
          'skip': skip,
        },
      ),
    );

    final payload = _decodeResponse(response);
    return ChatMessagesResponseModel.fromJson(
      payload,
      currentUsername: LocalStorage.getUsername() ?? '',
    );
  }

  Future<ChatSendMessageResponseModel> sendMessage(
    int conversationId,
    String body,
  ) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'chats/$conversationId/messages',
      body: <String, dynamic>{'body': body},
    );

    final payload = _decodeResponse(response);
    return ChatSendMessageResponseModel.fromJson(
      payload,
      currentUsername: LocalStorage.getUsername() ?? '',
    );
  }

  Future<void> markRead(int conversationId, {int? upToMessageId}) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'chats/$conversationId/read',
      body: upToMessageId == null
          ? null
          : <String, dynamic>{'up_to_message_id': upToMessageId},
    );
    _decodeResponse(response);
  }

  Future<ChatSyncResponseModel> syncMessages(
    int conversationId, {
    required int afterMessageId,
  }) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      _buildEndpoint(
        'chats/$conversationId/sync',
        queryParameters: <String, dynamic>{'after_message_id': afterMessageId},
      ),
    );

    final payload = _decodeResponse(response);
    return ChatSyncResponseModel.fromJson(
      payload,
      currentUsername: LocalStorage.getUsername() ?? '',
    );
  }

  Future<ChatMessagingToggleResponseModel> stopMessaging(
    int conversationId,
  ) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'chats/$conversationId/stop',
    );

    final payload = _decodeResponse(response);
    return ChatMessagingToggleResponseModel.fromJson(payload);
  }

  Future<ChatMessagingToggleResponseModel> resumeMessaging(
    int conversationId,
  ) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'chats/$conversationId/resume',
    );

    final payload = _decodeResponse(response);
    return ChatMessagingToggleResponseModel.fromJson(payload);
  }

  Future<void> acceptChatRequest(int conversationId) async {
    await _postFirstSuccess(
      <String>[
        'chats/$conversationId/accept',
        'chats/$conversationId/requests/accept',
      ],
      fallback: 'Unable to accept this chat request.',
    );
  }

  Future<void> rejectChatRequest(int conversationId) async {
    await _postFirstSuccess(
      <String>[
        'chats/$conversationId/reject',
        'chats/$conversationId/requests/reject',
      ],
      fallback: 'Unable to reject this chat request.',
    );
  }

  Future<ChatApiMessage> updatePresence(bool isOnline) async {
    final response = await ApiHelper.patchRequestWithAuthorization(
      'profile/me/presence',
      body: <String, dynamic>{'is_online': isOnline},
    );

    final payload = _decodeResponse(response);
    return ChatApiMessage.fromJson(payload);
  }

  Future<void> blockUser(String username) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'profiles/${Uri.encodeComponent(username.trim().replaceFirst('@', ''))}/block',
    );
    _decodeResponse(response);
  }

  /// Same endpoint as [blockUser] — it toggles the block relationship
  /// (confirmed by BlockedUsersController reusing it to unblock).
  Future<void> unblockUser(String username) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'profiles/${Uri.encodeComponent(username.trim().replaceFirst('@', ''))}/block',
    );
    _decodeResponse(response);
  }

  String _buildEndpoint(String path, {Map<String, dynamic>? queryParameters}) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return path;
    }

    final filtered = <String, String>{};
    queryParameters.forEach((key, value) {
      final resolved = value?.toString().trim();
      if (resolved == null || resolved.isEmpty || resolved == 'null') {
        return;
      }
      filtered[key] = resolved;
    });

    if (filtered.isEmpty) {
      return path;
    }

    return '$path?${Uri(queryParameters: filtered).query}';
  }

  Map<String, dynamic> _decodeResponse(dynamic response) {
    if (response == null) {
      throw const ChatApiException(message: 'No response from server.');
    }

    final body = response.body?.toString() ?? '';
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      throw ChatApiException(
        message: 'Invalid server response.',
        httpStatusCode: response.statusCode as int?,
      );
    }

    final statusCode = _readInt(payload['status_code']);
    final httpStatus = response.statusCode as int? ?? 0;
    final message = (payload['message'] ?? 'Request failed').toString();
    if (httpStatus < 200 || httpStatus >= 300 || statusCode != 1) {
      throw ChatApiException(
        message: message,
        statusCode: statusCode,
        httpStatusCode: httpStatus,
        isBlockedByMe: _asBoolValue(payload['is_blocked_by_me'] ?? false),
        isBlockedByOther: _asBoolValue(
          payload['is_blocked_by_other'] ?? false,
        ),
      );
    }

    return payload;
  }

  Future<void> _postFirstSuccess(
    List<String> endpoints, {
    required String fallback,
  }) async {
    ChatApiException? lastError;
    for (final endpoint in endpoints) {
      final response = await ApiHelper.postRequestWithAuthorization(endpoint);
      if (response == null) {
        lastError = ChatApiException(message: fallback);
        continue;
      }
      try {
        _decodeResponse(response);
        return;
      } on ChatApiException catch (error) {
        lastError = error;
        if (error.httpStatusCode != 404) {
          rethrow;
        }
      }
    }
    throw lastError ?? ChatApiException(message: fallback);
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  bool _asBoolValue(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}
