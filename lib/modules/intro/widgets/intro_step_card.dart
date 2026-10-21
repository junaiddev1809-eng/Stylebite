import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/intro_step_model.dart';

class IntroStepCard extends StatelessWidget {
  const IntroStepCard({super.key, required this.step});

  final IntroStepModel step;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 186,
          height: 186,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(255, 77, 109, 0.25),
                blurRadius: 35,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: AppHeroIconData(step.icon, size: 88, color: Colors.white),
        ),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            step.title,
            textAlign: TextAlign.center,
            style: AppFonts.plusJakarta(
              size: 30,
              height: 1.2,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            step.description,
            textAlign: TextAlign.center,
            style: AppFonts.beVietnam(
              size: 16,
              height: 1.5,
              weight: FontWeight.w500,
              color: AppColors.hintText,
            ),
          ),
        ),
      ],
    );
  }
}
