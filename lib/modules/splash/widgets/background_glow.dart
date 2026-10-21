import 'package:flutter/material.dart';

class BackgroundGlow extends StatelessWidget {
  const BackgroundGlow({
    super.key,
    required this.alignment,
    required this.width,
    required this.height,
    required this.innerColor,
  });

  final Alignment alignment;
  final double width;
  final double height;
  final Color innerColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [innerColor, Colors.transparent],
              stops: const [0, 0.6],
            ),
          ),
        ),
      ),
    );
  }
}
