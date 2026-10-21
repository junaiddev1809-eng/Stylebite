import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_verified_badge.dart';
import 'post_hashtag_chips.dart';

class CommentsCaptionHeader extends StatelessWidget {
  const CommentsCaptionHeader({
    super.key,
    required this.handle,
    required this.caption,
    this.avatarUrl = '',
    this.username = '',
    this.isVerified = false,
    this.onTapHashtag,
  });

  final String handle;
  final String caption;
  final String avatarUrl;
  final String username;
  final bool isVerified;
  final ValueChanged<String>? onTapHashtag;

  @override
  Widget build(BuildContext context) {
    final text = caption.trim();
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: avatarUrl.trim().isNotEmpty
                  ? AppCachedImage(
                      imageUrl: avatarUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      memCacheWidth: 108,
                    )
                  : ColoredBox(
                      color: const Color(0xFFE9E3E1),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: AppHeroIconData(
                            Icons.person_rounded,
                            size: 18,
                            color: AppColors.hintText,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.plusJakarta(
                            size: 14,
                            weight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      VerifiedBadgeSlot(
                        username: username,
                        fallback: isVerified,
                        size: 14,
                        spacing: 4,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  HashtagCaptionText(
                    text: text,
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w500,
                      height: 1.4,
                      color: AppColors.text,
                    ),
                    onTapHashtag: onTapHashtag,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: Color(0xFFE7E2E0)),
        const SizedBox(height: 12),
      ],
    );
  }
}
