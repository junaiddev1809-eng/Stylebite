import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

enum MediaSourceChoice { camera, gallery }

Future<MediaSourceChoice?> showMediaSourceSheet(BuildContext context) {
  return showModalBottomSheet<MediaSourceChoice>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8E3E1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Select Media Source',
                style: AppFonts.plusJakarta(
                  size: 20,
                  weight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 14),
              _tile(
                icon: HeroIcons.camera,
                title: 'Camera',
                subtitle: 'Capture a new photo or video',
                onTap: () =>
                    Navigator.of(context).pop(MediaSourceChoice.camera),
              ),
              const SizedBox(height: 10),
              _tile(
                icon: HeroIcons.photo,
                title: 'Gallery',
                subtitle: 'Choose from your media library',
                onTap: () =>
                    Navigator.of(context).pop(MediaSourceChoice.gallery),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _tile({
  required HeroIcons icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: AppHeroIconData(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppFonts.beVietnam(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppFonts.beVietnam(
                    size: 12,
                    weight: FontWeight.w500,
                    color: AppColors.hintText,
                  ),
                ),
              ],
            ),
          ),
          AppHeroIconData(icon, color: AppColors.hintText),
        ],
      ),
    ),
  );
}
