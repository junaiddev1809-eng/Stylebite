import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'app_cached_image.dart';
import 'app_hero_icon.dart';

/// Circular user avatar with a person-icon fallback when the DP is missing
/// or fails to load. Prefer this over raw [AppCachedImage] / [CircleAvatar]
/// for any profile photo in the app.
class AppUserAvatar extends StatelessWidget {
  const AppUserAvatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.iconSize,
    this.backgroundColor,
    this.iconColor,
    this.memCacheWidth,
  });

  final String imageUrl;
  final double size;
  final double? iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final int? memCacheWidth;

  static bool hasUsableUrl(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return false;
    }
    final lower = value.toLowerCase();
    return lower != 'null' && lower != 'undefined';
  }

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.chip;
    final fg = iconColor ?? AppColors.hintText;
    final resolvedIconSize = iconSize ?? (size * 0.5);
    final url = imageUrl.trim();

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: hasUsableUrl(url)
            ? AppCachedImage(
                imageUrl: url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: memCacheWidth ?? (size * 3).round(),
                fallbackIcon: Icons.person_rounded,
                fallbackBackgroundColor: bg,
                fallbackIconColor: fg,
              )
            : ColoredBox(
                color: bg,
                child: Center(
                  child: AppHeroIconData(
                    Icons.person_rounded,
                    color: fg,
                    size: resolvedIconSize,
                  ),
                ),
              ),
      ),
    );
  }
}
