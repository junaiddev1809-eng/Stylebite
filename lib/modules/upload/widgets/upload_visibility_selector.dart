import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/upload_post_model.dart';

/// Public / Followers / Private chips shared by the create and edit post
/// screens. [selected] may be null while the current value is still being
/// resolved, in which case no chip is highlighted.
class UploadVisibilitySelector extends StatelessWidget {
  const UploadVisibilitySelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final UploadPostVisibility? selected;
  final ValueChanged<UploadPostVisibility> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _VisibilityChip(
            label: 'Public',
            selected: selected == UploadPostVisibility.public,
            onTap: () => onChanged(UploadPostVisibility.public),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _VisibilityChip(
            label: 'Followers',
            selected: selected == UploadPostVisibility.followersOnly,
            onTap: () => onChanged(UploadPostVisibility.followersOnly),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _VisibilityChip(
            label: 'Private',
            selected: selected == UploadPostVisibility.private,
            onTap: () => onChanged(UploadPostVisibility.private),
          ),
        ),
      ],
    );
  }
}

class _VisibilityChip extends StatelessWidget {
  const _VisibilityChip({
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : const Color(0xFFF3F0EF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppFonts.beVietnam(
            size: 12,
            weight: FontWeight.w700,
            color: selected ? AppColors.primary : AppColors.text,
          ),
        ),
      ),
    );
  }
}

/// Maps the API `visibility` string to the enum; null when unknown.
UploadPostVisibility? parseUploadPostVisibility(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'public':
      return UploadPostVisibility.public;
    case 'followers_only':
    case 'followers':
      return UploadPostVisibility.followersOnly;
    case 'private':
      return UploadPostVisibility.private;
    default:
      return null;
  }
}
