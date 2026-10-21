import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/contest_model.dart';

class ContestCategoryTabs extends StatelessWidget {
  const ContestCategoryTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ContestCategory selected;
  final ValueChanged<ContestCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TabChip(
            label: 'Admin-created',
            selected: selected == ContestCategory.admin,
            onTap: () => onChanged(ContestCategory.admin),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color.fromRGBO(47, 47, 46, 0.08),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: AppFonts.beVietnam(
            size: 13,
            weight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.hintText,
          ),
        ),
      ),
    );
  }
}
