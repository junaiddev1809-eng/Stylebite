import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../models/contest_model.dart';

class AdminContestSection extends StatelessWidget {
  const AdminContestSection({
    super.key,
    required this.contests,
    required this.onViewLeaderboard,
    required this.onOpenContest,
  });

  final List<ContestModel> contests;
  final ValueChanged<int> onViewLeaderboard;
  final ValueChanged<ContestModel> onOpenContest;

  @override
  Widget build(BuildContext context) {
    if (contests.isEmpty) {
      return const SizedBox.shrink();
    }

    // Identify featured contest
    final featuredIndex = contests.indexWhere((c) => c.featured);
    final featured = featuredIndex != -1
        ? contests[featuredIndex]
        : contests.first;

    // Identify secondary contest (must be different from featured)
    ContestModel? secondary;
    for (final c in contests) {
      if (c.id != featured.id) {
        secondary = c;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FeaturedContestCard(
          contest: featured,
          onViewLeaderboard: onViewLeaderboard,
          onOpenContest: onOpenContest,
        ),
        if (secondary != null) ...[
          const SizedBox(height: 12),
          _SecondaryContestCard(
            contest: secondary,
            onOpenContest: onOpenContest,
            onViewLeaderboard: onViewLeaderboard,
          ),
        ],
      ],
    );
  }
}

class _FeaturedContestCard extends StatelessWidget {
  const _FeaturedContestCard({
    required this.contest,
    required this.onViewLeaderboard,
    required this.onOpenContest,
  });

  final ContestModel contest;
  final ValueChanged<int> onViewLeaderboard;
  final ValueChanged<ContestModel> onOpenContest;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpenContest(contest),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(47, 47, 46, 0.06),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(contest.imageUrl, fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color.fromRGBO(0, 0, 0, 0.58),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Wrap(
                        spacing: 6,
                        children: contest.badges
                            .take(2)
                            .map((badge) {
                              final isActive = badge.toLowerCase().contains(
                                'active',
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary
                                      : Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  badge,
                                  style: AppFonts.beVietnam(
                                    size: 10,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                    if (contest.featured)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
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
                                size: 12,
                                color: AppColors.text,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'FEATURED',
                                style: AppFonts.beVietnam(
                                  size: 10,
                                  weight: FontWeight.w800,
                                  color: AppColors.text,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 12,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contest.title,
                                  style: AppFonts.plusJakarta(
                                    size: 27,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  contest.subtitle,
                                  style: AppFonts.beVietnam(
                                    size: 12,
                                    weight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.84),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                contest.timeCaption,
                                style: AppFonts.beVietnam(
                                  size: 9,
                                  weight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.62),
                                  letterSpacing: 0.9,
                                ),
                              ),
                              Text(
                                contest.timeLabel,
                                style: AppFonts.plusJakarta(
                                  size: 20,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (contest.participantCount > 0) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.people_alt_rounded,
                          size: 16,
                          color: AppColors.hintText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          contest.participantCount == 1
                              ? '1 participant'
                              : '${contest.participantCount} participants',
                          style: AppFonts.beVietnam(
                            size: 12,
                            weight: FontWeight.w600,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => onOpenContest(contest),
                          child: Text(
                            contest.primaryCta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onViewLeaderboard(contest.id),
                          style: _outlinedButtonStyle,
                          child: Text(
                            contest.secondaryCta ?? 'Leaderboard',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final ButtonStyle _outlinedButtonStyle = OutlinedButton.styleFrom(
  foregroundColor: AppColors.primary,
  side: const BorderSide(color: AppColors.primary),
  shape: const StadiumBorder(),
  padding: const EdgeInsets.symmetric(vertical: 12),
);

class _SecondaryContestCard extends StatelessWidget {
  const _SecondaryContestCard({
    required this.contest,
    required this.onOpenContest,
    required this.onViewLeaderboard,
  });

  final ContestModel contest;
  final ValueChanged<ContestModel> onOpenContest;
  final ValueChanged<int> onViewLeaderboard;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpenContest(contest),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(contest.imageUrl, fit: BoxFit.cover),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Color.fromRGBO(0, 0, 0, 0.45),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contest.title,
                    style: AppFonts.plusJakarta(
                      size: 20,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    contest.timeLabel,
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.hintText,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onOpenContest(contest),
                          style: _outlinedButtonStyle,
                          child: Text(
                            contest.primaryCta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => onViewLeaderboard(contest.id),
                          style: _outlinedButtonStyle,
                          child: const Text(
                            'Leaderboard',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
