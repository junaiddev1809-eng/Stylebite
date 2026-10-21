import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:video_player/video_player.dart';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/shared_video_mute.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/double_tap_zoom.dart';
import '../../../core/widgets/app_cached_video_player.dart';

class FullMediaPreviewScreen extends StatefulWidget {
  const FullMediaPreviewScreen({
    super.key,
    required this.mediaUrl,
    required this.type,
    this.imageUrls = const [],
    this.thumbnailUrl,
    this.initialProgress,
    this.initialMuted,
  });

  final String mediaUrl;
  final List<String> imageUrls;
  final AppMediaType type;
  final String? thumbnailUrl;
  // Fraction (0..1) of the video's duration to resume from — e.g. wherever
  // it had already played to in the feed card that opened this screen.
  final double? initialProgress;
  // Starts the player matching whatever mute state the caller (e.g. the
  // feed card) was already in, instead of always defaulting to muted.
  final bool? initialMuted;

  @override
  State<FullMediaPreviewScreen> createState() =>
      _FullMediaPreviewScreenState();
}

class _FullMediaPreviewScreenState extends State<FullMediaPreviewScreen> {
  static const _hideDelay = Duration(seconds: 3);

  late bool _isMuted = widget.initialMuted ?? SharedVideoMute.muted.value;
  bool _isPaused = false;
  bool _controlsVisible = false;
  Timer? _hideTimer;
  VideoPlayerController? _videoController;

  bool get _isVideo => widget.type == AppMediaType.video;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _handleBackgroundTap() {
    if (!_isVideo) {
      return;
    }
    if (_controlsVisible) {
      _hideControls();
    } else {
      _showControlsTemporarily();
    }
  }

  void _showControlsTemporarily() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _hideTimer = Timer(_hideDelay, () {
      if (mounted) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _hideControls() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = false);
  }

  void _togglePlayPause() {
    setState(() => _isPaused = !_isPaused);
    _showControlsTemporarily();
  }

  void _toggleMute() {
    final nextMuted = !_isMuted;
    SharedVideoMute.setMuted(nextMuted);
    setState(() => _isMuted = nextMuted);
    _showControlsTemporarily();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isVideo)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleBackgroundTap,
              child: Center(
                child: AppCachedVideoPlayer(
                  videoUrl: widget.mediaUrl,
                  thumbnailUrl: widget.thumbnailUrl,
                  autoPlay: true,
                  isActive: true,
                  isPaused: _isPaused,
                  isMuted: _isMuted,
                  shareMute: true,
                  showControls: false,
                  initialProgress: widget.initialProgress,
                  onControllerReady: (controller) =>
                      setState(() => _videoController = controller),
                ),
              ),
            )
          else if (widget.imageUrls.length > 1)
            PageView.builder(
              itemCount: widget.imageUrls.length,
              itemBuilder: (context, index) {
                final path = widget.imageUrls[index];
                final file = File(
                  path.startsWith('file://') ? path.substring(7) : path,
                );
                final slide = file.existsSync()
                    ? Image.file(file, fit: BoxFit.contain)
                    : AppCachedImage(
                        imageUrl: path,
                        fit: BoxFit.contain,
                      );
                return DoubleTapZoom(child: Center(child: slide));
              },
            )
          else
            DoubleTapZoom(
              child: Center(
                child: AppCachedImage(imageUrl: widget.mediaUrl, fit: BoxFit.contain),
              ),
            ),
          if (_isVideo)
            IgnorePointer(
              ignoring: !_controlsVisible,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _bigControl(
                            icon: _isPaused ? HeroIcons.play : HeroIcons.pause,
                            onTap: _togglePlayPause,
                          ),
                          const SizedBox(height: 28),
                          _bigControl(
                            icon: _isMuted
                                ? HeroIcons.speakerXMark
                                : HeroIcons.speakerWave,
                            onTap: _toggleMute,
                          ),
                        ],
                      ),
                    ),
                    if (_videoController != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: MediaQuery.paddingOf(context).bottom + 20,
                        child: VideoProgressIndicator(
                          _videoController!,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          colors: VideoProgressColors(
                            playedColor: Colors.white,
                            bufferedColor: Colors.white.withValues(alpha: 0.3),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
              ),
              icon: const AppHeroIconData(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigControl({required HeroIcons icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: AppHeroIconData(icon, size: 28, color: Colors.white),
      ),
    );
  }
}
