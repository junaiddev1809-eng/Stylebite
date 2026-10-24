import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:stylebite/modules/post/widgets/feed_post_card.dart';
import 'package:get/get.dart' hide FormData;

import '../../../core/media/media_picker_service.dart';
import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/picked_media.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_time_formatter.dart';
import '../../../core/widgets/app_media_source_sheet.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../home/models/home_post_model.dart';
import '../../post/services/post_interaction_store.dart';
import '../../post/utils/rating_math.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../profile/models/profile_model.dart';
import '../../reports/widgets/report_reason_sheet.dart';
import '../api/contest_api.dart';
import '../controllers/contest_controller.dart';
import '../models/contest_detail_model.dart';
import '../models/contest_prize.dart';
import '../models/contest_submission_model.dart';
import 'contest_ranking_screen.dart';

class ContestDetailScreen extends StatefulWidget {
  const ContestDetailScreen({super.key, this.contestKey, this.sourceLabel});

  final String? contestKey;
  final String? sourceLabel;

  @override
  State<ContestDetailScreen> createState() => _ContestDetailScreenState();
}

class _ContestDetailScreenState extends State<ContestDetailScreen> {
  late final ContestController _controller;
  late final int _contestId;
  Timer? _liveRefreshTimer;
  Worker? _interactionWorker;
  final Set<String> _participantLikeLoadingIds = <String>{};
  final Set<String> _participantShareLoadingIds = <String>{};
  // Viewer's own rating per submission id — set optimistically on tap so the
  // selector reflects the given score immediately, then kept in sync with
  // the server's `viewer_score` on refresh.
  final Map<int, int> _viewerRatingOverrides = <int, int>{};
  final Map<int, double> _ratingAverageOverrides = <int, double>{};
  final Map<int, double> _totalScoreOverrides = <int, double>{};
  final Map<int, int> _voteCountOverrides = <int, int>{};
  final Map<int, _ContestRatingSnapshot> _ratingSnapshots =
      <int, _ContestRatingSnapshot>{};
  final Set<int> _votingSubmissionIds = <int>{};
  final Map<int, int> _pendingVotes = <int, int>{};
  final Map<int, int> _committedRatings = <int, int>{};
  final List<int> _pinnedFeedIds = <int>[];
  final TextEditingController _participantSearchController =
      TextEditingController();
  final RxString _participantQuery = ''.obs;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ContestController>()
        ? Get.find<ContestController>()
        : Get.put(ContestController());

    final args = Get.arguments is Map<String, dynamic>
        ? Get.arguments as Map<String, dynamic>
        : const <String, dynamic>{};
    _contestId =
        (args['contestId'] as int?) ??
        int.tryParse(widget.contestKey ?? '') ??
        0;
    final participantQuery = (args['participantQuery'] ?? '').toString().trim();
    if (participantQuery.isNotEmpty) {
      _participantSearchController.text = participantQuery;
      _participantQuery.value = participantQuery;
    }
    if (_contestId > 0) {
      _interactionWorker = ever(PostInteractionStore.ensure().revision, (_) {
        if (mounted) {
          setState(() {});
        }
      });
      _controller.fetchDetail(_contestId);
      _liveRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (!mounted) {
          return;
        }
        unawaited(_refreshContest(reorder: false));
      });
    }
  }

  @override
  void dispose() {
    _interactionWorker?.dispose();
    _liveRefreshTimer?.cancel();
    _participantSearchController.dispose();
    super.dispose();
  }

  Future<void> _reportContest(int contestId) async {
    final result = await showReportReasonSheet(
      context,
      title: 'Report contest',
    );
    if (result == null) {
      return;
    }
    await _controller.reportContest(
      contestId,
      result.reasonCode,
      result.details,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Obx(() {
        final contest = _controller.selectedContestDetail.value;
        if (_controller.isDetailLoading.value && contest == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (contest == null) {
          return const AppEmptyState(
            title: 'Contest unavailable',
            subtitle:
                'This contest is unavailable or no longer exists.',
            icon: Icons.lock_outline_rounded,
          );
        }

        return Column(
          children: [
            ColoredBox(
              color: AppColors.background,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  child: Row(
                    children: [
                      _FloatingCircleButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: AppBackNavigation.handleBack,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _participantSearchField()),
                      const SizedBox(width: 8),
                      _FloatingCircleButton(
                        icon: Icons.flag_outlined,
                        onTap: () => _reportContest(contest.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refreshContest(reorder: true),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppCachedImage(
                              imageUrl: contest.coverImageUrl,
                              fit: BoxFit.cover,
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Color(0xE6000000),
                                    Color(0xCC000000),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                            if (contest.featured)
                              Positioned(
                                top: 16,
                                right: 16,
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
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _Chip(
                                        text: contest.statusLabel,
                                        dark: true,
                                      ),
                                      _Chip(text: contest.typeLabel, dark: true),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    contest.title,
                                    style: AppFonts.plusJakarta(
                                      size: 28,
                                      weight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    contest.subtitle,
                                    style: AppFonts.beVietnam(
                                      size: 13,
                                      color: Colors.white.withValues(alpha: 0.88),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _surface(
                            child: Column(
                              children: [
                                Builder(
                                  builder: (_) {
                                    final alreadyJoined = contest
                                        .visibleSubmissions
                                        .any((item) => item.isMine);
                                    final canTapJoin =
                                        contest.canJoin && !alreadyJoined;
                                    final ctaText = alreadyJoined
                                        ? 'Already Joined'
                                        : 'Join Contest';
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: canTapJoin
                                                    ? const [
                                                        AppColors.primary,
                                                        AppColors.secondary,
                                                      ]
                                                    : const [
                                                        Color(0xFFC9C5C3),
                                                        Color(0xFFB5B0AD),
                                                      ],
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: ElevatedButton(
                                              onPressed: canTapJoin
                                                  ? () => _join(contest)
                                                  : null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.transparent,
                                                shadowColor: Colors.transparent,
                                                disabledBackgroundColor:
                                                    Colors.transparent,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: Text(ctaText),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        OutlinedButton(
                                          onPressed: () => Get.to<void>(
                                            () => const ContestRankingScreen(),
                                            arguments: {
                                              'contestId': _contestId,
                                            },
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: const BorderSide(
                                              color: AppColors.primary,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                          ),
                                          child: const Text('Leaderboard'),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 10),
                                _metaTile(
                                  icon: Icons.groups_rounded,
                                  label: 'Participants',
                                  value:
                                      '${contest.liveParticipantCount}/${contest.maxParticipants}',
                                ),
                                const SizedBox(height: 10),
                                _metaTile(
                                  icon: Icons.timer_outlined,
                                  label: contest.timeCaption
                                      .split(' ')
                                      .map(
                                        (word) =>
                                            word[0] +
                                            word.substring(1).toLowerCase(),
                                      )
                                      .join(' '),
                                  value: contest.timeLabel,
                                ),
                                const SizedBox(height: 10),
                                _metaTile(
                                  icon: Icons.play_circle_outline_rounded,
                                  label: 'Contest Start',
                                  value: _formatExactDateTime(contest.startAt),
                                ),
                                const SizedBox(height: 10),
                                _metaTile(
                                  icon: Icons.event_available_rounded,
                                  label: 'Contest End',
                                  value: _formatExactDateTime(contest.endAt),
                                ),
                              ],
                            ),
                          ),
                          if (contest.prizes.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _sectionTitle('Prizes'),
                            const SizedBox(height: 8),
                            _surface(
                              child: Column(
                                children: [
                                  for (var i = 0; i < contest.prizes.length; i++) ...[
                                    if (i > 0) const SizedBox(height: 8),
                                    _prizeTile(contest.prizes[i]),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (contest.teamRanking.isNotEmpty) ...[
                            _sectionTitle('Team Ranking'),
                            const SizedBox(height: 8),
                            _surface(
                              child: Column(
                                children: contest.teamRanking
                                    .map(
                                      (team) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(team.city),
                                        subtitle: Text(
                                          'Members ${team.memberCount}',
                                        ),
                                        trailing: Text(
                                          '${team.rank > 0 ? contestPlaceStanding(team.rank) : 'Unranked'} • ${team.score.toStringAsFixed(1)}',
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _sectionTitle('Participant Feed'),
                          const SizedBox(height: 4),
                          Text(
                            'Use search above to find anyone you want to rate. Posts stay in place after you score them — pull to refresh to see the updated ranking.',
                            style: AppFonts.beVietnam(
                              size: 12,
                              color: AppColors.hintText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (contest.visibleSubmissions.isEmpty)
                            _surface(
                              child: Text(
                                'No submissions yet. Joined posts will appear here.',
                                style: AppFonts.beVietnam(
                                  size: 13,
                                  color: AppColors.hintText,
                                ),
                              ),
                            )
                          else if (_visibleFeed(contest).isEmpty)
                            _surface(
                              child: Text(
                                'No participants match your search.',
                                style: AppFonts.beVietnam(
                                  size: 13,
                                  color: AppColors.hintText,
                                ),
                              ),
                            )
                          else
                            ..._visibleFeed(contest).map((submission) {
                              final postId = submission.postId > 0
                                  ? submission.postId.toString()
                                  : submission.id.toString();
                              final post = _participantPost(
                                submission,
                                contest,
                              );
                              final place = contest.placeForSubmission(submission);
                              return _SubmissionCard(
                                post: post,
                                place: place,
                                totalScore:
                                    _totalScoreOverrides[submission.id] ??
                                    submission.totalScore,
                                officialPlace:
                                    contest.status.trim().toLowerCase() ==
                                    'completed',
                                isLikeLoading: _participantLikeLoadingIds
                                    .contains(postId),
                                isShareLoading: _participantShareLoadingIds
                                    .contains(postId),
                                isVoteLoading: _votingSubmissionIds.contains(
                                  submission.id,
                                ),
                                onLike: () => _toggleParticipantLike(post),
                                onSave: () => _toggleParticipantSave(post),
                                onShare: (channel) =>
                                    _shareParticipant(post, channel),
                                onRatingSelected: (value) {
                                  _onRatingSelected(submission, value);
                                },
                              );
                            }),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _surface({required Widget child, double marginBottom = 0}) {
    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1E9E5)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color.fromRGBO(21, 16, 12, 0.06),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _metaTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: AppHeroIconData(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppFonts.beVietnam(
                    size: 12,
                    color: AppColors.hintText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppFonts.plusJakarta(
                    size: 14,
                    weight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _prizeTile(ContestPrize prize) {
    final winner = prize.winner.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F4F1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prize.title.isEmpty ? '${prize.placeLabel} place' : prize.title,
                  style: AppFonts.plusJakarta(
                    size: 14,
                    weight: FontWeight.w800,
                  ),
                ),
                if (winner.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Won by @$winner',
                    style: AppFonts.beVietnam(
                      size: 12,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            prize.amount > 0 ? prize.amountLabel : 'Prize TBA',
            style: AppFonts.plusJakarta(
              size: 14,
              weight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: AppFonts.plusJakarta(size: 19, weight: FontWeight.w800),
    );
  }

  Widget _participantSearchField() {
    _participantQuery.value;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: TextField(
        controller: _participantSearchController,
        textInputAction: TextInputAction.search,
        onChanged: (value) => _participantQuery.value = value,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        style: AppFonts.beVietnam(size: 14, color: AppColors.text),
        decoration: InputDecoration(
          hintText: 'Search contest participants',
          hintStyle: AppFonts.beVietnam(size: 13, color: AppColors.hintText),
          prefixIcon: const AppHeroIconData(
            Icons.search_rounded,
            color: AppColors.hintText,
          ),
          suffixIcon: _participantQuery.value.trim().isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _participantSearchController.clear();
                    _participantQuery.value = '';
                  },
                  icon: const AppHeroIconData(
                    Icons.close_rounded,
                    color: AppColors.hintText,
                  ),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: Color(0xFFF1E9E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshContest({required bool reorder}) async {
    if (reorder) {
      _pinnedFeedIds.clear();
    }
    await _controller.fetchDetail(_contestId);
    if (mounted) {
      _releaseSettledOverrides();
    }
  }

  List<ContestSubmissionModel> _visibleFeed(ContestDetailModel contest) {
    final query = _participantQuery.value.trim().toLowerCase();
    final source = _orderedSubmissions(contest.visibleSubmissions);
    if (query.isEmpty) {
      return source;
    }
    return source
        .where((item) => _matchesParticipant(item, query))
        .toList(growable: false);
  }

  List<ContestSubmissionModel> _orderedSubmissions(
    List<ContestSubmissionModel> source,
  ) {
    if (source.isEmpty) {
      return source;
    }
    if (_pinnedFeedIds.isEmpty) {
      _pinnedFeedIds.addAll(source.map((item) => item.id));
      return source;
    }

    final byId = <int, ContestSubmissionModel>{
      for (final item in source) item.id: item,
    };
    final ordered = <ContestSubmissionModel>[];
    for (final id in _pinnedFeedIds) {
      final item = byId.remove(id);
      if (item != null) {
        ordered.add(item);
      }
    }
    for (final leftover in byId.values) {
      ordered.add(leftover);
      _pinnedFeedIds.add(leftover.id);
    }
    return ordered;
  }

  bool _matchesParticipant(ContestSubmissionModel item, String query) {
    bool contains(String value) => value.toLowerCase().contains(query);
    return contains(item.username) ||
        contains(item.fullName) ||
        contains(item.caption);
  }

  /// The selected number, the 1–5 average, and the contest score move on
  /// tap. The card stays where it is until the server contest comes back.
  void _onRatingSelected(ContestSubmissionModel submission, int value) {
    final previous = _viewerRatingFor(submission);
    if (previous == value) {
      return;
    }
    final postId = submission.postId > 0
        ? submission.postId.toString()
        : submission.id.toString();
    final count = _voteCountOverrides[submission.id] ?? submission.totalVotes;
    final average =
        _ratingAverageOverrides[submission.id] ?? submission.ratingAverage;
    final store = PostInteractionStore.ensure();
    final likes = store.hasLike(postId)
        ? (store.stateFor(postId)?.likeCount ?? submission.likeCount)
        : submission.likeCount;
    final nextAverage = nextRatingAverage(
      average: average,
      count: count,
      previous: previous,
      next: value,
    );
    final nextCount = previous <= 0
        ? (count <= 0 && average > 0 ? 2 : count + 1)
        : (count <= 0 ? 1 : count);
    _ratingSnapshots.putIfAbsent(
      submission.id,
      () => _ContestRatingSnapshot(
        hadViewer: _viewerRatingOverrides.containsKey(submission.id),
        viewer: _viewerRatingOverrides[submission.id],
        hadAverage: _ratingAverageOverrides.containsKey(submission.id),
        average: _ratingAverageOverrides[submission.id],
        hadScore: _totalScoreOverrides.containsKey(submission.id),
        score: _totalScoreOverrides[submission.id],
        hadCount: _voteCountOverrides.containsKey(submission.id),
        count: _voteCountOverrides[submission.id],
      ),
    );
    setState(() {
      _viewerRatingOverrides[submission.id] = value;
      _ratingAverageOverrides[submission.id] = nextAverage;
      _totalScoreOverrides[submission.id] = contestTotalScore(
        averageRating: nextAverage,
        totalLikes: likes,
      );
      _voteCountOverrides[submission.id] = nextCount;
      _pendingVotes[submission.id] = value;
    });
    unawaited(_flushVote(submission.id));
  }

  Future<void> _flushVote(int submissionId) async {
    if (_votingSubmissionIds.contains(submissionId)) {
      return;
    }
    final value = _pendingVotes.remove(submissionId);
    if (value == null || !mounted) {
      return;
    }
    setState(() {
      _votingSubmissionIds.add(submissionId);
    });
    final ok = await _controller.vote(
      _contestId,
      submissionId,
      value.toDouble(),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _votingSubmissionIds.remove(submissionId);
      if (ok) {
        _committedRatings[submissionId] = value;
        _ratingSnapshots.remove(submissionId);
      } else {
        _restoreRatingSnapshot(submissionId);
      }
    });
    if (ok) {
      _releaseSettledOverrides();
    }
    if (_pendingVotes.containsKey(submissionId)) {
      await _flushVote(submissionId);
    }
  }

  void _restoreRatingSnapshot(int submissionId) {
    final snapshot = _ratingSnapshots.remove(submissionId);
    if (snapshot == null) {
      _viewerRatingOverrides.remove(submissionId);
      _ratingAverageOverrides.remove(submissionId);
      _totalScoreOverrides.remove(submissionId);
      _voteCountOverrides.remove(submissionId);
      return;
    }
    _writeOverride(_viewerRatingOverrides, submissionId, snapshot.hadViewer, snapshot.viewer);
    _writeOverride(
      _ratingAverageOverrides,
      submissionId,
      snapshot.hadAverage,
      snapshot.average,
    );
    _writeOverride(_totalScoreOverrides, submissionId, snapshot.hadScore, snapshot.score);
    _writeOverride(_voteCountOverrides, submissionId, snapshot.hadCount, snapshot.count);
  }

  void _writeOverride<T>(
    Map<int, T> target,
    int id,
    bool hadValue,
    T? value,
  ) {
    if (!hadValue || value == null) {
      target.remove(id);
      return;
    }
    target[id] = value;
  }

  void _releaseSettledOverrides() {
    final contest = _controller.selectedContestDetail.value;
    if (contest == null || !mounted) {
      return;
    }
    final drop = <int>[];
    for (final entry in _viewerRatingOverrides.entries) {
      if (_votingSubmissionIds.contains(entry.key) ||
          _pendingVotes.containsKey(entry.key)) {
        continue;
      }
      ContestSubmissionModel? match;
      for (final item in contest.submissions) {
        if (item.id == entry.key) {
          match = item;
          break;
        }
      }
      if (match != null && match.viewerScore == entry.value) {
        drop.add(entry.key);
      }
    }
    if (drop.isEmpty) {
      return;
    }
    setState(() {
      for (final id in drop) {
        _viewerRatingOverrides.remove(id);
        _ratingAverageOverrides.remove(id);
        _totalScoreOverrides.remove(id);
        _voteCountOverrides.remove(id);
        _ratingSnapshots.remove(id);
      }
    });
  }

  /// What the bottom selector should highlight: the viewer's own rating
  /// (optimistic override first, then the server's value). Never the
  /// aggregate — that belongs to the top badge only.
  int _viewerRatingFor(ContestSubmissionModel submission) {
    return _viewerRatingOverrides[submission.id] ?? submission.viewerScore ?? 0;
  }

  HomePostModel _toPost(
    ContestSubmissionModel submission,
    ContestDetailModel contest,
  ) {
    final resolvedPostId = submission.postId > 0
        ? submission.postId
        : submission.id;
    final submittedAt = submission.submittedAt;
    final postedAt = submittedAt == null
        ? ''
        : AppTimeFormatter.formatCompactDateValue(submittedAt);
    final avatarUrl = _resolveParticipantAvatar(contest, submission);
    return HomePostModel(
      id: resolvedPostId.toString(),
      feedType: HomeFeedType.style,
      mediaType: _isVideo(submission)
          ? HomeMediaType.video
          : HomeMediaType.image,
      contentType: HomeContentType.fashion,
      username: submission.username.isNotEmpty
          ? submission.username
          : submission.fullName,
      location: contest.title,
      streakLabel: contest.typeLabel,
      avatarUrl: avatarUrl,
      imageUrl: submission.mediaUrl,
      displayRating:
          _ratingAverageOverrides[submission.id] ?? submission.ratingAverage,
      likes: submission.likeCount.toString(),
      comments: submission.commentCount.toString(),
      isLiked: submission.isLiked,
      isSaved: submission.isSaved,
      defaultSelectedRate: _viewerRatingFor(submission),
      caption: submission.caption,
      postedAt: postedAt.isEmpty ? 'Joined' : postedAt,
      mediaUrl: submission.mediaUrl,
      thumbnailUrl: submission.mediaThumbnailUrl.isNotEmpty
          ? submission.mediaThumbnailUrl
          : null,
      profileUsername: submission.username,
      authorCity: '',
      ratingEnabled: true,
    );
  }

  String _resolveParticipantAvatar(
    ContestDetailModel contest,
    ContestSubmissionModel submission,
  ) {
    final directAvatar = submission.avatarUrl.trim();
    if (directAvatar.isNotEmpty) {
      return directAvatar;
    }

    final rankingMatch = contest.participantsRanking.where((item) {
      if (item.userId == submission.userId) {
        return true;
      }
      return item.username.trim().toLowerCase() ==
          submission.username.trim().toLowerCase();
    });

    return rankingMatch.isNotEmpty ? rankingMatch.first.avatarUrl : '';
  }

  HomePostModel _participantPost(
    ContestSubmissionModel submission,
    ContestDetailModel contest,
  ) {
    final base = _toPost(submission, contest);
    return PostInteractionStore.ensure().presentHome(base);
  }

  Future<void> _toggleParticipantLike(HomePostModel post) async {
    final shared = PostInteractionStore.ensure().stateFor(post.id);
    PostInteractionStore.ensure().toggleLike(
      postId: post.id,
      isLiked: shared?.isLiked ?? post.isLiked,
      likeCount: shared?.likeCount ?? int.tryParse(post.likes) ?? 0,
      isSaved: post.isSaved,
      saveCount: post.saveCount,
    );
  }

  void _toggleParticipantSave(HomePostModel post) {
    final shared = PostInteractionStore.ensure().stateFor(post.id);
    PostInteractionStore.ensure().toggleSave(
      postId: post.id,
      isSaved: shared?.isSaved ?? post.isSaved,
      saveCount: shared?.saveCount ?? post.saveCount,
      isLiked: post.isLiked,
      likeCount: int.tryParse(post.likes) ?? 0,
      draft: SavedPostDraft.fromHome(post),
    );
  }

  Future<void> _shareParticipant(HomePostModel post, String shareChannel) async {
    final postId = post.id;
    if (_participantShareLoadingIds.contains(postId)) {
      return;
    }
    setState(() => _participantShareLoadingIds.add(postId));
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'feed/posts/$postId/share',
        body: <String, dynamic>{'share_channel': shareChannel},
      );
      if (response == null) {
        return;
      }
      final payload = jsonDecode(response.body);
      if (payload is Map &&
          (response.statusCode != 200 || payload['status_code'] != 1)) {
        throw Exception(
          (payload['message'] ?? 'Unable to share this post').toString(),
        );
      }
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _participantShareLoadingIds.remove(postId));
      }
    }
  }

  bool _isVideo(ContestSubmissionModel submission) {
    final type = submission.mediaType.toLowerCase().trim();
    if (type == 'video') {
      return true;
    }
    final lower = submission.mediaUrl.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.webm');
  }

  Future<void> _join(ContestDetailModel contest) async {
    final accepted = await _acceptScoringTerms();
    if (!accepted) {
      return;
    }
    await _openJoinContestSheet(contest);
  }

  Future<bool> _acceptScoringTerms() async {
    var accepted = false;
    final result = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How voting works',
                    style: AppFonts.plusJakarta(
                      size: 20,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Rate a post from 1 to 5.\n\nYour place comes from the average of those ratings, plus the likes on the post.\n\nRatings count much more than likes. The highest score wins.',
                    style: AppFonts.beVietnam(
                      size: 13,
                      color: AppColors.text,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: accepted,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primary,
                    onChanged: (value) {
                      setState(() {
                        accepted = value ?? false;
                      });
                    },
                    title: Text(
                      'I accept the terms and conditions',
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Get.back(result: false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: accepted
                              ? () => Get.back(result: true)
                              : null,
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      barrierDismissible: false,
    );

    return result == true;
  }

  Future<void> _openJoinContestSheet(ContestDetailModel contest) async {
    final captionController = TextEditingController();
    PickedMedia? pickedOutfit;
    ProfilePostModel? selectedProfilePost;
    bool isSubmitting = false;
    var sheetActive = true;
    void Function(void Function())? setSheetState;

    Future<void> pickOutfit(BuildContext context) async {
      final source = await showMediaSourceSheet(context);
      if (!sheetActive || source == null) {
        return;
      }

      final selected = source == MediaSourceChoice.camera
          ? await MediaPickerService.pickFromCamera()
          : await MediaPickerService.pickFromGallery();
      if (!sheetActive) {
        return;
      }

      setSheetState?.call(() {
        pickedOutfit = selected;
        selectedProfilePost = null;
      });
    }

    Future<void> selectFromProfile() async {
      final selected = await _showMyPostsSheet();
      if (!sheetActive || selected == null) {
        return;
      }

      setSheetState?.call(() {
        selectedProfilePost = selected;
        pickedOutfit = null;
        if (captionController.text.trim().isEmpty) {
          captionController.text = selected.caption;
        }
      });
    }

    await Get.bottomSheet<void>(
      StatefulBuilder(
        builder: (context, updateSheetState) {
          setSheetState = updateSheetState;
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD3CECC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Text(
                      'Join ${contest.title}',
                      style: AppFonts.plusJakarta(
                        size: 22,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a caption and choose the media you want to join with.',
                      style: AppFonts.beVietnam(
                        size: 13,
                        color: AppColors.hintText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _sheetField(
                      'Caption',
                      captionController,
                      maxLines: 4,
                      hintText:
                          'Write a short caption for your contest submission',
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.04),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Outfit Selection',
                                style: AppFonts.plusJakarta(
                                  size: 15,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              TextButton(
                                onPressed: selectFromProfile,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'My Posts',
                                  style: AppFonts.beVietnam(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => pickOutfit(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: AppHeroIconData(
                                      (pickedOutfit?.type == AppMediaType.video)
                                          ? HeroIcons.camera
                                          : HeroIcons.camera,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      pickedOutfit != null
                                          ? pickedOutfit!.path.split('/').last
                                          : (selectedProfilePost != null
                                                ? 'Selected from My Posts'
                                                : 'Select an outfit'),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.beVietnam(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const AppHeroIconData(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.hintText,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (pickedOutfit != null ||
                              selectedProfilePost != null) ...[
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: pickedOutfit != null
                                  ? (pickedOutfit!.type == AppMediaType.image
                                        ? Image.file(
                                            pickedOutfit!.file,
                                            width: double.infinity,
                                            height: 180,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: double.infinity,
                                            height: 180,
                                            color: const Color(0xFFF3F0EF),
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const AppHeroIconData(
                                                  Icons
                                                      .play_circle_fill_rounded,
                                                  size: 42,
                                                  color: AppColors.primary,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  pickedOutfit!.path
                                                      .split('/')
                                                      .last,
                                                  textAlign: TextAlign.center,
                                                  style: AppFonts.beVietnam(
                                                    size: 12,
                                                    weight: FontWeight.w600,
                                                    color: AppColors.hintText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ))
                                  : AppCachedImage(
                                      imageUrl:
                                          selectedProfilePost!.primaryImageUrl,
                                      width: double.infinity,
                                      height: 180,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            if (isSubmitting) {
                              return;
                            }

                            final caption = captionController.text.trim();
                            if (caption.isEmpty ||
                                (pickedOutfit == null &&
                                    selectedProfilePost == null)) {
                              errorSnackBar(
                                message: 'Caption and asset are required.',
                              );
                              return;
                            }

                            updateSheetState(() {
                              isSubmitting = true;
                            });
                            try {
                              final fields = <String, String>{
                                'caption': caption,
                                // Unlike the main upload/edit flows, this
                                // endpoint never got the same
                                // rating_enabled: '1' for outfit entries —
                                // that gap is why freshly-uploaded contest
                                // submissions could end up with voting
                                // silently disabled server-side.
                                'rating_enabled': '1',
                              };
                              final filePaths = <String, String>{};

                              if (selectedProfilePost != null) {
                                fields['post_id'] = selectedProfilePost!.id
                                    .toString();
                              } else if (pickedOutfit != null) {
                                filePaths['asset'] = pickedOutfit!.path;
                              }

                              await _controller.joinContest(
                                _contestId,
                                ContestFormData(
                                  fields: fields,
                                  filePaths: filePaths,
                                ),
                              );
                              if (Get.isBottomSheetOpen ?? false) {
                                AppBackNavigation.handleBack();
                              }
                            } finally {
                              if (sheetActive) {
                                updateSheetState(() {
                                  isSubmitting = false;
                                });
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            disabledBackgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            isSubmitting
                                ? 'Joining...'
                                : 'Upload & Join Contest',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    ).whenComplete(() {
      sheetActive = false;
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        captionController.dispose();
      });
    });
  }

  Future<ProfilePostModel?> _showMyPostsSheet() async {
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());

    if (profileController.outfitPosts.isEmpty) {
      await profileController.refreshProfileOverview();
    }

    return await Get.bottomSheet<ProfilePostModel?>(
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 46,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD3CECC),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              'Select from My Posts',
              style: AppFonts.plusJakarta(size: 20, weight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: Obx(() {
                if (profileController.isInitialLoading.value) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (profileController.outfitPosts.isEmpty) {
                  return Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Text(
                      'No posts found.',
                      style: AppFonts.beVietnam(color: AppColors.hintText),
                    ),
                  );
                }
                return GridView.builder(
                  shrinkWrap: true,
                  itemCount: profileController.outfitPosts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    final post = profileController.outfitPosts[index];
                    return InkWell(
                      onTap: () => Get.back(result: post),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppCachedImage(
                          imageUrl: post.primaryImageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetField(
    String hint,
    TextEditingController controller, {
    int maxLines = 1,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: AppFonts.beVietnam(),
      decoration: InputDecoration(
        hintText: hintText ?? hint,
        hintStyle: AppFonts.beVietnam(color: AppColors.hintText),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  String _formatExactDateTime(DateTime? value) {
    if (value == null) {
      return 'TBA';
    }
    // Already device-local from parseContestDate / AppTimeFormatter.
    return AppTimeFormatter.formatFullDateTimeValue(value);
  }
}

class _FloatingCircleButton extends StatelessWidget {
  const _FloatingCircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.dark = false});

  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.primary.withValues(alpha: 0.1);
    final fg = dark ? Colors.white : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        color: bg,
      ),
      child: Text(
        text,
        style: AppFonts.beVietnam(size: 12, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({
    required this.post,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.isLikeLoading,
    this.isShareLoading = false,
    this.isVoteLoading = false,
    required this.onRatingSelected,
    this.place,
    this.totalScore = 0,
    this.officialPlace = false,
  });

  final HomePostModel post;
  final int? place;
  final double totalScore;
  final bool officialPlace;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final Future<void> Function(String shareChannel) onShare;
  final bool isLikeLoading;
  final bool isShareLoading;
  final bool isVoteLoading;
  final ValueChanged<int> onRatingSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FeedPostCard(
        post: post,
        pictureBadge: _ContestPhotoBadges(
          place: place,
          official: officialPlace,
          rating: post.displayRating,
          totalScore: totalScore,
        ),
        pictureBadgeAtTop: true,
        hideRatingBadge: true,
        selectedRating: post.defaultSelectedRate,
        onRatingSelected: onRatingSelected,
        onLike: onLike,
        onSave: onSave,
        onShare: onShare,
        isLikeLoading: isLikeLoading,
        isShareLoading: isShareLoading,
        isVoteLoading: isVoteLoading,
      ),
    );
  }
}

class _ContestPhotoBadges extends StatelessWidget {
  const _ContestPhotoBadges({
    required this.place,
    required this.official,
    required this.rating,
    required this.totalScore,
  });

  final int? place;
  final bool official;
  final double rating;
  final double totalScore;

  @override
  Widget build(BuildContext context) {
    final average = rating.isFinite && rating > 0 ? rating : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (place != null) ...[
          _PlaceBadge(place: place!, official: official),
          const SizedBox(height: 6),
        ],
        _InfoPill(
          emoji: '⭐',
          label: average.toStringAsFixed(1),
          background: Colors.white.withValues(alpha: 0.92),
          foreground: AppColors.text,
        ),
        const SizedBox(height: 6),
        _InfoPill(
          emoji: '🎯',
          label: _formatContestScore(totalScore),
          background: const Color(0xFFFFF4CC),
          foreground: const Color(0xFF8A5A00),
        ),
      ],
    );
  }
}

String _formatContestScore(double value) {
  if (!value.isFinite || value <= 0) {
    return '0';
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(1);
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.emoji,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String emoji;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.16),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        '$emoji $label',
        style: AppFonts.plusJakarta(
          size: 12,
          weight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

class _ContestRatingSnapshot {
  const _ContestRatingSnapshot({
    required this.hadViewer,
    required this.viewer,
    required this.hadAverage,
    required this.average,
    required this.hadScore,
    required this.score,
    required this.hadCount,
    required this.count,
  });

  final bool hadViewer;
  final int? viewer;
  final bool hadAverage;
  final double? average;
  final bool hadScore;
  final double? score;
  final bool hadCount;
  final int? count;
}

class _PlaceBadge extends StatelessWidget {
  const _PlaceBadge({required this.place, required this.official});

  final int place;
  final bool official;

  String get _label {
    if (official) {
      return contestWinnerTitle(place);
    }
    final emoji = switch (place) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '🏅',
    };
    final standing = contestPlaceStanding(place).replaceFirst(' place', '');
    return '$emoji $standing';
  }

  @override
  Widget build(BuildContext context) {
    final title = _label;
    final colors = switch (place) {
      1 => (const Color(0xFFFFF4CC), const Color(0xFF8A5A00)),
      2 => (const Color(0xFFF3F4F6), const Color(0xFF3F3F46)),
      3 => (const Color(0xFFFFE8D6), const Color(0xFF9A3412)),
      _ => (Colors.white, AppColors.text),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.16),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        title,
        style: AppFonts.plusJakarta(
          size: 12,
          weight: FontWeight.w800,
          color: colors.$2,
        ),
      ),
    );
  }
}
