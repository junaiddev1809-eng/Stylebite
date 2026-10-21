import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../post/utils/post_detail_open_helper.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../controllers/contest_controller.dart';
import '../models/contest_detail_model.dart';
import '../models/contest_prize.dart';
import '../models/contest_ranking_model.dart';

class ContestRankingScreen extends StatefulWidget {
  const ContestRankingScreen({super.key});

  @override
  State<ContestRankingScreen> createState() => _ContestRankingScreenState();
}

class _ContestRankingScreenState extends State<ContestRankingScreen> {
  late final ContestController _controller;
  late final int _contestId;
  final RxString _query = ''.obs;
  final RxString _filter = 'all'.obs;
  final TextEditingController _searchController = TextEditingController();
  final RxSet<int> _openingPostUserIds = <int>{}.obs;
  Timer? _liveRefreshTimer;
  Timer? _uiTicker;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ContestController>()
        ? Get.find<ContestController>()
        : Get.put(ContestController());
    final args = Get.arguments is Map<String, dynamic>
        ? Get.arguments as Map<String, dynamic>
        : const <String, dynamic>{};
    _contestId = (args['contestId'] as int?) ?? 0;

    _uiTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _contestId <= 0) {
        return;
      }
      _controller.fetchDetail(_contestId);
      _liveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_contestId > 0 && mounted) {
          _controller.fetchDetail(_contestId);
        }
      });
    });
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    _uiTicker?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Leaderboard')),
      body: Obx(() {
        final contest = _controller.selectedContestDetail.value;
        if (_controller.isDetailLoading.value && contest == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (contest == null) {
          return const Center(child: Text('Contest not found'));
        }

        // Ranks are numbered over the full live leaderboard so a searched
        // user keeps their real position; search/Top-N only trim the list.
        final ranked = _buildLeaderboard(contest);
        final rankByKey = <String, int>{
          for (var i = 0; i < ranked.length; i++) _rankKey(ranked[i]): i + 1,
        };
        final visible = _applyFilters(_applyQuery(ranked));
        final liveCount = contest.liveParticipantCount;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => _query.value = value,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search contest participants',
                      prefixIcon: const AppHeroIconData(Icons.search_rounded),
                      suffixIcon: _query.value.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _query.value = '';
                              },
                              icon: const AppHeroIconData(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF0EEED),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _chip('all', 'All'),
                      const SizedBox(width: 8),
                      _chip('top10', 'Top 10'),
                      const SizedBox(width: 8),
                      _chip('top50', 'Top 50'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _controller.fetchDetail(_contestId),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    _rewardCard(contest),
                    const SizedBox(height: 12),
                    _countdownCard(contest),
                    const SizedBox(height: 12),
                    _summaryCard(contest, liveCount, visible.length),
                    const SizedBox(height: 12),
                    if (visible.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          'No leaderboard entries found.',
                          style: AppFonts.beVietnam(
                            size: 13,
                            color: AppColors.hintText,
                          ),
                        ),
                      )
                    else
                      ...visible.map(
                        (item) => _participantTile(
                          item,
                          displayRank: rankByKey[_rankKey(item)] ?? 0,
                          contest: contest,
                        ),
                      ),
                    if (contest.teamRanking.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Team Ranking',
                        style: AppFonts.plusJakarta(
                          size: 18,
                          weight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...contest.teamRanking.map((team) => _teamTile(team)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  /// Live participants in leaderboard order. The server's `rank_position`
  /// is only used for ordering — it can have gaps once entries are removed,
  /// so the number shown to users is the position in this list.
  List<ContestRankingModel> _buildLeaderboard(ContestDetailModel contest) {
    final items = contest.liveParticipantsRanking.toList(growable: false);

    items.sort((a, b) {
      final rankA = a.rankPosition ?? a.rank;
      final rankB = b.rankPosition ?? b.rank;
      if (rankA > 0 && rankB > 0 && rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.username.toLowerCase().compareTo(b.username.toLowerCase());
    });

    return items;
  }

  List<ContestRankingModel> _applyQuery(List<ContestRankingModel> items) {
    final query = _query.value.trim().toLowerCase();
    if (query.isEmpty) {
      return items;
    }
    final contest = _controller.selectedContestDetail.value;
    final namesByUser = <int, String>{
      for (final submission in contest?.visibleSubmissions ?? const [])
        if (submission.userId > 0) submission.userId: submission.fullName,
    };
    return items.where((item) {
      if (item.username.toLowerCase().contains(query)) {
        return true;
      }
      if (item.city.toLowerCase().contains(query)) {
        return true;
      }
      final fullName = namesByUser[item.userId]?.toLowerCase() ?? '';
      return fullName.contains(query);
    }).toList(growable: false);
  }

  String _rankKey(ContestRankingModel item) => item.userId > 0
      ? 'u:${item.userId}'
      : 'n:${item.username.trim().toLowerCase()}';

  List<ContestRankingModel> _applyFilters(List<ContestRankingModel> items) {
    return switch (_filter.value) {
      'top10' => items.take(10).toList(growable: false),
      'top50' => items.take(50).toList(growable: false),
      _ => items,
    };
  }

  Widget _chip(String key, String label) {
    final active = _filter.value == key;
    return InkWell(
      onTap: () => _filter.value = key,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFFF0EEED),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: AppFonts.plusJakarta(
            size: 13,
            weight: FontWeight.w700,
            color: active ? Colors.white : AppColors.hintText,
          ),
        ),
      ),
    );
  }

  Widget _rewardCard(ContestDetailModel contest) {
    if (!contest.hasReward) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            contest.prizes.length > 1 ? '🎁 Prize pool' : '🎁 Today\'s Prize',
            style: AppFonts.beVietnam(size: 13, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'PKR ${contest.rewardAmount.toStringAsFixed(0)}',
            style: AppFonts.plusJakarta(
              size: 46,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            contest.prizes.length > 1
                ? contest.prizes
                    .map((prize) => '${prize.placeLabel} ${prize.amountLabel}')
                    .join('  ·  ')
                : contest.prizes.length == 1
                    ? '1 winner${contest.prizes.first.winner.isEmpty ? '' : ' · @${contest.prizes.first.winner}'}'
                    : 'Winner gets cash + featured badge',
            style: AppFonts.beVietnam(
              size: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countdownCard(ContestDetailModel contest) {
    final now = DateTime.now();
    
    // Fallback: Check all possible end dates to find the future one
    final dates = [
      contest.endAt,
      contest.votingEndAt,
      contest.enrollmentEndAt,
    ].whereType<DateTime>().where((d) => d.isAfter(now)).toList();
    
    dates.sort(); // Closest future date
    
    final target = dates.isNotEmpty ? dates.first : null;

    if (target == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppHeroIconData(
              Icons.event_available_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Contest Ended',
              style: AppFonts.plusJakarta(
                size: 24,
                weight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ],
        ),
      );
    }

    final diff = target.difference(now);
    final safe = diff.isNegative ? Duration.zero : diff;
    
    final days = safe.inDays;
    final hours = safe.inHours.remainder(24);
    final mins = safe.inMinutes.remainder(60);
    final secs = safe.inSeconds.remainder(60);

    Widget box(String val, String label) {
      return Expanded(
        child: Column(
          children: [
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF0EEED),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Text(
                val,
                style: AppFonts.plusJakarta(
                  size: days > 0 ? 36 : 44,
                  weight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppFonts.beVietnam(size: 11, color: AppColors.hintText),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppHeroIconData(
                Icons.access_time_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Next Deadline In',
                style: AppFonts.plusJakarta(size: 24, weight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (days > 0) ...[
                box(days.toString().padLeft(2, '0'), 'Days'),
                const SizedBox(width: 8),
              ],
              box(hours.toString().padLeft(2, '0'), 'Hours'),
              const SizedBox(width: 8),
              box(mins.toString().padLeft(2, '0'), 'Mins'),
              const SizedBox(width: 8),
              box(secs.toString().padLeft(2, '0'), 'Secs'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(
    ContestDetailModel contest,
    int participantCount,
    int visibleCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryStat('Participants', '$participantCount'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _summaryStat('Entries', '${contest.visibleSubmissions.length}'),
          ),
          const SizedBox(width: 12),
          Expanded(child: _summaryStat('Shown', '$visibleCount')),
        ],
      ),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.beVietnam(size: 12, color: AppColors.hintText),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppFonts.plusJakarta(size: 22, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _participantTile(
    ContestRankingModel item, {
    required int displayRank,
    required ContestDetailModel contest,
  }) {
    final rankLabel = displayRank > 0
        ? displayRank
        : (item.rankPosition ?? item.rank);
    final avatarUrl = item.avatarUrl.trim().isNotEmpty
        ? item.avatarUrl
        : _avatarFallbackFromSubmission(contest, item.userId, item.username);
    final username = item.username.trim().isNotEmpty
        ? item.username
        : 'Unknown';
    final score = item.score.toStringAsFixed(1);
    final isOpening = _openingPostUserIds.contains(item.userId);

    final avatar = CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: AppFonts.plusJakarta(
                weight: FontWeight.w800,
                color: AppColors.primary,
              ),
            )
          : null,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFE2DD)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isOpening ? null : () => _openParticipantPost(item, contest),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openParticipantProfile(item, avatarUrl),
                  child: avatar,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _openParticipantProfile(item, avatarUrl),
                              child: Text(
                                username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.plusJakarta(
                                  size: 16,
                                  weight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              rankLabel > 0
                                  ? contestPlaceStanding(rankLabel)
                                  : 'Unranked',
                              style: AppFonts.beVietnam(
                                size: 12,
                                weight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.city.isNotEmpty ? item.city : 'Contest participant',
                        style: AppFonts.beVietnam(
                          size: 12,
                          color: AppColors.hintText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isOpening)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        score,
                        style: AppFonts.plusJakarta(
                          size: 18,
                          weight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        'Score',
                        style: AppFonts.beVietnam(
                          size: 11,
                          color: AppColors.hintText,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openParticipantProfile(ContestRankingModel item, String avatarUrl) {
    final username = ProfileOpenHelper.normalizeUsername(item.username);
    if (username.isEmpty || username.toLowerCase() == 'unknown') {
      errorSnackBar(message: 'Profile not available.');
      return;
    }
    ProfileOpenHelper.open(username: username, avatarUrl: avatarUrl);
  }

  /// Resolves the participant's submitted post: prefer the `post_id` sent
  /// with the ranking row, otherwise fall back to the matching submission
  /// (older API payloads only expose it there).
  int _resolveParticipantPostId(
    ContestRankingModel item,
    ContestDetailModel contest,
  ) {
    final direct = item.postId ?? 0;
    if (direct > 0) {
      return direct;
    }
    final normalizedName = item.username.trim().toLowerCase();
    for (final submission in contest.submissions) {
      final sameUser = item.userId > 0 && submission.userId == item.userId;
      final sameName = normalizedName.isNotEmpty &&
          submission.username.trim().toLowerCase() == normalizedName;
      if ((sameUser || sameName) && submission.postId > 0) {
        return submission.postId;
      }
    }
    return 0;
  }

  Future<void> _openParticipantPost(
    ContestRankingModel item,
    ContestDetailModel contest,
  ) async {
    if (_openingPostUserIds.contains(item.userId)) {
      return;
    }
    final postId = _resolveParticipantPostId(item, contest);
    if (postId <= 0) {
      errorSnackBar(message: 'This entry\'s post is not available.');
      return;
    }
    _openingPostUserIds.add(item.userId);
    try {
      await PostDetailOpenHelper.openById(postId.toString());
    } finally {
      _openingPostUserIds.remove(item.userId);
    }
  }

  Widget _teamTile(ContestRankingModel team) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFEFE2DD)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const AppHeroIconData(
              Icons.groups_rounded,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.city.isNotEmpty ? team.city : 'Team',
                  style: AppFonts.plusJakarta(
                    size: 15,
                    weight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Members ${team.memberCount}',
                  style: AppFonts.beVietnam(
                    size: 12,
                    color: AppColors.hintText,
                  ),
                ),
              ],
            ),
          ),
          Text(
            team.score.toStringAsFixed(1),
            style: AppFonts.plusJakarta(size: 15, weight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  String _avatarFallbackFromSubmission(
    ContestDetailModel contest,
    int userId,
    String username,
  ) {
    final match = contest.participantsRanking.where((item) {
      if (item.userId == userId) {
        return true;
      }
      return item.username.trim().toLowerCase() ==
          username.trim().toLowerCase();
    });
    return match.isNotEmpty ? match.first.avatarUrl : '';
  }
}
