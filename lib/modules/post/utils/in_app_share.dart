import 'dart:convert';

import '../../home/models/home_post_model.dart';
import '../../messages/models/chat_models.dart';
import '../../messages/services/chat_api_service.dart';
import '../../reel/models/reel_item_model.dart';
import '../../reel/utils/reel_open_helper.dart';

/// A post or reel sent through StyleBite chat.
class InAppSharePayload {
  const InAppSharePayload({
    required this.kind,
    required this.id,
    required this.caption,
    required this.previewUrl,
    required this.authorName,
    required this.username,
  });

  static const _prefix = 'sbshare:v1:';

  final String kind;
  final String id;
  final String caption;
  final String previewUrl;
  final String authorName;
  final String username;

  bool get isReel => kind == 'reel';

  String get listLabel => isReel ? 'Shared a reel' : 'Shared a post';

  factory InAppSharePayload.fromPost(HomePostModel post) {
    final username = post.profileUsername.trim().isNotEmpty
        ? post.profileUsername.trim()
        : post.username.trim();
    final preview = (post.thumbnailUrl ?? '').trim().isNotEmpty
        ? post.thumbnailUrl!.trim()
        : post.imageUrl.trim();
    return InAppSharePayload(
      kind: ReelOpenHelper.isReel(post) ? 'reel' : 'post',
      id: post.id,
      caption: _short(post.caption),
      previewUrl: preview,
      authorName: post.authorName.trim(),
      username: username.replaceFirst('@', ''),
    );
  }

  factory InAppSharePayload.fromReel(ReelItemModel reel) {
    return InAppSharePayload(
      kind: 'reel',
      id: reel.id,
      caption: _short(reel.caption),
      previewUrl: reel.imageUrl.trim(),
      authorName: reel.authorName.trim(),
      username: reel.handle.trim().replaceFirst('@', ''),
    );
  }

  String encode() {
    return '$_prefix${jsonEncode(<String, String>{
      'kind': kind,
      'id': id,
      'caption': caption,
      'preview': previewUrl,
      'author': authorName,
      'username': username,
    })}';
  }

  static InAppSharePayload? tryParse(String raw) {
    final text = raw.trim();
    if (!text.startsWith(_prefix)) {
      return null;
    }
    try {
      final decoded = jsonDecode(text.substring(_prefix.length));
      if (decoded is! Map) {
        return null;
      }
      final id = (decoded['id'] ?? '').toString().trim();
      if (id.isEmpty) {
        return null;
      }
      final kind = (decoded['kind'] ?? 'post').toString().trim();
      return InAppSharePayload(
        kind: kind == 'reel' ? 'reel' : 'post',
        id: id,
        caption: (decoded['caption'] ?? '').toString(),
        previewUrl: (decoded['preview'] ?? '').toString(),
        authorName: (decoded['author'] ?? '').toString(),
        username: (decoded['username'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }

  static String previewText(String raw) {
    return tryParse(raw)?.listLabel ?? raw;
  }

  static Future<void> sendToUsername({
    required String username,
    required InAppSharePayload payload,
  }) async {
    final handle = username.trim().replaceFirst(RegExp(r'^@+'), '');
    if (handle.isEmpty) {
      throw const ChatApiException(message: 'Choose someone to send this to.');
    }
    final chat = await const ChatApiService().initializeChat(handle);
    if (chat.conversationId <= 0) {
      throw const ChatApiException(message: 'Unable to open this chat.');
    }
    if (chat.isBlocked) {
      throw const ChatApiException(message: 'You cannot message this person.');
    }
    if (chat.isMessagingStopped) {
      throw const ChatApiException(message: 'Messaging is stopped in this chat.');
    }
    await const ChatApiService().sendMessage(chat.conversationId, payload.encode());
  }

  static String _short(String value) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= 140) {
      return cleaned;
    }
    return '${cleaned.substring(0, 137)}...';
  }
}
