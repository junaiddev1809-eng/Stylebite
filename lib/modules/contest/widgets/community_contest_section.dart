import 'package:flutter/material.dart';

import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../models/contest_model.dart';
import 'contest_list_tile.dart';

class CommunityContestSection extends StatelessWidget {
  const CommunityContestSection({
    super.key,
    required this.contests,
    required this.onOpenContest,
    this.onViewLeaderboard,
  });

  final List<ContestModel> contests;
  final ValueChanged<ContestModel> onOpenContest;
  final ValueChanged<int>? onViewLeaderboard;

  @override
  Widget build(BuildContext context) {
    final sortedContests = [...contests]..sort(compareContestListOrder);

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
        for (var i = 0; i < sortedContests.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          ContestListTile(
            contest: sortedContests[i],
            onOpenContest: onOpenContest,
            onViewLeaderboard: onViewLeaderboard,
          ),
        ],
      ],
    );
  }
}
