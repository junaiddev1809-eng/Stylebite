import 'package:flutter/material.dart';

class AppShimmerBox extends StatefulWidget {
  const AppShimmerBox({
    super.key,
    this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final double? height;
  final double? width;
  final BorderRadius borderRadius;

  @override
  State<AppShimmerBox> createState() => _AppShimmerBoxState();
}

class _AppShimmerBoxState extends State<AppShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + (2 * _controller.value), -0.3),
              end: Alignment(1 + (2 * _controller.value), 0.3),
              colors: const [
                Color(0xFFE8E4E2), // Slightly darker base for better contrast
                Color(0xFFFDFCFB), // Brighter highlight
                Color(0xFFE8E4E2),
              ],
            ),
          ),
        );
      },
    );
  }
}
