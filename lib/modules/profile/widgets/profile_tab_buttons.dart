import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/profile_model.dart';

class ProfileTabButtons extends StatelessWidget {
  const ProfileTabButtons({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    this.includeMoreTab = false,
    this.showSavedTab = true,
  });

  final ProfileContentTab activeTab;
  final ValueChanged<ProfileContentTab> onTabChanged;
  final bool includeMoreTab;
  // Saved posts are private to their owner — only the profile-owner's own
  // screen should pass true here.
  final bool showSavedTab;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabButton(
          label: 'Outfits',
          selected: activeTab == ProfileContentTab.outfits,
          onTap: () => onTabChanged(ProfileContentTab.outfits),
        ),
        _TabButton(
          label: 'Food',
          selected: activeTab == ProfileContentTab.food,
          onTap: () => onTabChanged(ProfileContentTab.food),
        ),
        if (showSavedTab)
          _TabButton(
            label: 'Saved',
            selected: activeTab == ProfileContentTab.saved,
            onTap: () => onTabChanged(ProfileContentTab.saved),
          ),
        if (includeMoreTab)
          _TabButton(
            label: 'More',
            selected: activeTab == ProfileContentTab.more,
            onTap: () => onTabChanged(ProfileContentTab.more),
          ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 18),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(
            children: [
              Text(
                label,
                style: AppFonts.plusJakarta(
                  size: 22,
                  weight: selected ? FontWeight.w800 : FontWeight.w700,
                  color: selected
                      ? AppColors.text
                      : AppColors.hintText.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 52,
                height: 4,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
