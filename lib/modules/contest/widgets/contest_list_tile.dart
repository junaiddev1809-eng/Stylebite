import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../models/contest_model.dart';

/// Horizontal contest row: cover on the left, details on the right.
/// Used for live, upcoming, and ended contests on the Contest tab.
class ContestListTile extends StatelessWidget {
  const ContestListTile({
    super.key,
    required this.contest,
    required this.onOpenContest,
    this.onViewLeaderboard,
  });

  final ContestModel contest;
  final ValueChanged<ContestModel> onOpenContest;
  final ValueChanged<int>? onViewLeaderboard;

  @override
  Widget build(BuildContext context) {
    final badge = contest.badges.isNotEmpty
        ? contest.badges.first
        : contest.statusLabel;
    final ended = contest.ended;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onOpenContest(contest),
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoverThumb(
                  imageUrl: contest.imageUrl,
                  ended: ended,
                  featured: contest.featured,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (badge.trim().isNotEmpty)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: ended
                                      ? AppColors.chip
                                      : AppColors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badge.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.beVietnam(
                                    size: 10,
                                    weight: FontWeight.w700,
                                    color: ended
                                        ? AppColors.hintText
                                        : AppColors.primary,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            contest.timeLabel,
                            style: AppFonts.beVietnam(
                              size: 11,
                              weight: FontWeight.w700,
                              color: AppColors.hintText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        contest.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.plusJakarta(
                          size: 16,
                          weight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      if (contest.subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          contest.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.beVietnam(
                            size: 12,
                            weight: FontWeight.w500,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                      if (contest.participantCount > 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          contest.participantCount == 1
                              ? '1 participant'
                              : '${contest.participantCount} participants',
                          style: AppFonts.beVietnam(
                            size: 11,
                            weight: FontWeight.w600,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: () => onOpenContest(contest),
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: ended
                                      ? AppColors.chip
                                      : AppColors.primary,
                                  foregroundColor: ended
                                      ? AppColors.text
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  textStyle: AppFonts.beVietnam(
                                    size: 12,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                child: Text(
                                  contest.primaryCta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          if (onViewLeaderboard != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: OutlinedButton(
                                  onPressed: () =>
                                      onViewLeaderboard!(contest.id),
                                  style: OutlinedButton.styleFrom(
                                    elevation: 0,
                                    padding: EdgeInsets.zero,
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    textStyle: AppFonts.beVietnam(
                                      size: 12,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                  child: Text(
                                    contest.secondaryCta ?? 'Leaderboard',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({
    required this.imageUrl,
    required this.ended,
    required this.featured,
  });

  final String imageUrl;
  final bool ended;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                ended ? Colors.grey : Colors.transparent,
                ended ? BlendMode.saturation : BlendMode.dst,
              ),
              child: imageUrl.trim().isEmpty
                  ? ColoredBox(
                      color: AppColors.chip,
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: AppColors.primary.withValues(alpha: 0.55),
                      ),
                    )
                  : AppCachedImage(imageUrl: imageUrl, fit: BoxFit.cover),
            ),
            if (ended)
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.34),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'ENDED',
                      style: AppFonts.beVietnam(
                        size: 9,
                        weight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            if (featured && !ended)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '★',
                    style: AppFonts.beVietnam(
                      size: 10,
                      weight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
