import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class LandingTabPlaceholder extends StatelessWidget {
  const LandingTabPlaceholder({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF5F0), AppColors.background],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: AppHeroIconData(icon, color: Colors.white, size: 42),
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: AppFonts.plusJakarta(
                    size: 30,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppFonts.beVietnam(
                    size: 15,
                    weight: FontWeight.w500,
                    color: AppColors.hintText,
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
