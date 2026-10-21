import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_cached_video_player.dart';
import '../controllers/upload_controller.dart';

class UploadMediaPreview extends StatelessWidget {
  const UploadMediaPreview({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UploadController>();

    return Obx(() {
      final items = controller.selectedMediaItems.toList(growable: false);
      final media = items.isEmpty ? null : items.first;
      final carousel = items.length > 1;
      final error = controller.mediaError.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (media == null)
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuCjR6VYR1NWMnsoP7adZC-mIzxHIu7fwncBpxL9q-fRplj-mm_4y43LGnwfoZfEx1cjyGPaRLYVTfLJLg56nSX9fQ_vdJ_5F8KT3MYBPPD6QYu9ngfUGMD2EqBJnUbtoN2v5x7wKfUDA8QisYfqiIWUzehPdMEAyaCZFn2FldyVGYdY6lXsnMT_xs-qV9V26-A4dpcRzspUkZiY0Bjo2v1tbEL5QR1ioC7mYSVzRE69CI6AMD6aFDWJQq7aHnpbGGn7vK8s7-NFjBQG',
                          fit: BoxFit.cover,
                        ),
                        Container(color: Colors.white.withValues(alpha: 0.25)),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const AppHeroIconData(Icons.cloud_upload_rounded,
                                size: 40,
                                color: AppColors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Preview',
                                style: AppFonts.beVietnam(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to upload from Camera or Gallery',
                                style: AppFonts.beVietnam(
                                  size: 11,
                                  weight: FontWeight.w500,
                                  color: AppColors.hintText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else if (media.type == AppMediaType.video)
                    AppCachedVideoPlayer(
                      videoUrl: media.path,
                      autoPlay: false,
                      isActive: true,
                    )
                  else if (carousel)
                    _UploadCarousel(items: items)
                  else
                    Image.file(media.file, fit: BoxFit.cover),
                  // Video has its own play/mute controls layered on top, so
                  // a full-bleed "tap anywhere to re-pick" overlay here
                  // would swallow every tap meant for them before it ever
                  // reaches the player. Picking a new video still works via
                  // the camera _ActionCircle button below.
                  if (media == null ||
                      (media.type != AppMediaType.video && !carousel))
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(onTap: onPick),
                      ),
                    ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        _ActionCircle(
                          icon: Icons.photo_camera_back_rounded,
                          onTap: onPick,
                        ),
                        const SizedBox(width: 8),
                        _ActionCircle(
                          icon: Icons.delete_rounded,
                          color: Colors.redAccent,
                          onTap: controller.clearMedia,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (media != null) ...[
            const SizedBox(height: 8),
            Text(
              carousel
                  ? '${items.length} photos • swipe to preview • max 10'
                  : '${media.type == AppMediaType.video ? 'Video' : 'Image'} selected • ${_readableSize(media.file)}',
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.hintText,
              ),
            ),
          ],
          if (error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              error,
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ],
        ],
      );
    });
  }

  String _readableSize(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _UploadCarousel extends StatefulWidget {
  const _UploadCarousel({required this.items});

  final List<PickedMedia> items;

  @override
  State<_UploadCarousel> createState() => _UploadCarouselState();
}

class _UploadCarouselState extends State<_UploadCarousel> {
  var _page = 0;

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: count,
          onPageChanged: (index) => setState(() => _page = index),
          itemBuilder: (context, index) {
            return Image.file(widget.items[index].file, fit: BoxFit.cover);
          },
        ),
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_page + 1}/$count',
              style: AppFonts.beVietnam(
                size: 11,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.icon, this.color, required this.onTap});

  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        child: AppHeroIconData(icon,
          size: 20,
          color: color ?? AppColors.text,
        ),
      ),
    );
  }
}
