import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class IntroPageIndicator extends StatelessWidget {
  const IntroPageIndicator({
    super.key,
    required this.total,
    required this.currentIndex,
  });

  final int total;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        total,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentIndex == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            gradient: currentIndex == index
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  )
                : null,
            color: currentIndex == index
                ? null
                : AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}
