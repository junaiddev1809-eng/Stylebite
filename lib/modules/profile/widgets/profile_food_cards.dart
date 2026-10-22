import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../models/profile_model.dart';

class ProfileFoodCards extends StatelessWidget {
  const ProfileFoodCards({super.key, required this.items, this.onTapItem});

  final List<ProfilePostModel> items;
  final ValueChanged<ProfilePostModel>? onTapItem;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCols = constraints.maxWidth > 650;
        if (!twoCols) {
          return Column(
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FoodCard(
                      item: item,
                      onTap: onTapItem == null ? null : () => onTapItem!(item),
                    ),
                  ),
                )
                .toList(),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) => _FoodCard(
            item: items[index],
            onTap: onTapItem == null ? null : () => onTapItem!(items[index]),
          ),
        );
      },
    );
  }
}

class _FoodCard extends StatelessWidget {
  const _FoodCard({required this.item, this.onTap});

  final ProfilePostModel item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0EF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: AppCachedImage(
                imageUrl: item.gridImageUrl,
                borderRadius: BorderRadius.circular(12),
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.displayTitle,
              style: AppFonts.plusJakarta(
                size: 16,
                weight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              item.metricsLabel,
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.hintText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
