import 'package:flutter/material.dart';

/// White heart that pops in the middle of a post or reel after a double tap.
class LikeHeartBurst extends StatefulWidget {
  const LikeHeartBurst({super.key, required this.burstTick});

  final int burstTick;

  @override
  State<LikeHeartBurst> createState() => _LikeHeartBurstState();
}

class _LikeHeartBurstState extends State<LikeHeartBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didUpdateWidget(LikeHeartBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.burstTick != oldWidget.burstTick && widget.burstTick > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            if (t == 0) {
              return const SizedBox.shrink();
            }
            final scale = t < 0.35
                ? 0.4 + (t / 0.35) * 0.8
                : 1.2 - ((t - 0.35) / 0.65) * 0.2;
            final opacity = t < 0.55 ? 1.0 : (1 - (t - 0.55) / 0.45);
            return Opacity(
              opacity: opacity.clamp(0, 1),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 108,
            shadows: [
              Shadow(color: Color(0x66000000), blurRadius: 18),
            ],
          ),
        ),
      ),
    );
  }
}
