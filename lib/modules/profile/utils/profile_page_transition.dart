import 'package:flutter/material.dart';

class ProfilePageTransition {
  static const Duration forward = Duration(milliseconds: 260);
  static const Duration reverse = Duration(milliseconds: 220);

  static PageRouteBuilder<void> to(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: forward,
      reverseTransitionDuration: reverse,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubicEmphasized,
          reverseCurve: Curves.easeInOutCubic,
        );
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.58, curve: Curves.easeOut),
            reverseCurve: Curves.easeIn,
          ),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.965, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
