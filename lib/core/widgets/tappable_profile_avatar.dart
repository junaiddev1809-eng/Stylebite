import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_cached_image.dart';
import 'app_hero_icon.dart';

class TappableProfileAvatar extends StatelessWidget {
  const TappableProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.size = 96,
    this.showBorder = true,
  });

  final String imageUrl;
  final String heroTag;
  final double size;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = imageUrl.trim().isNotEmpty;
    final photoSize = showBorder ? size - 5 : size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasPhoto
          ? () => AvatarPreviewScreen.open(
              context,
              imageUrl: imageUrl,
              heroTag: heroTag,
            )
          : null,
      child: Container(
        width: size,
        height: size,
        padding: showBorder ? const EdgeInsets.all(2.5) : EdgeInsets.zero,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(color: AppColors.primary, width: 2)
              : null,
        ),
        child: hasPhoto
            ? Hero(
                tag: heroTag,
                createRectTween: (begin, end) =>
                    MaterialRectArcTween(begin: begin, end: end),
                flightShuttleBuilder:
                    (context, animation, direction, fromContext, toContext) {
                      return ClipOval(
                        child: AppCachedImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                      );
                    },
                child: Material(
                  type: MaterialType.transparency,
                  child: _CirclePhoto(imageUrl: imageUrl, size: photoSize),
                ),
              )
            : ClipOval(
                child: ColoredBox(
                  color: const Color(0xFFE9E3E1),
                  child: Center(
                    child: AppHeroIconData(
                      Icons.person_rounded,
                      color: AppColors.text,
                      size: size * 0.35,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class AvatarPreviewScreen extends StatelessWidget {
  const AvatarPreviewScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    required this.animation,
  });

  final String imageUrl;
  final String heroTag;
  final Animation<double> animation;

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    required String heroTag,
  }) {
    if (imageUrl.trim().isEmpty) {
      return Future<void>.value();
    }

    return Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 340),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AvatarPreviewScreen(
            imageUrl: imageUrl,
            heroTag: heroTag,
            animation: animation,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final photoSize = (size.shortestSide - 48).clamp(220.0, 420.0);
    final fade = animation.drive(CurveTween(curve: Curves.easeOutCubic));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: AnimatedBuilder(
        animation: fade,
        builder: (context, child) {
          return Scaffold(
            backgroundColor: Colors.black.withValues(alpha: 0.86 * fade.value),
            body: child,
          );
        },
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Hero(
                  tag: heroTag,
                  createRectTween: (begin, end) =>
                      MaterialRectArcTween(begin: begin, end: end),
                  child: Material(
                    type: MaterialType.transparency,
                    child: _CirclePhoto(imageUrl: imageUrl, size: photoSize),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 8,
                child: FadeTransition(
                  opacity: fade,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const AppHeroIconData(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CirclePhoto extends StatelessWidget {
  const _CirclePhoto({required this.imageUrl, required this.size});

  final String imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: AppCachedImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
