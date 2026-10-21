import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class StorySourceSheet extends StatelessWidget {
  const StorySourceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFE7E2E0),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Add to story',
            style: AppFonts.plusJakarta(
              size: 18,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.photo_camera_rounded),
            title: Text(
              'Camera',
              style: AppFonts.beVietnam(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            onTap: () => Get.back(result: 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: Text(
              'Gallery',
              style: AppFonts.beVietnam(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            onTap: () => Get.back(result: 'gallery'),
          ),
        ],
      ),
    );
  }
}
