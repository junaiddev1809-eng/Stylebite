import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class SplashCard extends StatelessWidget {
  const SplashCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.loaderProgress,
    required this.onEnterPressed,
  });

  final String title;
  final String subtitle;
  final double loaderProgress;
  final VoidCallback onEnterPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  AppAssets.brandLogo,
                  width: 88,
                  height: 88,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) =>
                      const _FallbackBrandIcon(),
                ),
                const SizedBox(height: 12),
                Text(
                  'StyleBite',
                  style: AppFonts.plusJakarta(
                    size: 32,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppFonts.plusJakarta(
                    size: 20,
                    weight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: 0.2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: double.infinity,
                    height: 6,
                    child: ColoredBox(
                      color: const Color.fromRGBO(255, 77, 109, 0.12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: loaderProgress.clamp(0.0, 1.0),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.secondary,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  subtitle,
                  style: AppFonts.beVietnam(
                    size: 12,
                    weight: FontWeight.w500,
                    color: AppColors.hintText,
                  ),
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  child: ElevatedButton(
                    onPressed: onEnterPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    child: Text(
                      'Enter App',
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackBrandIcon extends StatelessWidget {
  const _FallbackBrandIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white),
    );
  }
}
