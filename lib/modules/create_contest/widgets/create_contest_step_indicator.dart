import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class CreateContestStepIndicator extends StatelessWidget {
  const CreateContestStepIndicator({super.key, this.activeStep = 1});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(height: 2, color: const Color(0xFFE7E8EA)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) {
              final step = index + 1;
              final isActive = step <= activeStep;
              return Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        )
                      : null,
                  color: isActive ? null : const Color(0xFFE8E8EA),
                ),
                child: Text(
                  '$step',
                  style: AppFonts.plusJakarta(
                    size: 14,
                    weight: FontWeight.w700,
                    color: isActive ? Colors.white : AppColors.hintText,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
