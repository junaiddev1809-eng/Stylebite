import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/create_contest_model.dart';

class CreateContestRuleCards extends StatelessWidget {
  const CreateContestRuleCards({super.key, required this.items});

  final List<ContestRuleCardModel> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        if (compact) {
          return Column(
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RuleCard(item: item),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          children: List.generate(items.length, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == items.length - 1 ? 0 : 12,
                ),
                child: _RuleCard(item: items[index]),
              ),
            );
          }),
        );
      },
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({required this.item});

  final ContestRuleCardModel item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F3),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AppHeroIconData(_iconFor(item.icon), color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.label,
                style: AppFonts.beVietnam(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppColors.hintText,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.value,
                style: AppFonts.plusJakarta(
                  size: 16,
                  weight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String icon) {
    switch (icon) {
      case 'person_add':
        return Icons.person_add_alt_1_rounded;
      case 'timer':
        return Icons.timer_outlined;
      case 'how_to_vote':
        return Icons.how_to_vote_rounded;
      default:
        return Icons.circle_rounded;
    }
  }
}
