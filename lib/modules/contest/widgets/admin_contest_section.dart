import 'package:flutter/material.dart';

import '../models/contest_model.dart';
import 'contest_list_tile.dart';

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

    final sorted = [...contests]..sort(compareContestListOrder);

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          ContestListTile(
            contest: sorted[i],
            onOpenContest: onOpenContest,
            onViewLeaderboard: onViewLeaderboard,
          ),
        ],
      ],
    );
  }
}
