import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../models/upload_post_model.dart';

class UploadPostTypeSelector extends StatelessWidget {
  const UploadPostTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  final UploadPostType selectedType;
  final ValueChanged<UploadPostType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeCard(
            selected: selectedType == UploadPostType.outfit,
            icon: Icons.checkroom_rounded,
            iconColor: AppColors.primary,
            label: 'Post Outfit',
            onTap: () => onChanged(UploadPostType.outfit),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeCard(
            selected: selectedType == UploadPostType.food,
            icon: Icons.restaurant_rounded,
            iconColor: AppColors.accent,
            label: 'Post Food',
            onTap: () => onChanged(UploadPostType.food),
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.selected,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF3F0EF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(255, 77, 109, 0.12),
                    blurRadius: 26,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: 0.12),
              ),
              child: AppHeroIconData(icon, size: 34, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: AppFonts.plusJakarta(
                size: 16,
                weight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
