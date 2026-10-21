import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../models/contest_model.dart';

class CommunityContestSection extends StatelessWidget {
  const CommunityContestSection({
    super.key,
    required this.contests,
    required this.onOpenContest,
  });

  final List<ContestModel> contests;
  final ValueChanged<ContestModel> onOpenContest;

  @override
  Widget build(BuildContext context) {
    final sortedContests = [...contests]
      ..sort((a, b) {
        if (a.featured == b.featured) return 0;
        return a.featured ? -1 : 1;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Community Contests',
              style: AppFonts.plusJakarta(size: 25, weight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {},
              icon: const AppHeroIconData(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          itemCount: sortedContests.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemBuilder: (context, index) {
            final contest = sortedContests[index];
            return _CommunityCard(
              contest: contest,
              onOpenContest: onOpenContest,
            );
          },
        ),
      ],
    );
  }
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard({required this.contest, required this.onOpenContest});

  final ContestModel contest;
  final ValueChanged<ContestModel> onOpenContest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      contest.ended ? Colors.grey : Colors.transparent,
                      contest.ended ? BlendMode.saturation : BlendMode.dst,
                    ),
                    child: Image.network(contest.imageUrl, fit: BoxFit.cover),
                  ),
                  if (contest.ended)
                    Container(
                      color: Colors.black.withValues(alpha: 0.38),
                      alignment: Alignment.center,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'ENDED',
                          style: AppFonts.beVietnam(
                            size: 10,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (contest.featured)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 11,
                              color: AppColors.text,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'FEATURED',
                              style: AppFonts.beVietnam(
                                size: 9,
                                weight: FontWeight.w800,
                                color: AppColors.text,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            contest.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.beVietnam(size: 14, weight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (contest.badges.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    contest.badges.first,
                    style: AppFonts.beVietnam(
                      size: 10,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const Spacer(),
              Text(
                contest.timeLabel,
                style: AppFonts.beVietnam(
                  size: 10,
                  weight: FontWeight.w700,
                  color: AppColors.hintText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onOpenContest(contest),
              style: OutlinedButton.styleFrom(
                foregroundColor: contest.ended
                    ? AppColors.hintText
                    : AppColors.primary,
                side: BorderSide(
                  color: contest.ended
                      ? AppColors.hintText.withValues(alpha: 0.3)
                      : AppColors.primary,
                ),
              ),
              child: Text(
                contest.primaryCta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
