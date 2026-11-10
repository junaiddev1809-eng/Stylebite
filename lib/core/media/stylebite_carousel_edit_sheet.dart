import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'stylebite_editor_chrome.dart';

/// How to handle filters for a multi-photo carousel before upload.
enum StyleBiteCarouselEditChoice {
  /// One look + intensity baked onto every slide (Instagram apply-all).
  applyLookToAll,

  /// Open the full editor on every slide.
  editEach,

  /// Keep originals — skip the editor entirely.
  skipEditing,
}

/// Instagram-inspired carousel edit choices.
Future<StyleBiteCarouselEditChoice?> showStyleBiteCarouselEditSheet({
  required int slideCount,
}) {
  return Get.bottomSheet<StyleBiteCarouselEditChoice>(
    SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: StyleBiteEditorChrome.bar,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit your carousel',
              style: AppFonts.plusJakarta(
                size: 18,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$slideCount photos selected. Choose how you want to style them.',
              style: AppFonts.plusJakarta(
                size: 13,
                weight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 18),
            _ChoiceTile(
              icon: Icons.filter_vintage_rounded,
              title: 'Apply one look to all',
              subtitle: 'Pick a StyleBite filter once — Instagram apply-all',
              accent: AppColors.primary,
              onTap: () =>
                  Get.back(result: StyleBiteCarouselEditChoice.applyLookToAll),
            ),
            const SizedBox(height: 10),
            _ChoiceTile(
              icon: Icons.auto_awesome_rounded,
              title: 'Edit each photo',
              subtitle: 'Full filters, Lux & Structure on every slide',
              accent: const Color(0xFFFFD166),
              onTap: () =>
                  Get.back(result: StyleBiteCarouselEditChoice.editEach),
            ),
            const SizedBox(height: 10),
            _ChoiceTile(
              icon: Icons.skip_next_rounded,
              title: 'Skip editing',
              subtitle: 'Post the photos as they are',
              accent: Colors.white70,
              onTap: () =>
                  Get.back(result: StyleBiteCarouselEditChoice.skipEditing),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: Get.back,
              child: Text(
                'Cancel',
                style: AppFonts.plusJakarta(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StyleBiteEditorChrome.elevated,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppFonts.plusJakarta(
                        size: 15,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppFonts.plusJakarta(
                        size: 12,
                        weight: FontWeight.w500,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
