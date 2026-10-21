import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../home/models/home_post_model.dart';
import '../utils/explore_media_mapper.dart';

class ExploreMediaGrid extends StatelessWidget {
  const ExploreMediaGrid({
    super.key,
    required this.items,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(10, 0, 10, 0),
    this.showRestaurantName = false,
  });

  final List<HomePostModel> items;
  final ValueChanged<HomePostModel>? onTap;
  final EdgeInsetsGeometry padding;
  final bool showRestaurantName;

  static const double gap = 10;
  static const double radius = 18;

  static Widget shimmer({int tiles = 8}) {
    const heights = <double>[210, 280, 240, 320, 200, 300, 260, 230];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                for (var i = 0; i < tiles; i += 2) ...[
                  if (i > 0) const SizedBox(height: gap),
                  AppShimmerBox(
                    height: heights[i % heights.length],
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: gap),
          Expanded(
            child: Column(
              children: [
                for (var i = 1; i < tiles; i += 2) ...[
                  if (i > 1) const SizedBox(height: gap),
                  AppShimmerBox(
                    height: heights[i % heights.length],
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth - gap) / 2;
          final left = <_PinLayout>[];
          final right = <_PinLayout>[];
          var leftHeight = 0.0;
          var rightHeight = 0.0;

          final trending = ExploreMediaMapper.trendingIds(items);
          for (var i = 0; i < items.length; i++) {
            final post = items[i];
            final viral = trending.contains(post.id);
            final height = columnWidth / _aspectRatioFor(post, i, viral: viral);
            final pin = _PinLayout(post: post, height: height, isViral: viral);
            if (leftHeight <= rightHeight) {
              left.add(pin);
              leftHeight += height + gap;
            } else {
              right.add(pin);
              rightHeight += height + gap;
            }
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PinColumn(
                  pins: left,
                  onTap: onTap,
                  showRestaurantName: showRestaurantName,
                ),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: _PinColumn(
                  pins: right,
                  onTap: onTap,
                  showRestaurantName: showRestaurantName,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static double _aspectRatioFor(
    HomePostModel post,
    int index, {
    required bool viral,
  }) {
    if (viral) {
      const viralRatios = [0.58, 0.64, 0.60, 0.70];
      return viralRatios[index % viralRatios.length];
    }
    if (ExploreMediaMapper.isVideo(post)) {
      const reelRatios = [0.62, 0.70, 0.58, 0.66];
      return reelRatios[index % reelRatios.length];
    }
    if (post.media.length > 1) {
      const carouselRatios = [0.78, 0.92, 0.72, 0.84];
      return carouselRatios[index % carouselRatios.length];
    }
    const photoRatios = [
      0.82,
      1.08,
      0.68,
      0.94,
      0.74,
      1.16,
      0.64,
      0.88,
      1.02,
      0.76,
    ];
    return photoRatios[index % photoRatios.length];
  }
}

class _PinLayout {
  const _PinLayout({
    required this.post,
    required this.height,
    required this.isViral,
  });

  final HomePostModel post;
  final double height;
  final bool isViral;
}

class _PinColumn extends StatelessWidget {
  const _PinColumn({
    required this.pins,
    this.onTap,
    this.showRestaurantName = false,
  });

  final List<_PinLayout> pins;
  final ValueChanged<HomePostModel>? onTap;
  final bool showRestaurantName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < pins.length; i++) ...[
          if (i > 0) const SizedBox(height: ExploreMediaGrid.gap),
          _ExplorePinCard(
            post: pins[i].post,
            height: pins[i].height,
            isViral: pins[i].isViral,
            onTap: onTap,
            showRestaurantName: showRestaurantName,
          ),
        ],
      ],
    );
  }
}

class _ExplorePinCard extends StatelessWidget {
  const _ExplorePinCard({
    required this.post,
    required this.height,
    required this.isViral,
    this.onTap,
    this.showRestaurantName = false,
  });

  final HomePostModel post;
  final double height;
  final bool isViral;
  final ValueChanged<HomePostModel>? onTap;
  final bool showRestaurantName;

  @override
  Widget build(BuildContext context) {
    final cover = ExploreMediaMapper.coverUrl(post);
    final video = ExploreMediaMapper.isVideo(post);
    final pageCount = post.media.length > 1 ? post.media.length : 0;
    final restaurant = showRestaurantName
        ? ExploreMediaMapper.restaurantLabel(post)
        : '';
    const radius = BorderRadius.all(
      Radius.circular(ExploreMediaGrid.radius),
    );

    return GestureDetector(
      onTap: onTap == null ? null : () => onTap!(post),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE8E4E3),
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(47, 47, 46, 0.08),
                blurRadius: 18,
                offset: Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              fit: StackFit.expand,
              children: [
                cover.isEmpty
                    ? const ColoredBox(
                        color: Color(0xFFE8E4E3),
                        child: Center(
                          child: AppHeroIconData(
                            Icons.image_outlined,
                            color: AppColors.hintText,
                          ),
                        ),
                      )
                    : AppCachedImage(
                        imageUrl: cover,
                        fit: BoxFit.cover,
                      ),
                if (isViral)
                  const Positioned(
                    top: 10,
                    left: 10,
                    child: _ViralBadge(),
                  ),
                if (video)
                  const Positioned(
                    top: 10,
                    right: 10,
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white,
                      size: 26,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                if (pageCount > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: restaurant.isEmpty ? 10 : 36,
                    child: _PinDots(count: pageCount > 5 ? 5 : pageCount),
                  ),
                if (restaurant.isNotEmpty)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _RestaurantNameBar(name: restaurant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantNameBar extends StatelessWidget {
  const _RestaurantNameBar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0x00000000),
            Color(0x99000000),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
        child: Row(
          children: [
            const Icon(
              Icons.storefront_rounded,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.beVietnam(
                  size: 11,
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViralBadge extends StatelessWidget {
  const _ViralBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            'Trending',
            style: AppFonts.beVietnam(
              size: 10,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: i == 0 ? 6 : 5,
            height: i == 0 ? 6 : 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: i == 0 ? 0.95 : 0.45),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
