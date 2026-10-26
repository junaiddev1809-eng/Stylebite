import 'dart:io';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:video_player/video_player.dart';

import '../media/shared_video_mute.dart';
import '../media/video_cache_service.dart';
import 'app_cached_image.dart';
import 'app_video_seek_bar.dart';

enum AppVideoControlsPosition { topLeft, topRight }

class AppCachedVideoPlayer extends StatefulWidget {
  const AppCachedVideoPlayer({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.looping = true,
    this.isActive = true,
    this.showControls = true,
    this.showPlayPauseButton = true,
    this.showMuteButton = true,
    this.showCenterPlayPauseButton = false,
    this.enableTapToTogglePlayback = false,
    this.onDoubleTap,
    this.showPausedOverlayOnly = false,
    this.showProgressBar = false,
    this.controlsPosition = AppVideoControlsPosition.topRight,
    this.isMuted,
    this.shareMute = false,
    this.onMutedChanged,
    this.isPaused,
    this.onPlayPauseChanged,
    this.onProgressChanged,
    this.onInitFailed,
    this.initialProgress,
    this.onControllerReady,
    this.borderRadius,
    this.deferInitUntilActive = false,
    this.showLoadingIndicator = true,
    this.fit = BoxFit.cover,
  });

  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final bool looping;
  final bool isActive;
  final bool showControls;
  final bool showPlayPauseButton;
  final bool showMuteButton;
  final bool showCenterPlayPauseButton;
  final bool enableTapToTogglePlayback;
  final VoidCallback? onDoubleTap;
  final bool showPausedOverlayOnly;
  final bool showProgressBar;
  final AppVideoControlsPosition controlsPosition;
  /// How the decoded video fills its parent. Reels/feed use [BoxFit.cover]
  /// so every phone viewport is filled (TikTok/IG style).
  final BoxFit fit;
  final bool? isMuted;

  /// When true, this player follows [SharedVideoMute] instead of its own
  /// mute flag, so one tap applies to every reel.
  final bool shareMute;
  final ValueChanged<bool>? onMutedChanged;
  final bool? isPaused;
  final ValueChanged<bool>? onPlayPauseChanged;
  final ValueChanged<double>? onProgressChanged;
  /// Fired when the video URL cannot be opened or initialized.
  final VoidCallback? onInitFailed;
  // Fraction (0..1) of the video's duration to seek to right after it
  // initializes — used to resume from wherever a different instance of the
  // same video (e.g. the feed card) had already played to.
  final double? initialProgress;
  // Fires with the live controller once initialized (and with null when it
  // goes away), letting a parent build its own UI — e.g. a scrubber via
  // VideoProgressIndicator — driven by the real playback state.
  final ValueChanged<VideoPlayerController?>? onControllerReady;
  final BorderRadius? borderRadius;
  final bool deferInitUntilActive;
  final bool showLoadingIndicator;

  @override
  State<AppCachedVideoPlayer> createState() => _AppCachedVideoPlayerState();
}

class _AppCachedVideoPlayerState extends State<AppCachedVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _isMuted = true;
  bool _isBuffering = false;
  Size? _lastVideoSize;
  int _initGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.shareMute) {
      SharedVideoMute.muted.addListener(_onSharedMute);
    }
    if (!widget.deferInitUntilActive || widget.isActive) {
      _initialize();
    } else {
      _isLoading = false;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Tab switches and pushed routes keep this player mounted. Pause once
    // this screen is no longer the one the user is looking at.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncPlayState();
    });
  }

  @override
  void didUpdateWidget(covariant AppCachedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initialize();
      return;
    }
    if (widget.deferInitUntilActive &&
        widget.isActive &&
        _controller == null &&
        !_isLoading &&
        widget.videoUrl.trim().isNotEmpty) {
      _initialize();
      return;
    }
    // Deferred: play()/pause()/setVolume() notify the controller's listeners
    // synchronously, and a VideoProgressIndicator elsewhere in the tree (a
    // sibling, already mounted) listens to the same controller and calls
    // setState on itself in response. Doing that here — mid-rebuild of this
    // widget, itself triggered by a parent's didUpdateWidget — hits Flutter's
    // "setState() called during build" guard. Running it after the frame
    // settles avoids the reentrant call.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (oldWidget.isMuted != widget.isMuted) {
        _syncMuteState();
      }
      _syncPlayState();
    });
  }

  Future<void> _initialize() async {
    final generation = ++_initGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final old = _controller;
    _controller = null;
    if (old != null) {
      widget.onControllerReady?.call(null);
    }
    await old?.dispose();

    if (generation != _initGeneration) {
      return;
    }

    if (widget.videoUrl.trim().isEmpty) {
      if (mounted && generation == _initGeneration) {
        setState(() {
          _isLoading = false;
        });
        widget.onInitFailed?.call();
      }
      return;
    }

    VideoPlayerController? controller;
    final rawUrl = widget.videoUrl.trim();
    try {
      if (_looksLikeLocalVideoPath(rawUrl)) {
        final local = File(rawUrl.startsWith('file:')
            ? Uri.parse(rawUrl).toFilePath()
            : rawUrl);
        if (await local.exists()) {
          controller = VideoPlayerController.file(local);
        }
      }
    } catch (_) {
      controller = null;
    }

    if (controller == null) {
      try {
        File? localFile = await VideoCacheService.getCachedFile(rawUrl);
        if (localFile == null && VideoCacheService.isInFlight(rawUrl)) {
          localFile = await VideoCacheService.getFile(rawUrl).timeout(
            const Duration(milliseconds: 900),
            onTimeout: () => null,
          );
        }
        if (localFile != null && await localFile.exists()) {
          controller = VideoPlayerController.file(File(localFile.path));
        }
      } catch (_) {
        controller = null;
      }
    }

    if (generation != _initGeneration) {
      await controller?.dispose();
      return;
    }

    if (controller == null) {
      if (_looksLikeLocalVideoPath(rawUrl)) {
        try {
          final local = File(rawUrl.startsWith('file:')
              ? Uri.parse(rawUrl).toFilePath()
              : rawUrl);
          controller = VideoPlayerController.file(local);
        } catch (_) {
          if (mounted && generation == _initGeneration) {
            setState(() {
              _isLoading = false;
            });
            widget.onInitFailed?.call();
          }
          return;
        }
      } else {
        controller = VideoPlayerController.networkUrl(Uri.parse(rawUrl));
        VideoCacheService.prefetch(rawUrl);
      }
    }

    try {
      await controller.setLooping(widget.looping);
      await controller.initialize();
      // Volume set before initialize is ignored on Android, which left reels
      // silent even when they were supposed to start with sound.
      await controller.setVolume(_resolvedMuted ? 0 : 1);
      final initialProgress = widget.initialProgress;
      if (initialProgress != null && initialProgress > 0) {
        final duration = controller.value.duration;
        if (duration > Duration.zero) {
          final target = duration * initialProgress.clamp(0.0, 0.98);
          await controller.seekTo(target);
        }
      }
    } catch (_) {
      await controller.dispose();
      if (mounted && generation == _initGeneration) {
        setState(() {
          _isLoading = false;
        });
        widget.onInitFailed?.call();
      }
      return;
    }

    if (!mounted || generation != _initGeneration) {
      await controller.dispose();
      return;
    }

    final VideoPlayerController ready = controller;
    _controller = ready;
    _lastVideoSize = ready.value.size;
    ready.addListener(_handleControllerUpdate);
    _syncPlayState();
    setState(() {
      _isLoading = false;
      _isBuffering = ready.value.isBuffering;
    });
    widget.onControllerReady?.call(ready);
  }

  bool get _hasPlayableSize {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return false;
    }
    final size = controller.value.size;
    return size.width > 0 && size.height > 0;
  }

  void _handleControllerUpdate() {
    final controller = _controller;
    if (!mounted || controller == null) {
      return;
    }

    final isBuffering = controller.value.isBuffering;
    final size = controller.value.size;
    final sizeChanged = size != _lastVideoSize;
    if (isBuffering != _isBuffering || sizeChanged) {
      _lastVideoSize = size;
      setState(() {
        _isBuffering = isBuffering;
      });
    }

    if (widget.onProgressChanged != null && controller.value.isInitialized) {
      final duration = controller.value.duration;
      final position = controller.value.position;
      if (duration.inMilliseconds > 0) {
        final progress = position.inMilliseconds / duration.inMilliseconds;
        widget.onProgressChanged!(progress);
      }
    }
  }

  void _syncPlayState() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return;
    }

    final shouldPlay = _shouldPlayNow();
    if (shouldPlay) {
      final volume = _resolvedMuted ? 0.0 : 1.0;
      c.setVolume(volume);
      // Android applies volume only after playback starts, so a reel that
      // should be audible still comes up silent if this is set earlier.
      c.play().then((_) {
        if (!mounted || _controller != c) {
          return;
        }
        if (!_shouldPlayNow()) {
          c.setVolume(0);
          c.pause();
          return;
        }
        c.setVolume(_resolvedMuted ? 0 : 1);
      });
    } else {
      // A kept-alive player can keep its audio session after pause. Drop the
      // volume as well so sound cannot continue on another tab.
      c.setVolume(0);
      c.pause();
    }
  }

  bool _shouldPlayNow() {
    final route = ModalRoute.of(context);
    final routeIsCurrent = route == null || route.isCurrent;
    return widget.isActive &&
        widget.autoPlay &&
        !_resolvedPaused &&
        routeIsCurrent &&
        TickerMode.of(context);
  }

  void _syncMuteState() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return;
    }
    c.setVolume(_shouldPlayNow() && !_resolvedMuted ? 1 : 0);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _controller?.setVolume(0);
      _controller?.pause();
    } else if (state == AppLifecycleState.resumed) {
      _syncPlayState();
    }
  }

  void _onSharedMute() {
    if (!mounted) {
      return;
    }
    _syncMuteState();
  }

  void _toggleMute(VideoPlayerController controller) {
    final nextMuted = !_resolvedMuted;
    if (widget.shareMute) {
      SharedVideoMute.setMuted(nextMuted);
    }
    if (widget.onMutedChanged != null) {
      widget.onMutedChanged!(nextMuted);
    } else if (!widget.shareMute) {
      _isMuted = nextMuted;
      controller.setVolume(nextMuted ? 0 : 1);
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (widget.shareMute) {
      SharedVideoMute.muted.removeListener(_onSharedMute);
    }
    _initGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_handleControllerUpdate);
    _controller?.dispose();
    if (_controller != null) {
      widget.onControllerReady?.call(null);
    }
    super.dispose();
  }

  Widget _coverThumbnail() {
    final thumbnailUrl = widget.thumbnailUrl?.trim() ?? '';
    if (thumbnailUrl.isEmpty) {
      return ColoredBox(color: const Color(0xFF1B1B1F));
    }
    return AppCachedImage(
      imageUrl: thumbnailUrl,
      fit: widget.fit,
      memCacheWidth: 1080,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final showVideo = !_isLoading && _hasPlayableSize && controller != null;

    Widget child = Stack(
      fit: StackFit.expand,
      children: [
        // Letterbox / pillarbox stays dark when fit is contain.
        const ColoredBox(color: Color(0xFF0E0E11)),
        _coverThumbnail(),
        if (showVideo)
          FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        if (widget.showLoadingIndicator &&
            (_isLoading || (showVideo && _isBuffering)))
          const Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            ),
          ),
        if (showVideo) ...[
          if (widget.enableTapToTogglePlayback || widget.onDoubleTap != null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: widget.enableTapToTogglePlayback
                    ? _togglePlayback
                    : null,
                onDoubleTap: widget.onDoubleTap,
              ),
            ),
          if (widget.showCenterPlayPauseButton &&
              (widget.showPausedOverlayOnly
                  ? _resolvedPaused
                  : !controller.value.isPlaying))
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kept out of the IgnorePointer below — mute must stay
                    // tappable even when enableTapToTogglePlayback makes the
                    // play/pause icon a passive status indicator only.
                    if (widget.showMuteButton) ...[
                      _control(
                        icon: _resolvedMuted
                            ? HeroIcons.speakerXMark
                            : HeroIcons.speakerWave,
                        size: 52,
                        iconSize: 28,
                        backgroundOpacity: 0.38,
                        onTap: () => _toggleMute(controller),
                      ),
                      const SizedBox(height: 16),
                    ],
                    IgnorePointer(
                      ignoring: widget.enableTapToTogglePlayback,
                      child: _control(
                        icon: widget.showPausedOverlayOnly
                            ? HeroIcons.pause
                            : controller.value.isPlaying
                            ? HeroIcons.pause
                            : HeroIcons.play,
                        size: 52,
                        iconSize: 28,
                        backgroundOpacity: 0.38,
                        onTap: _togglePlayback,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.showProgressBar)
            Positioned(
              bottom: 132,
              left: 12,
              right: 12,
              child: AppVideoSeekBar(controller: controller),
            ),
          if (widget.showControls &&
              (widget.showPlayPauseButton || widget.showMuteButton))
            Positioned(
              top: widget.controlsPosition == AppVideoControlsPosition.topLeft
                  ? 10
                  : 80,
              left: widget.controlsPosition == AppVideoControlsPosition.topLeft
                  ? 10
                  : null,
              right:
                  widget.controlsPosition == AppVideoControlsPosition.topRight
                  ? 10
                  : null,
              child: Row(
                children: [
                  if (widget.showPlayPauseButton)
                    _control(
                      icon: controller.value.isPlaying
                          ? HeroIcons.pause
                          : HeroIcons.play,
                      onTap: () {
                        if (controller.value.isPlaying) {
                          controller.pause();
                        } else {
                          controller.play();
                        }
                        setState(() {});
                      },
                    ),
                  if (widget.showPlayPauseButton && widget.showMuteButton)
                    const SizedBox(width: 8),
                  if (widget.showMuteButton)
                    _control(
                      icon: _resolvedMuted
                          ? HeroIcons.speakerXMark
                          : HeroIcons.speakerWave,
                      onTap: () => _toggleMute(controller),
                    ),
                ],
              ),
            ),
        ],
      ],
    );

    if (widget.borderRadius != null) {
      return ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }
    return child;
  }

  void _togglePlayback() {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _isLoading || _isBuffering) {
      return;
    }

    final nextPaused = c.value.isPlaying;
    if (widget.onPlayPauseChanged != null) {
      widget.onPlayPauseChanged!(nextPaused);
      return;
    }

    if (nextPaused) {
      c.pause();
    } else {
      c.play();
    }
    if (mounted) {
      setState(() {});
    }
  }

  bool get _resolvedMuted => widget.shareMute
      ? SharedVideoMute.muted.value
      : (widget.isMuted ?? _isMuted);

  bool get _resolvedPaused => widget.isPaused ?? false;

  Widget _control({
    required HeroIcons icon,
    required VoidCallback onTap,
    double size = 34,
    double iconSize = 18,
    double backgroundOpacity = 0.45,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: backgroundOpacity),
          shape: BoxShape.circle,
        ),
        child: AppHeroIconData(icon, size: iconSize, color: Colors.white),
      ),
    );
  }

  /// Local device path (POSIX, Windows drive letter, or file://) — not http(s).
  bool _looksLikeLocalVideoPath(String url) {
    final value = url.trim();
    if (value.isEmpty) {
      return false;
    }
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return false;
    }
    if (value.startsWith('/') || lower.startsWith('file:')) {
      return true;
    }
    // Windows: C:\… or C:/…
    return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
  }
}
