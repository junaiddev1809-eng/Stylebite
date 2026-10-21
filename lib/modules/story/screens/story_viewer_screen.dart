import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_cached_video_player.dart';
import '../../messages/models/chat_models.dart';
import '../../messages/services/chat_api_service.dart';
import '../../profile/screen/user_profile_cover_screen.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../controllers/story_controller.dart';
import '../models/story_model.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.bucket,
    this.startIndex = 0,
  });

  final StoryBucket bucket;
  final int startIndex;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  static const _imageHold = Duration(seconds: 5);
  static const _reactions = ['❤️', '🔥', '😍', '😂', '😮', '👏'];

  late int _index;
  Timer? _timer;
  var _progress = 0.0;
  var _elapsedMs = 0;
  var _holdPaused = false;
  var _inputPaused = false;
  var _sending = false;
  var _advancing = false;
  String? _burst;
  int? _conversationId;

  final _replyController = TextEditingController();
  final _replyFocus = FocusNode();

  List<StoryItem> get _items => widget.bucket.items;
  StoryItem get _current => _items[_index];
  bool get _paused => _holdPaused || _inputPaused;
  bool get _canReply => !widget.bucket.isMine;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, _items.length - 1);
    _replyFocus.addListener(_onReplyFocus);
    _startHold();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _replyFocus.removeListener(_onReplyFocus);
    _replyFocus.dispose();
    _replyController.dispose();
    super.dispose();
  }

  void _onReplyFocus() {
    if (_replyFocus.hasFocus) {
      _setInputPaused(true);
    } else {
      _setInputPaused(false);
    }
  }

  void _setInputPaused(bool value) {
    if (_inputPaused == value) {
      return;
    }
    _inputPaused = value;
    if (value) {
      _timer?.cancel();
      if (mounted) setState(() {});
      return;
    }
    if (!_holdPaused) {
      _resumeImageTimer();
    }
    if (mounted) setState(() {});
  }

  void _startHold() {
    _timer?.cancel();
    _progress = 0;
    _elapsedMs = 0;
    _holdPaused = false;
    _advancing = false;
    _conversationId = null;
    unawaited(StoryController.ensure().markSeen(_current.id));
    if (_current.isVideo || _paused) {
      return;
    }
    _resumeImageTimer();
  }

  void _resumeImageTimer() {
    if (_current.isVideo || _paused) {
      return;
    }
    _timer?.cancel();
    const ticks = 50;
    final slice = _imageHold.inMilliseconds ~/ ticks;
    _timer = Timer.periodic(Duration(milliseconds: slice), (timer) {
      if (!mounted || _paused) {
        timer.cancel();
        return;
      }
      _elapsedMs += slice;
      final next = (_elapsedMs / _imageHold.inMilliseconds).clamp(0.0, 1.0);
      setState(() => _progress = next);
      if (_elapsedMs >= _imageHold.inMilliseconds) {
        timer.cancel();
        _next();
      }
    });
  }

  void _pauseHold() {
    if (_holdPaused) {
      return;
    }
    _timer?.cancel();
    setState(() => _holdPaused = true);
  }

  void _resumeHold() {
    if (!_holdPaused) {
      return;
    }
    setState(() => _holdPaused = false);
    if (!_inputPaused && !_current.isVideo) {
      _resumeImageTimer();
    }
  }

  void _next() {
    if (_paused || _advancing) {
      return;
    }
    _advancing = true;
    if (_index >= _items.length - 1) {
      Get.back<void>();
      return;
    }
    _replyController.clear();
    _replyFocus.unfocus();
    setState(() => _index += 1);
    _startHold();
  }

  void _previous() {
    if (_paused || _advancing) {
      return;
    }
    _advancing = true;
    if (_index <= 0) {
      Get.back<void>();
      return;
    }
    _replyController.clear();
    _replyFocus.unfocus();
    setState(() => _index -= 1);
    _startHold();
  }

  bool _isLocalFile(StoryItem item) {
    return item.mediaPath.isNotEmpty && File(item.mediaPath).existsSync();
  }

  String _mediaUrl(StoryItem item) {
    if (_isLocalFile(item)) {
      return item.mediaPath;
    }
    return item.mediaUrl.trim().isNotEmpty ? item.mediaUrl : item.mediaPath;
  }

  Future<void> _openAuthor() async {
    final name = widget.bucket.username.trim().replaceFirst('@', '');
    if (name.isEmpty) {
      return;
    }
    _pauseHold();
    if (widget.bucket.isMine || ProfileOpenHelper.isSelf(name)) {
      _timer?.cancel();
      await ProfileOpenHelper.open(
        username: name,
        avatarUrl: widget.bucket.avatarUrl,
      );
      return;
    }
    await Get.to<void>(
      () => UserProfileCoverScreen(
        username: name,
        initialAvatarUrl: widget.bucket.avatarUrl,
      ),
    );
    if (mounted) {
      _resumeHold();
    }
  }

  Future<void> _send(String body, {String? burst}) async {
    final text = body.trim();
    final username = _current.username.trim().replaceFirst('@', '');
    if (text.isEmpty || username.isEmpty || _sending || widget.bucket.isMine) {
      return;
    }
    setState(() => _sending = true);
    _setInputPaused(true);
    try {
      final conversationId = await _ensureConversation(username);
      if (conversationId == null) {
        return;
      }
      await const ChatApiService().sendMessage(conversationId, text);
      if (!mounted) {
        return;
      }
      _replyController.clear();
      _replyFocus.unfocus();
      setState(() => _burst = burst ?? 'Sent');
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) {
        setState(() => _burst = null);
      }
    } on ChatApiException catch (error) {
      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Unable to send that right now.');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        if (!_replyFocus.hasFocus) {
          _setInputPaused(false);
        }
      }
    }
  }

  Future<int?> _ensureConversation(String username) async {
    final cached = _conversationId;
    if (cached != null && cached > 0) {
      return cached;
    }
    final chat = await const ChatApiService().initializeChat(username);
    if (chat.isBlocked || chat.isMessagingStopped || chat.conversationId <= 0) {
      errorSnackBar(message: 'You cannot message this account.');
      return null;
    }
    _conversationId = chat.conversationId;
    return chat.conversationId;
  }

  String _storyNote(String text) {
    final caption = _current.caption.trim();
    final quote = caption.isEmpty
        ? ''
        : ' “${caption.length > 40 ? '${caption.substring(0, 40)}…' : caption}”';
    if (_reactions.contains(text)) {
      return 'Reacted $text to your story$quote';
    }
    return 'Replied to your story$quote: $text';
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (item.isVideo)
            AppCachedVideoPlayer(
              key: ValueKey(item.id),
              videoUrl: _mediaUrl(item),
              autoPlay: true,
              looping: false,
              isActive: !_paused,
              isMuted: false,
              showControls: false,
              showLoadingIndicator: false,
              onProgressChanged: (value) {
                if (_paused) {
                  return;
                }
                setState(() => _progress = value);
                if (value >= 0.98) {
                  _next();
                }
              },
            )
          else if (_isLocalFile(item))
            Image.file(File(item.mediaPath), fit: BoxFit.cover)
          else
            AppCachedImage(
              imageUrl: _mediaUrl(item),
              fit: BoxFit.cover,
            ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapUp: (details) {
                if (_replyFocus.hasFocus) {
                  _replyFocus.unfocus();
                  return;
                }
                final width = MediaQuery.sizeOf(context).width;
                if (details.localPosition.dx < width * 0.3) {
                  _previous();
                } else {
                  _next();
                }
              },
              onLongPressStart: (_) => _pauseHold(),
              onLongPressEnd: (_) => _resumeHold(),
              onLongPressCancel: _resumeHold,
            ),
          ),
          if (_holdPaused)
            const IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.pause_rounded,
                  color: Colors.white70,
                  size: 64,
                ),
              ),
            ),
          if (_burst != null)
            IgnorePointer(
              child: Center(
                child: Text(
                  _burst!,
                  style: TextStyle(
                    fontSize: _burst == 'Sent' ? 28 : 72,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < _items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              minHeight: 2.5,
                              value: i < _index
                                  ? 1
                                  : i == _index
                                  ? _progress
                                  : 0,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.bucket.kind == StoryKind.food
                                    ? const Color(0xFF7DFFB2)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openAuthor,
                          child: Row(
                            children: [
                              _StoryRingAvatar(imageUrl: item.avatarUrl),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.bucket.isMine
                                          ? 'Your story'
                                          : '@${item.username}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.plusJakarta(
                                        size: 14,
                                        weight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      widget.bucket.kind == StoryKind.food
                                          ? 'Bite'
                                          : 'Style',
                                      style: AppFonts.beVietnam(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: widget.bucket.kind == StoryKind.food
                                            ? const Color(0xFF7DFFB2)
                                            : const Color(0xFFFFB4C4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: Get.back,
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (item.caption.trim().isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          item.caption,
                          style: AppFonts.beVietnam(
                            size: 15,
                            weight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  if (_canReply) _replyBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _replyBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final emoji in _reactions)
              GestureDetector(
                onTap: _sending ? null : () => _send(_storyNote(emoji), burst: emoji),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _replyController,
                focusNode: _replyFocus,
                style: AppFonts.beVietnam(size: 14, color: Colors.white),
                cursorColor: Colors.white,
                textInputAction: TextInputAction.send,
                onSubmitted: (value) => _send(_storyNote(value)),
                decoration: InputDecoration(
                  hintText: 'Send message',
                  hintStyle: AppFonts.beVietnam(
                    size: 14,
                    color: Colors.white70,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: AppColors.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending
                    ? null
                    : () => _send(_storyNote(_replyController.text)),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StoryRingAvatar extends StatelessWidget {
  const _StoryRingAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color(0xFFFF8A5B),
            AppColors.accent,
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(1.4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black,
        ),
        child: ClipOval(
          child: imageUrl.trim().isNotEmpty
              ? AppCachedImage(
                  imageUrl: imageUrl,
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                  memCacheWidth: 96,
                )
              : const ColoredBox(
                  color: Colors.white24,
                  child: SizedBox(width: 28, height: 28),
                ),
        ),
      ),
    );
  }
}
