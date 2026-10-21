import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/memory_item_model.dart';

class MemoryFeaturedCard extends StatelessWidget {
  const MemoryFeaturedCard({
    super.key,
    required this.memory,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Memories memory;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final String image1 = (memory.images != null && memory.images!.isNotEmpty)
        ? memory.images![0].fileUrl ?? ''
        : '';
    final String image2 = (memory.images != null && memory.images!.length > 1)
        ? memory.images![1].fileUrl ?? ''
        : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _image(image1)),
                  if (image2.isNotEmpty) ...{
                    const SizedBox(width: 6),
                    Expanded(child: _image(image2)),
                  }
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${memory.title ?? ''} *',
                      style: AppFonts.plusJakarta(
                        size: 24,
                        weight: FontWeight.w800,
                        color: AppColors.text,
                        height: 1.05,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE7D9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      memory.location ?? '',
                      style: AppFonts.beVietnam(
                        size: 10,
                        weight: FontWeight.w700,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${memory.memoryDate ?? ''} - ${memory.note ?? ''}',
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w500,
                  color: AppColors.hintText,
                ),
              ),
              if (memory.description != null &&
                  memory.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  memory.description!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.beVietnam(
                    size: 12,
                    weight: FontWeight.w400,
                    color: AppColors.hintText.withValues(alpha: 0.8),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  GestureDetector(
                    onTap: onFavoriteTap,
                    child: AppHeroIconData(
                      (memory.isFavorite ?? false)
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      size: 20,
                      color: (memory.isFavorite ?? false)
                          ? AppColors.primary
                          : AppColors.hintText,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const AppHeroIconData(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _image(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 240,
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (context, url) => Container(
            color: const Color(0xFFF3F0EF),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
          errorWidget: (context, url, error) => const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFFE9E6E6)),
            child: AppHeroIconData(Icons.image_not_supported_outlined),
          ),
        ),
      ),
    );
  }
}
