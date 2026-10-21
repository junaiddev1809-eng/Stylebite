import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class HomeWelcomeCard extends StatelessWidget {
  const HomeWelcomeCard({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(47, 47, 46, 0.12),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.plusJakarta(
              size: 28,
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
    );
  }
}
