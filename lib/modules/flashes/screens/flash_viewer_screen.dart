import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../messages/models/chat_models.dart';
import '../../messages/services/chat_api_service.dart';
import '../../profile/screen/user_profile_cover_screen.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../controllers/flash_controller.dart';
import '../models/flash_model.dart';

class FlashViewerScreen extends StatefulWidget {
  const FlashViewerScreen({
    super.key,
    required this.bucket,
    this.startIndex = 0,
  });

  final FlashBucket bucket;
  final int startIndex;

  @override
  State<FlashViewerScreen> createState() => _FlashViewerScreenState();
}

class _FlashViewerScreenState extends State<FlashViewerScreen> {
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

  List<FlashItem> get _items => widget.bucket.items;
  FlashItem get _current => _items[_index];
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
    unawaited(FlashController.ensure().markSeen(_current.id));
    if (_paused) {
      return;
    }
    _resumeImageTimer();
  }

  void _resumeImageTimer() {
    if (_paused) {
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
    if (!_inputPaused) {
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

  bool _isLocalFile(FlashItem item) {
    return item.mediaPath.isNotEmpty && File(item.mediaPath).existsSync();
  }

  String _mediaUrl(FlashItem item) {
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

  String _replyNote(String text) {
    final caption = _current.caption.trim();
    final quote = caption.isEmpty
        ? ''
        : ' “${caption.length > 40 ? '${caption.substring(0, 40)}…' : caption}”';
    if (_reactions.contains(text)) {
      return 'Reacted $text to your ${flashSingularLabel(widget.bucket.kind).toLowerCase()}$quote';
    }
    return 'Replied to your ${flashSingularLabel(widget.bucket.kind).toLowerCase()}$quote: $text';
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    final mediaUrl = _mediaUrl(item);
    final isLocal = _isLocalFile(item);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (isLocal)
            Image.file(File(mediaUrl), fit: BoxFit.cover)
          else
            AppCachedImage(
              imageUrl: mediaUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < _items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: i < _index
                                  ? 1
                                  : i > _index
                                      ? 0
                                      : _progress,
                              minHeight: 2.5,
                              backgroundColor: Colors.white24,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: Get.back,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      GestureDetector(
                        onTap: _openAuthor,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFE9E3E1),
                              backgroundImage:
                                  widget.bucket.avatarUrl.trim().isNotEmpty
                                      ? NetworkImage(widget.bucket.avatarUrl)
                                      : null,
                              child: widget.bucket.avatarUrl.trim().isEmpty
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 18,
                                      color: AppColors.hintText,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.bucket.isMine
                                      ? flashOwnLabel(widget.bucket.kind)
                                      : '@${item.username}',
                                  style: AppFonts.plusJakarta(
                                    size: 14,
                                    weight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  flashSingularLabel(widget.bucket.kind),
                                  style: AppFonts.beVietnam(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: widget.bucket.kind == FlashKind.food
                                        ? const Color(0xFF7DFFB2)
                                        : const Color(0xFFFFB4C4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (!widget.bucket.isMine)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Once',
                            style: AppFonts.beVietnam(
                              size: 11,
                              weight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (details) {
                      final width = MediaQuery.sizeOf(context).width;
                      if (details.localPosition.dx < width * 0.35) {
                        _previous();
                      } else {
                        _next();
                      }
                    },
                    onLongPressStart: (_) => _pauseHold(),
                    onLongPressEnd: (_) => _resumeHold(),
                    child: const SizedBox.expand(),
                  ),
                ),
                if (item.caption.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.caption,
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                if (_canReply) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Row(
                      children: [
                        for (final reaction in _reactions)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _send(
                                _replyNote(reaction),
                                burst: reaction,
                              ),
                              child: Center(
                                child: Text(
                                  reaction,
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            focusNode: _replyFocus,
                            style: AppFonts.beVietnam(
                              size: 14,
                              weight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Reply…',
                              hintStyle: AppFonts.beVietnam(
                                size: 14,
                                weight: FontWeight.w500,
                                color: Colors.white54,
                              ),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            onSubmitted: (value) =>
                                _send(_replyNote(value)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _sending
                              ? null
                              : () => _send(
                                    _replyNote(_replyController.text),
                                  ),
                          icon: Icon(
                            Icons.send_rounded,
                            color: _sending ? Colors.white38 : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_burst != null)
            Center(
              child: Text(
                _burst!,
                style: AppFonts.plusJakarta(
                  size: 42,
                  weight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
