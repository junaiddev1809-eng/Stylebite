import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../controllers/story_controller.dart';
import '../models/story_model.dart';

class StyleStoryTray extends StatelessWidget {
  const StyleStoryTray({super.key, this.kind = StoryKind.outfit});

  final StoryKind kind;

  bool get _isFood => kind == StoryKind.food;

  @override
  Widget build(BuildContext context) {
    final controller = StoryController.ensure();
    return Obx(() {
      final buckets = controller.bucketsFor(kind);
      return SizedBox(
        height: 108,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          scrollDirection: Axis.horizontal,
          itemCount: buckets.length,
          separatorBuilder: (context, index) => const SizedBox(width: 14),
          itemBuilder: (context, index) {
            final bucket = buckets[index];
            return _StoryRing(
              bucket: bucket,
              isFood: _isFood,
              onTap: () => controller.openBucket(bucket),
              onAdd: bucket.isMine
                  ? () => controller.startCreate(kind: kind)
                  : null,
            );
          },
        ),
      );
    });
  }
}

class _StoryRing extends StatelessWidget {
  const _StoryRing({
    required this.bucket,
    required this.isFood,
    required this.onTap,
    this.onAdd,
  });

  final StoryBucket bucket;
  final bool isFood;
  final VoidCallback onTap;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final hasStory = bucket.items.isNotEmpty;
    final unseen = bucket.hasUnseen;
    final label = bucket.isMine
        ? (isFood ? 'Food story' : 'Outfit story')
        : '@${bucket.username}';
    final addColor = isFood ? const Color(0xFF1F8A4C) : AppColors.primary;

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
                        colors: !hasStory || !unseen
                            ? const [Color(0xFFD8CFCC), Color(0xFFC9C1BE)]
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
                            color: addColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.background,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 14,
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
