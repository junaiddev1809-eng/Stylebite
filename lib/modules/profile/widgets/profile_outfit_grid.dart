import 'package:flutter/material.dart';

import '../../../core/widgets/app_cached_image.dart';

class ProfileOutfitGrid extends StatelessWidget {
  const ProfileOutfitGrid({
    super.key,
    required this.images,
    this.carousel = const [],
    this.onTapImage,
  });

  final List<String> images;
  final List<bool> carousel;
  final ValueChanged<int>? onTapImage;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3 / 4,
      ),
      itemBuilder: (context, index) {
        return RepaintBoundary(
          child: InkWell(
            onTap: onTapImage == null ? null : () => onTapImage!(index),
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AppCachedImage(
                  imageUrl: images[index],
                  borderRadius: BorderRadius.circular(14),
                  fit: BoxFit.cover,
                  memCacheWidth: 420,
                ),
                if (index < carousel.length && carousel[index])
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: Icon(
                      Icons.collections_rounded,
                      color: Colors.white,
                      size: 18,
                      shadows: [
                        Shadow(color: Color(0x99000000), blurRadius: 6),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
