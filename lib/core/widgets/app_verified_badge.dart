import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';
import '../utils/verified_flag.dart';

class AppVerifiedBadge extends StatelessWidget {
  const AppVerifiedBadge({
    super.key,
    this.size = 16,
    this.color = AppColors.primary,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.verified_rounded, size: size, color: color);
  }
}

class VerifiedBadgeSlot extends StatelessWidget {
  const VerifiedBadgeSlot({
    super.key,
    this.username,
    this.fallback = false,
    this.size = 14,
    this.spacing = 4,
    this.color = AppColors.primary,
  });

  final String? username;
  final bool fallback;
  final double size;
  final double spacing;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      VerifiedBadgeCache.revision.value;
      if (!VerifiedBadgeCache.shown(username: username, fallback: fallback)) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: EdgeInsets.only(left: spacing),
        child: AppVerifiedBadge(size: size, color: color),
      );
    });
  }
}

class AppVerifiedName extends StatelessWidget {
  const AppVerifiedName({
    super.key,
    required this.name,
    this.username,
    this.isVerified = false,
    this.style,
    this.badgeSize = 14,
    this.maxLines = 1,
    this.textAlign,
  });

  final String name;
  final String? username;
  final bool isVerified;
  final TextStyle? style;
  final double badgeSize;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      VerifiedBadgeCache.revision.value;
      final show = VerifiedBadgeCache.shown(
        username: username,
        fallback: isVerified,
      );
      final nameText = Text(
        name,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style,
      );
      if (!show) {
        return nameText;
      }

      final badge = Padding(
        padding: EdgeInsets.only(left: badgeSize * 0.25),
        child: AppVerifiedBadge(size: badgeSize),
      );

      return LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedWidth) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [nameText, badge],
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: nameText),
              badge,
            ],
          );
        },
      );
    });
  }

  static List<InlineSpan> inlineSpans({
    required String name,
    String? username,
    bool isVerified = false,
    required TextStyle style,
    double badgeSize = 13,
    String suffix = '',
    TextStyle? suffixStyle,
  }) {
    final show = VerifiedBadgeCache.shown(
      username: username,
      fallback: isVerified,
    );
    return [
      TextSpan(text: name, style: style),
      if (show)
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(left: 3, right: 3),
            child: Icon(
              Icons.verified_rounded,
              size: badgeSize,
              color: AppColors.primary,
            ),
          ),
        ),
      if (suffix.isNotEmpty)
        TextSpan(text: suffix, style: suffixStyle ?? style),
    ];
  }
}
