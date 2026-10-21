import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/create_contest_model.dart';

class CreateContestTypeSelector extends StatelessWidget {
  const CreateContestTypeSelector({
    super.key,
    required this.options,
    required this.selectedType,
    required this.onChanged,
  });

  final List<ContestTypeOption> options;
  final CreateContestType selectedType;
  final ValueChanged<CreateContestType> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: options.map((option) {
            final isSelected = option.type == selectedType;
            return SizedBox(
              width: compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 42) / 4,
              child: _TypeCard(
                option: option,
                selected: isSelected,
                onTap: () => onChanged(option.type),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final ContestTypeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppHeroIconData(
              _iconFor(option.icon),
              size: 34,
              color: selected ? AppColors.primary : const Color(0xFF8F8F95),
            ),
            const SizedBox(height: 14),
            Text(
              option.title,
              style: AppFonts.plusJakarta(
                size: 18,
                weight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              option.description,
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.hintText,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'swords':
        return Icons.sports_martial_arts_rounded;
      case 'groups':
        return Icons.groups_rounded;
      case 'location_city':
        return Icons.location_city_rounded;
      case 'campaign':
        return Icons.campaign_rounded;
      default:
        return Icons.circle_rounded;
    }
  }
}
