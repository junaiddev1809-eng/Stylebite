import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// Scrubbable reel/video progress line.
///
/// Tall hit target + horizontal drag/tap seek so users can jump backward or
/// forward without fighting the surrounding feed gestures.
class AppVideoSeekBar extends StatefulWidget {
  const AppVideoSeekBar({
    super.key,
    required this.controller,
    this.height = 28,
    this.lineHeight = 2.5,
    this.activeLineHeight = 4.5,
    this.padding = EdgeInsets.zero,
    this.onScrubbingChanged,
  });

  final VideoPlayerController? controller;
  final double height;
  final double lineHeight;
  final double activeLineHeight;
  final EdgeInsets padding;
  final ValueChanged<bool>? onScrubbingChanged;

  @override
  State<AppVideoSeekBar> createState() => _AppVideoSeekBarState();
}

class _AppVideoSeekBarState extends State<AppVideoSeekBar> {
  bool _scrubbing = false;
  double? _dragValue;
  bool _wasPlaying = false;

  VideoPlayerController? get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
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
    final lineHeight = _scrubbing ? widget.activeLineHeight : widget.lineHeight;

    return Padding(
      padding: widget.padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
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
            onHorizontalDragEnd: ready ? (_) => unawaited(_endScrub()) : null,
            onHorizontalDragCancel: ready ? () => unawaited(_endScrub()) : null,
            child: SizedBox(
              height: widget.height,
              width: width,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  height: lineHeight,
                  width: width,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progress,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: _scrubbing ? 1 : 0.92,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: _scrubbing
                              ? [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
