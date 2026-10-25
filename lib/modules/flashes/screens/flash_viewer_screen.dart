import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../messages/models/chat_models.dart';
import '../../messages/services/chat_api_service.dart';
import '../controllers/flash_controller.dart';
import '../models/flash_model.dart';

/// Instants-style viewer: centered mid-screen card, no story progress bars.
/// Tap photo → next in the combined following playlist.
class FlashViewerScreen extends StatefulWidget {
  const FlashViewerScreen({
    super.key,
    required this.items,
    required this.kind,
    this.startIndex = 0,
    this.openCameraWhenDone = true,
  });

  final List<FlashItem> items;
  final FlashKind kind;
  final int startIndex;
  final bool openCameraWhenDone;

  @override
  State<FlashViewerScreen> createState() => _FlashViewerScreenState();
}

class _FlashViewerScreenState extends State<FlashViewerScreen> {
  static const _reactions = ['❤️', '🔥', '😍', '😂', '😮', '👏'];

  late int _index;
  var _sending = false;
  String? _burst;
  int? _conversationId;

  String get _me =>
      (LocalStorage.getUsername() ?? '').trim().replaceFirst('@', '').toLowerCase();

  List<FlashItem> get _items => widget.items;
  FlashItem get _current => _items[_index];
  bool get _isMine =>
      _current.username.trim().replaceFirst('@', '').toLowerCase() == _me;
  bool get _canReact => !_isMine;

  @override
  void initState() {
    super.initState();
    _index = widget.startIndex.clamp(0, _items.length - 1);
    unawaited(FlashController.ensure().markSeen(_current.id));
  }

  Future<void> _finish() async {
    Get.back<void>();
    if (widget.openCameraWhenDone) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await FlashController.ensure().startCreate(kind: widget.kind);
    }
  }

  Future<void> _advance() async {
    await FlashController.ensure().markSeen(_current.id);
    if (_index >= _items.length - 1) {
      await _finish();
      return;
    }
    setState(() {
      _index += 1;
      _burst = null;
      _conversationId = null;
    });
    unawaited(FlashController.ensure().markSeen(_current.id));
  }

  Future<void> _goPrevious() async {
    if (_index <= 0) {
      Get.back<void>();
      return;
    }
    setState(() {
      _index -= 1;
      _burst = null;
      _conversationId = null;
    });
  }

  bool _isLocalFile(FlashItem item) {
    return item.mediaPath.isNotEmpty && File(item.mediaPath).existsSync();
  }

  String _mediaUrl(FlashItem item) {
    if (_isLocalFile(item)) return item.mediaPath;
    return item.mediaUrl.trim().isNotEmpty ? item.mediaUrl : item.mediaPath;
  }

  Future<void> _react(String emoji) async {
    if (!_canReact || _sending) return;
    final username = _current.username.trim().replaceFirst('@', '');
    if (username.isEmpty) return;
    setState(() => _sending = true);
    try {
      final conversationId = await _ensureConversation(username);
      if (conversationId == null) return;
      final note =
          'Reacted $emoji to your ${flashSingularLabel(widget.kind).toLowerCase()}';
      await const ChatApiService().sendMessage(conversationId, note);
      if (!mounted) return;
      setState(() => _burst = emoji);
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (mounted) setState(() => _burst = null);
    } on ChatApiException catch (error) {
      errorSnackBar(message: error.message);
    } catch (_) {
      errorSnackBar(message: 'Could not send reaction.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<int?> _ensureConversation(String username) async {
    final cached = _conversationId;
    if (cached != null && cached > 0) return cached;
    final chat = await const ChatApiService().initializeChat(username);
    if (chat.isBlocked || chat.isMessagingStopped || chat.conversationId <= 0) {
      errorSnackBar(message: 'You cannot react to this account.');
      return null;
    }
    _conversationId = chat.conversationId;
    return chat.conversationId;
  }

  Future<void> _deleteCurrent() async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text(
          'Delete ${flashSingularLabel(widget.kind)}?',
          style: AppFonts.plusJakarta(size: 17, weight: FontWeight.w800),
        ),
        content: Text(
          'Removes it for friends who have not opened it yet.',
          style: AppFonts.beVietnam(size: 14, weight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = _current.id;
    await FlashController.ensure().deleteFlash(id);
    if (!mounted) return;
    final remaining = [for (final i in _items) if (i.id != id) i];
    if (remaining.isEmpty) {
      Get.back<void>();
      return;
    }
    Get.off<void>(
      () => FlashViewerScreen(
        items: remaining,
        kind: widget.kind,
        startIndex: _index.clamp(0, remaining.length - 1),
        openCameraWhenDone: widget.openCameraWhenDone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    final mediaUrl = _mediaUrl(item);
    final isLocal = _isLocalFile(item);
    final accent = widget.kind == FlashKind.food
        ? const Color(0xFF1F8A4C)
        : AppColors.primary;
    final size = MediaQuery.sizeOf(context);
    final cardWidth = size.width * 0.86;
    final cardHeight = size.height * 0.58;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.92),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: Get.back,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(0xFFE9E3E1),
                        backgroundImage: item.avatarUrl.trim().isNotEmpty
                            ? NetworkImage(item.avatarUrl)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isMine
                              ? flashOwnLabel(widget.kind)
                              : '@${item.username}',
                          style: AppFonts.plusJakarta(
                            size: 14,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (_isMine)
                        IconButton(
                          onPressed: _deleteCurrent,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white70,
                          ),
                        ),
                      Text(
                        '${_index + 1}/${_items.length}',
                        style: AppFonts.beVietnam(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTapUp: (details) {
                        final box = context.findRenderObject() as RenderBox?;
                        final local = box?.globalToLocal(details.globalPosition);
                        final dx = local?.dx ?? details.globalPosition.dx;
                        final width = box?.size.width ?? size.width;
                        if (dx < width * 0.35) {
                          unawaited(_goPrevious());
                        } else {
                          unawaited(_advance());
                        }
                      },
                      child: Container(
                        width: cardWidth,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.28),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: ColoredBox(
                            color: const Color(0xFF1A1A1A),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (isLocal)
                                  Image.file(
                                    File(mediaUrl),
                                    key: ValueKey(item.id),
                                    fit: BoxFit.cover,
                                  )
                                else
                                  AppCachedImage(
                                    key: ValueKey(item.id),
                                    imageUrl: mediaUrl,
                                    fit: BoxFit.cover,
                                    width: cardWidth,
                                    height: cardHeight,
                                  ),
                                if (item.caption.trim().isNotEmpty)
                                  Positioned(
                                    left: 12,
                                    right: 12,
                                    bottom: 12,
                                    child: Text(
                                      item.caption,
                                      textAlign: TextAlign.center,
                                      style: AppFonts.beVietnam(
                                        size: 14,
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_canReact)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Row(
                      children: [
                        for (final reaction in _reactions)
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _react(reaction),
                              child: Center(
                                child: Text(
                                  reaction,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 28),
              ],
            ),
            if (_burst != null)
              Center(
                child: Text(_burst!, style: const TextStyle(fontSize: 72)),
              ),
          ],
        ),
      ),
    );
  }
}
