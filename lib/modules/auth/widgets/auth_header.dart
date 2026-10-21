import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppFonts.plusJakarta(
            size: 30,
            weight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: AppFonts.beVietnam(
            size: 15,
            weight: FontWeight.w500,
            color: AppColors.hintText,
          ),
        ),
      ],
    );
  }
}
