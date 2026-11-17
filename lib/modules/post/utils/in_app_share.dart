import 'dart:convert';

import '../../home/models/home_post_model.dart';
import '../../messages/models/chat_models.dart';
import '../../messages/services/chat_api_service.dart';
import '../../reel/models/reel_item_model.dart';
import '../../reel/utils/reel_open_helper.dart';
import '../../story/models/story_model.dart';

/// A post, reel, or story reply sent through StyleBite chat.
class InAppSharePayload {
  const InAppSharePayload({
    required this.kind,
    required this.id,
    required this.caption,
    required this.previewUrl,
    required this.authorName,
    required this.username,
    this.reply = '',
    this.isVideo = false,
  });

  static const _prefix = 'sbshare:v1:';

  final String kind;
  final String id;
  final String caption;
  final String previewUrl;
  final String authorName;
  final String username;
  /// Story reply / reaction text (empty for plain post/reel shares).
  final String reply;
  final bool isVideo;

  bool get isReel => kind == 'reel';

  bool get isStory => kind == 'story';

  bool get isStoryReaction {
    if (!isStory || reply.trim().isEmpty) {
      return false;
    }
    // Single emoji / short reaction cluster — matches story viewer reactions.
    final text = reply.trim();
    return text.runes.length <= 4 &&
        !RegExp(r'[A-Za-z0-9]').hasMatch(text);
  }

  String get listLabel {
    if (isStory) {
      if (isStoryReaction) {
        return 'Reacted to your story';
      }
      if (reply.trim().isNotEmpty) {
        return 'Replied to your story';
      }
      return 'Story';
    }
    return isReel ? 'Shared a reel' : 'Shared a post';
  }

  factory InAppSharePayload.fromPost(HomePostModel post) {
    final username = post.profileUsername.trim().isNotEmpty
        ? post.profileUsername.trim()
        : post.username.trim();
    final isReel = ReelOpenHelper.isReel(post);
    final preview = _remotePreviewUrl(
      post.thumbnailUrl,
      post.imageUrl,
    );
    return InAppSharePayload(
      kind: isReel ? 'reel' : 'post',
      id: post.id,
      caption: _short(post.caption),
      previewUrl: preview,
      authorName: post.authorName.trim(),
      username: username.replaceFirst('@', ''),
      isVideo: isReel,
    );
  }

  factory InAppSharePayload.fromReel(ReelItemModel reel) {
    return InAppSharePayload(
      kind: 'reel',
      id: reel.id,
      caption: _short(reel.caption),
      previewUrl: _remotePreviewUrl(reel.imageUrl),
      authorName: reel.authorName.trim(),
      username: reel.handle.trim().replaceFirst('@', ''),
      isVideo: true,
    );
  }

  factory InAppSharePayload.fromStoryReply({
    required StoryItem story,
    required String reply,
  }) {
    // Never encode local mediaPath — recipients cannot load device paths.
    // Prefer poster/still over raw video URLs for the chat card.
    final preview = story.isVideo
        ? _remotePreviewUrl(story.posterUrl)
        : _remotePreviewUrl(story.posterUrl, story.mediaUrl);
    final id = story.remoteId.trim().isNotEmpty
        ? story.remoteId.trim()
        : story.id.replaceFirst(RegExp(r'^p'), '');
    return InAppSharePayload(
      kind: 'story',
      id: id,
      caption: _short(story.caption),
      previewUrl: preview,
      authorName: '',
      username: story.username.trim().replaceFirst('@', ''),
      reply: reply.trim(),
      isVideo: story.isVideo,
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
      if (reply.trim().isNotEmpty) 'reply': reply.trim(),
      if (isVideo) 'is_video': '1',
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
      final kindRaw = (decoded['kind'] ?? 'post').toString().trim().toLowerCase();
      final kind = switch (kindRaw) {
        'reel' => 'reel',
        'story' => 'story',
        _ => 'post',
      };
      return InAppSharePayload(
        kind: kind,
        id: id,
        caption: (decoded['caption'] ?? '').toString(),
        previewUrl: (decoded['preview'] ?? '').toString(),
        authorName: (decoded['author'] ?? '').toString(),
        username: (decoded['username'] ?? '').toString(),
        reply: (decoded['reply'] ?? '').toString(),
        isVideo: (decoded['is_video'] ?? '').toString() == '1' ||
            decoded['is_video'] == true,
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

  /// Absolute http(s) still only — skip local paths and raw video files.
  static String _remotePreviewUrl(String? a, [String? b, String? c]) {
    for (final raw in <String?>[a, b, c]) {
      final value = (raw ?? '').trim();
      if (value.isEmpty) {
        continue;
      }
      final lower = value.toLowerCase().split('?').first;
      final isVideo = lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.mkv') ||
          lower.endsWith('.m4v') ||
          lower.endsWith('.avi');
      if (isVideo) {
        continue;
      }
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        return value;
      }
    }
    return '';
  }
}
