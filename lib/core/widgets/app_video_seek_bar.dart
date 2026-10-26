import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// Scrubbable reel progress line — TikTok/IG style.
///
/// Idle: thin glowing track. Drag: bar thickens, thumb pops, time chip shows.
class AppVideoSeekBar extends StatefulWidget {
  const AppVideoSeekBar({
    super.key,
    required this.controller,
    this.height = 36,
    this.lineHeight = 3,
    this.activeLineHeight = 7,
    this.padding = EdgeInsets.zero,
    this.onScrubbingChanged,
    this.showTimeWhileScrubbing = true,
  });

  final VideoPlayerController? controller;
  final double height;
  final double lineHeight;
  final double activeLineHeight;
  final EdgeInsets padding;
  final ValueChanged<bool>? onScrubbingChanged;
  final bool showTimeWhileScrubbing;

  @override
  State<AppVideoSeekBar> createState() => _AppVideoSeekBarState();
}

class _AppVideoSeekBarState extends State<AppVideoSeekBar>
    with SingleTickerProviderStateMixin {
  bool _scrubbing = false;
  double? _dragValue;
  bool _wasPlaying = false;
  late final AnimationController _pulse;

  VideoPlayerController? get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _controller?.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant AppVideoSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTick);
      widget.controller?.addListener(_onTick);
      _dragValue = null;
      _scrubbing = false;
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _pulse.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!_scrubbing && mounted) {
      setState(() {});
    }
  }

  double _progressFor(VideoPlayerController controller) {
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) {
      return 0;
    }
    if (_dragValue != null) {
      return _dragValue!.clamp(0.0, 1.0);
    }
    final position = controller.value.position;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  String _format(Duration value) {
    final total = value.inSeconds.clamp(0, 99 * 60 + 59);
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _seekToFraction(double fraction) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final duration = controller.value.duration;
    if (duration.inMilliseconds <= 0) {
      return;
    }
    final target = duration * fraction.clamp(0.0, 1.0);
    await controller.seekTo(target);
  }

  void _beginScrub(Offset local, double width) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || width <= 0) {
      return;
    }
    HapticFeedback.selectionClick();
    _wasPlaying = controller.value.isPlaying;
    if (_wasPlaying) {
      controller.pause();
    }
    setState(() {
      _scrubbing = true;
      _dragValue = (local.dx / width).clamp(0.0, 1.0);
    });
    widget.onScrubbingChanged?.call(true);
    unawaited(_seekToFraction(_dragValue!));
  }

  void _updateScrub(Offset local, double width) {
    if (!_scrubbing || width <= 0) {
      return;
    }
    final next = (local.dx / width).clamp(0.0, 1.0);
    setState(() => _dragValue = next);
    unawaited(_seekToFraction(next));
  }

  Future<void> _endScrub() async {
    if (!_scrubbing) {
      return;
    }
    final value = _dragValue ?? 0;
    await _seekToFraction(value);
    final controller = _controller;
    if (_wasPlaying && controller != null && controller.value.isInitialized) {
      await controller.play();
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _scrubbing = false;
      _dragValue = null;
    });
    widget.onScrubbingChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final progress = ready ? _progressFor(controller) : 0.0;
    final duration = ready ? controller.value.duration : Duration.zero;
    final position = duration * progress;
    final lineHeight = _scrubbing ? widget.activeLineHeight : widget.lineHeight;
    final thumbSize = _scrubbing ? 16.0 : 8.0;

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final thumbLeft =
              (progress * width - thumbSize / 2).clamp(0.0, width - thumbSize);

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.showTimeWhileScrubbing && _scrubbing) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        '${_format(position)} / ${_format(duration)}',
                        style: AppFonts.beVietnam(
                          size: 12,
                          weight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: ready
                    ? (details) async {
                        final fraction =
                            (details.localPosition.dx / width).clamp(0.0, 1.0);
                        HapticFeedback.selectionClick();
                        setState(() => _dragValue = fraction);
                        await _seekToFraction(fraction);
                        if (mounted) {
                          setState(() => _dragValue = null);
                        }
                      }
                    : null,
                onHorizontalDragStart: ready
                    ? (details) => _beginScrub(details.localPosition, width)
                    : null,
                onHorizontalDragUpdate: ready
                    ? (details) => _updateScrub(details.localPosition, width)
                    : null,
                onHorizontalDragEnd:
                    ready ? (_) => unawaited(_endScrub()) : null,
                onHorizontalDragCancel:
                    ready ? () => unawaited(_endScrub()) : null,
                child: SizedBox(
                  height: widget.height,
                  width: width,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    clipBehavior: Clip.none,
                    children: [
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulse,
                          builder: (context, child) {
                            final glow = 0.18 + (_pulse.value * 0.12);
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              curve: Curves.easeOutCubic,
                              height: lineHeight,
                              width: width,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withValues(alpha: 0.16),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: _scrubbing ? 0.28 : glow * 0.55,
                                    ),
                                    blurRadius: _scrubbing ? 14 : 8,
                                    spreadRadius: _scrubbing ? 0.5 : 0,
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: child,
                            );
                          },
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress <= 0 ? 0.001 : progress,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFF8A5B),
                                      AppColors.primary,
                                      Color(0xFFFF4D6D),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (ready)
                        AnimatedPositioned(
                          duration: Duration(
                            milliseconds: _scrubbing ? 0 : 90,
                          ),
                          curve: Curves.easeOut,
                          left: thumbLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: thumbSize,
                            height: thumbSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: _scrubbing ? 0.95 : 0.7,
                                ),
                                width: _scrubbing ? 2.2 : 1.4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: _scrubbing ? 0.55 : 0.28,
                                  ),
                                  blurRadius: _scrubbing ? 12 : 6,
                                  spreadRadius: _scrubbing ? 1 : 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
