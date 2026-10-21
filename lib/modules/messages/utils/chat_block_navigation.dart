import 'package:flutter/foundation.dart' show immutable;

import '../models/chat_models.dart' show ChatApiException;

/// Where to route after `initializeChat` 403s because the two users have
/// blocked each other, in place of a generic error toast.
@immutable
class BlockedChatNavigation {
  const BlockedChatNavigation({
    required this.username,
    required this.conversationId,
    required this.isBlockedByMe,
    required this.isBlockedByOther,
  });

  final String username;

  /// 0 when no conversation exists yet — `initializeChat` itself is what
  /// 403'd, so there's nothing to look one up from. 0 is the existing
  /// "no conversation" sentinel used elsewhere (e.g.
  /// `ChatSocketService.subscribeToConversation`), and is safe to open
  /// `ChatDetailScreen` with since the composer stays disabled while
  /// blocked.
  final int conversationId;
  final bool isBlockedByMe;
  final bool isBlockedByOther;
}

/// Decides whether a [ChatApiException] thrown by `initializeChat`
/// represents a block that should route to the block-banner
/// `ChatDetailScreen` instead of a generic error toast. Returns null for
/// any other failure (wrong password, network error, non-block 403, etc.).
BlockedChatNavigation? resolveBlockedChatNavigation(
  ChatApiException error, {
  required String username,
  int knownConversationId = 0,
}) {
  if (error.httpStatusCode != 403) {
    return null;
  }
  if (!error.isBlockedByMe && !error.isBlockedByOther) {
    return null;
  }

  return BlockedChatNavigation(
    username: username,
    conversationId: knownConversationId,
    isBlockedByMe: error.isBlockedByMe,
    isBlockedByOther: error.isBlockedByOther,
  );
}
