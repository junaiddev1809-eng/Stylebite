import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gold sprinkles drifting over a contest-winning post.
class WinnerSparkleOverlay extends StatefulWidget {
  const WinnerSparkleOverlay({super.key});

  @override
  State<WinnerSparkleOverlay> createState() => _WinnerSparkleOverlayState();
}

class _WinnerSparkleOverlayState extends State<WinnerSparkleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Speck> _specks;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _specks = List<_Speck>.generate(26, _Speck.new);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _SparklePainter(
              progress: _controller.value,
              specks: _specks,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _Speck {
  _Speck(int index) : random = math.Random(index * 97 + 11) {
    x = random.nextDouble();
    size = 1.6 + random.nextDouble() * 3.4;
    speed = 0.35 + random.nextDouble() * 0.65;
    phase = random.nextDouble();
    drift = (random.nextDouble() - 0.5) * 0.08;
    round = random.nextBool();
  }

  final math.Random random;
  late final double x;
  late final double size;
  late final double speed;
  late final double phase;
  late final double drift;
  late final bool round;
}

class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.progress, required this.specks});

  final double progress;
  final List<_Speck> specks;

  static const List<Color> _colors = <Color>[
    Color(0xFFFFF4C2),
    Color(0xFFFFE08A),
    Color(0xFFFFD24A),
    Color(0xFFFFF8E1),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < specks.length; i++) {
      final speck = specks[i];
      final travel = (progress * speck.speed + speck.phase) % 1.0;
      final y = (1.05 - travel) * size.height;
      final x = (speck.x + math.sin(travel * math.pi * 2) * speck.drift) * size.width;
      final twinkle = 0.35 + 0.65 * ((math.sin((travel + speck.phase) * math.pi * 4) + 1) / 2);
      final paint = Paint()
        ..color = _colors[i % _colors.length].withValues(alpha: twinkle);

      if (speck.round) {
        canvas.drawCircle(Offset(x, y), speck.size, paint);
      } else {
        _drawStar(canvas, Offset(x, y), speck.size * 1.7, paint);
      }
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final angle = (i * math.pi / 2) - math.pi / 2;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      final inner = Offset(
        center.dx + math.cos(angle + math.pi / 4) * radius * 0.35,
        center.dy + math.sin(angle + math.pi / 4) * radius * 0.35,
      );
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
