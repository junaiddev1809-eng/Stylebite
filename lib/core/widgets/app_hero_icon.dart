import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

class AppHeroIconData extends StatelessWidget {
  const AppHeroIconData(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.style,
  });

  final Object icon;
  final double? size;
  final Color? color;
  final HeroIconStyle? style;

  @override
  Widget build(BuildContext context) {
    if (icon is HeroIcons) {
      return HeroIcon(
        icon as HeroIcons,
        size: size,
        color: color,
        style: style ?? HeroIconStyle.outline,
      );
    }

    return Icon(
      icon as IconData,
      size: size,
      color: color,
      semanticLabel: null,
    );
  }
}
