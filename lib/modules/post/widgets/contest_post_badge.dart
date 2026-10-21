import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/widgets/app_hero_icon.dart';

/// Small circular trophy marker shown on media of contest-enrolled posts.
class ContestTrophyBadge extends StatelessWidget {
  const ContestTrophyBadge({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: AppHeroIconData(
        Icons.emoji_events_rounded,
        size: size * 0.58,
        color: const Color(0xFFD9A400),
      ),
    );
  }
}

/// Compact tag with the contest name. Tapping it opens the contest page.
class ContestNameTag extends StatelessWidget {
  const ContestNameTag({
    super.key,
    required this.contestId,
    required this.contestTitle,
    this.maxWidth = 160,
  });

  final int contestId;
  final String contestTitle;
  final double maxWidth;

  static void openContest(int contestId) {
    if (contestId <= 0) {
      errorSnackBar(message: 'Contest not available.');
      return;
    }
    Get.toNamed(AppRoutes.contestDetail, arguments: {'contestId': contestId});
  }

  @override
  Widget build(BuildContext context) {
    final title = contestTitle.trim().isEmpty ? 'Contest' : contestTitle.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => openContest(contestId),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppHeroIconData(
                Icons.emoji_events_rounded,
                size: 12,
                color: Color(0xFFFFD54F),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              const AppHeroIconData(
                Icons.chevron_right_rounded,
                size: 13,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
