import 'dart:async';

class ChatPushEvent {
  const ChatPushEvent({required this.type, required this.payload});

  final String type;
  final Map<String, dynamic> payload;

  bool get isMessageEvent =>
      type.toLowerCase() == 'message' || type.toLowerCase().contains('chat');
  bool get isCommentEvent => type.toLowerCase().contains('comment');
  bool get isLikeEvent {
    final normalized = type.toLowerCase();
    return normalized == 'like' ||
        normalized.contains('like') ||
        normalized.contains('react');
  }
}

class ChatEventBus {
  ChatEventBus._();

  static final ChatEventBus instance = ChatEventBus._();

  final StreamController<ChatPushEvent> _controller =
      StreamController<ChatPushEvent>.broadcast();

  Stream<ChatPushEvent> get stream => _controller.stream;

  void publish(ChatPushEvent event) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(event);
  }
}
