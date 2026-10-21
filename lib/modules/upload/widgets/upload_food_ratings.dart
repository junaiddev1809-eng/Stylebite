import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../models/upload_post_model.dart';

class UploadFoodRatings extends StatelessWidget {
  const UploadFoodRatings({
    super.key,
    required this.items,
    required this.values,
    required this.onChanged,
    required this.previewTitle,
    required this.previewLocation,
    required this.overall,
  });

  final List<FoodRatingItem> items;
  final Map<String, double> values;
  final void Function(String key, double value) onChanged;
  final String previewTitle;
  final String previewLocation;
  final double overall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewTitle,
                      style: AppFonts.beVietnam(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      previewLocation,
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w500,
                        color: AppColors.hintText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFFFE7A8),
                ),
                child: Row(
                  children: [
                    const AppHeroIconData(Icons.star_rounded,
                      size: 16,
                      color: Color(0xFF7A2E00),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      overall.toStringAsFixed(1),
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w700,
                        color: const Color(0xFF7A2E00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...items.map((item) {
            final value = ((values[item.key] ?? item.initial).clamp(
              1.0,
              5.0,
            )).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Text(
                      item.label,
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w600,
                        color: AppColors.hintText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: value,
                      min: 1,
                      max: 5,
                      divisions: 40,
                      activeColor: const Color(0xFFF59E0B),
                      onChanged: (newValue) => onChanged(item.key, newValue),
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      value.toStringAsFixed(1),
                      textAlign: TextAlign.right,
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
