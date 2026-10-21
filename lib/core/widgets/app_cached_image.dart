import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../media/app_cache_manager.dart';
import 'states/app_shimmer_box.dart';

class AppCachedImage extends StatelessWidget {
  const AppCachedImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.memCacheWidth,
    this.memCacheHeight,
    this.filterQuality = FilterQuality.low,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    if (width != null ||
        height != null ||
        memCacheWidth != null ||
        memCacheHeight != null) {
      return _buildImage(width, height);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : null;
        final resolvedHeight =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : null;
        return _buildImage(resolvedWidth, resolvedHeight);
      },
    );
  }

  Widget _buildImage(double? resolvedWidth, double? resolvedHeight) {
    final decode = _aspectSafeDecode(
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      layoutWidth: resolvedWidth,
      layoutHeight: resolvedHeight,
    );

    Widget child;
    if (imageUrl.trim().isEmpty) {
      child = _FallbackBox(
        icon: Icons.image_not_supported_outlined,
        width: resolvedWidth,
        height: resolvedHeight,
      );
    } else {
      child = CachedNetworkImage(
        imageUrl: imageUrl,
        fit: fit,
        width: resolvedWidth,
        height: resolvedHeight,
        memCacheWidth: decode.width,
        memCacheHeight: decode.height,
        filterQuality: filterQuality,
        cacheManager: AppImageCacheManager.instance,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholderFadeInDuration: Duration.zero,
        placeholder: (context, url) => _PlaceholderBox(
          width: resolvedWidth,
          height: resolvedHeight,
          borderRadius: borderRadius,
        ),
        errorWidget: (context, url, error) => _FallbackBox(
          icon: Icons.broken_image_outlined,
          width: resolvedWidth,
          height: resolvedHeight,
        ),
        imageBuilder: (context, imageProvider) {
          return SizedBox.expand(
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: imageProvider,
                  fit: fit,
                  alignment: Alignment.center,
                  filterQuality: filterQuality,
                ),
              ),
            ),
          );
        },
      );
    }

    if (resolvedWidth != null || resolvedHeight != null) {
      child = SizedBox(
        width: resolvedWidth,
        height: resolvedHeight,
        child: child,
      );
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }

    return child;
  }

  /// Decode using only one axis so Flutter does not resample the bitmap
  /// to a different aspect ratio (which looks like stretch/shrink).
  static ({int? width, int? height}) _aspectSafeDecode({
    int? memCacheWidth,
    int? memCacheHeight,
    double? layoutWidth,
    double? layoutHeight,
  }) {
    var width = memCacheWidth;
    var height = memCacheHeight;
    if (width == null && height == null) {
      final dpr = 3.0;
      if (layoutWidth != null && layoutWidth.isFinite && layoutWidth > 0) {
        width = (layoutWidth * dpr).round();
      } else if (layoutHeight != null &&
          layoutHeight.isFinite &&
          layoutHeight > 0) {
        height = (layoutHeight * dpr).round();
      }
    }
    if (width != null && height != null) {
      if (width >= height) {
        return (width: width, height: null);
      }
      return (width: null, height: height);
    }
    return (width: width, height: height);
  }
}

class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return AppShimmerBox(
      width: width,
      height: height,
      borderRadius: borderRadius ?? BorderRadius.zero,
    );
  }
}

class _FallbackBox extends StatelessWidget {
  const _FallbackBox({
    required this.icon,
    required this.width,
    required this.height,
  });

  final IconData icon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFECEC),
      child: SizedBox(
        width: width,
        height: height,
        child: Center(child: AppHeroIconData(icon)),
      ),
    );
  }
}
