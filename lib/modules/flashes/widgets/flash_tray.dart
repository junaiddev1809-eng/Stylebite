import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../controllers/flash_controller.dart';
import '../models/flash_model.dart';

class FlashTray extends StatelessWidget {
  const FlashTray({super.key, this.kind = FlashKind.outfit});

  final FlashKind kind;

  bool get _isFood => kind == FlashKind.food;

  @override
  Widget build(BuildContext context) {
    final controller = FlashController.ensure();
    return Obx(() {
      final buckets = controller.bucketsFor(kind);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Icon(
                  _isFood ? Icons.restaurant_rounded : Icons.bolt_rounded,
                  size: 16,
                  color: _isFood ? const Color(0xFF1F8A4C) : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  flashPluralLabel(kind),
                  style: AppFonts.plusJakarta(
                    size: 15,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'once · 24h',
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.hintText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 108,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              scrollDirection: Axis.horizontal,
              itemCount: buckets.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final bucket = buckets[index];
                return _FlashRing(
                  bucket: bucket,
                  isFood: _isFood,
                  onTap: () => controller.openBucket(bucket),
                  onAdd: bucket.isMine
                      ? () => controller.startCreate(kind: kind)
                      : null,
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class _FlashRing extends StatelessWidget {
  const _FlashRing({
    required this.bucket,
    required this.isFood,
    required this.onTap,
    this.onAdd,
  });

  final FlashBucket bucket;
  final bool isFood;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final hasFlash = bucket.items.isNotEmpty;
    final unseen = bucket.hasUnseen;
    final label = bucket.isMine
        ? (isFood ? 'Your Bite' : 'Your Flash')
        : '@${bucket.username}';
    final accent = isFood ? const Color(0xFF1F8A4C) : AppColors.primary;

    return SizedBox(
      width: 74,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: !hasFlash || !unseen
                            ? const [Color(0xFFD8CFCC), Color(0xFFC9C1BE)]
                            : isFood
                                ? const [
                                    Color(0xFF1F8A4C),
                                    Color(0xFF5ED18A),
                                    Color(0xFF0E5C32),
                                  ]
                                : const [
                                    AppColors.primary,
                                    Color(0xFFFF8A5B),
                                    AppColors.accent,
                                  ],
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(1.6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: bucket.avatarUrl.trim().isNotEmpty
                            ? AppCachedImage(
                                imageUrl: bucket.avatarUrl,
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                                memCacheWidth: 160,
                              )
                            : const ColoredBox(
                                color: Color(0xFFE9E3E1),
                                child: Center(
                                  child: AppHeroIconData(
                                    Icons.person_rounded,
                                    size: 26,
                                    color: AppColors.hintText,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (bucket.isMine)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: onAdd,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppFonts.beVietnam(
                size: 11,
                weight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
