import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../controllers/flash_controller.dart';
import '../models/flash_model.dart';
import '../screens/flash_viewer_screen.dart';

class FlashArchiveSheet extends StatelessWidget {
  const FlashArchiveSheet({super.key, required this.kind});

  final FlashKind kind;

  @override
  Widget build(BuildContext context) {
    final controller = FlashController.ensure();
    final accent =
        kind == FlashKind.food ? const Color(0xFF1F8A4C) : AppColors.primary;

    return Obx(() {
      final items = controller.minePlaylist(kind);
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
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
            const SizedBox(height: 14),
            Text(
              'Your ${flashPluralLabel(kind)}',
              style: AppFonts.plusJakarta(
                size: 17,
                weight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'View like Instants, or delete anytime.',
              textAlign: TextAlign.center,
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w500,
                color: AppColors.hintText,
              ),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Get.back<void>();
                    await controller.openMineViewer(kind: kind);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'View all',
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Text(
                  'Nothing here yet.',
                  style: AppFonts.beVietnam(
                    size: 14,
                    weight: FontWeight.w600,
                    color: AppColors.hintText,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[items.length - 1 - index];
                    final local = item.mediaPath.isNotEmpty &&
                        File(item.mediaPath).existsSync();
                    final url = local
                        ? item.mediaPath
                        : (item.mediaUrl.isNotEmpty
                            ? item.mediaUrl
                            : item.mediaPath);
                    final startIndex = items.indexOf(item);
                    return Row(
                      children: [
                        GestureDetector(
                          onTap: () async {
                            Get.back<void>();
                            await Get.to<void>(
                              () => FlashViewerScreen(
                                items: items,
                                kind: kind,
                                startIndex: startIndex < 0 ? 0 : startIndex,
                                openCameraWhenDone: false,
                              ),
                            );
                            await controller.load();
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox(
                              width: 56,
                              height: 70,
                              child: local
                                  ? Image.file(File(url), fit: BoxFit.cover)
                                  : AppCachedImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      width: 56,
                                      height: 70,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              Get.back<void>();
                              await Get.to<void>(
                                () => FlashViewerScreen(
                                  items: items,
                                  kind: kind,
                                  startIndex: startIndex < 0 ? 0 : startIndex,
                                  openCameraWhenDone: false,
                                ),
                              );
                              await controller.load();
                            },
                            child: Text(
                              item.caption.trim().isEmpty
                                  ? flashSingularLabel(kind)
                                  : item.caption,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.beVietnam(
                                size: 13,
                                weight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () async {
                            await controller.deleteFlash(item.id);
                          },
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      );
    });
  }
}
