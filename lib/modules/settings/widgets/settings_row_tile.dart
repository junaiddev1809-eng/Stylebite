import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';

class SettingsRowTile extends StatelessWidget {
  const SettingsRowTile({
    super.key,
    required this.title,
    this.trailingText,
    this.trailingIcon,
    this.onTap,
  });

  final String title;
  final String? trailingText;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppFonts.beVietnam(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppColors.textThemed,
                  ),
                ),
              ),
              if (trailingText != null)
                Text(
                  trailingText!,
                  style: AppFonts.beVietnam(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.hintTextThemed,
                  ),
                ),
              if (trailingIcon != null)
                AppHeroIconData(
                  trailingIcon!,
                  color: AppColors.hintTextThemed,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
