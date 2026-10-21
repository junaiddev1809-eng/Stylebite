import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../controllers/contest_controller.dart';
import '../models/contest_model.dart';
import '../widgets/admin_contest_section.dart';
import '../widgets/community_contest_section.dart';

class ContestScreen extends StatefulWidget {
  const ContestScreen({super.key});

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> {
  late final ContestController _controller;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ContestController>()
        ? Get.find<ContestController>()
        : Get.put(ContestController());
    _scrollController.addListener(_onScroll);
    _controller.attachScrollController(_scrollController);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.detachScrollController(_scrollController);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.background),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _TopBar(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Obx(() {
                  _controller.searchQuery.value;
                  return _ContestSearchField(
                    controller: _searchController,
                    onChanged: _controller.setSearchQuery,
                    onClear: () {
                      _searchController.clear();
                      _controller.setSearchQuery('');
                    },
                  );
                }),
              ),
              Expanded(
                child: Obx(() {
                  return RefreshIndicator(
                    onRefresh: _controller.refreshContests,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 130),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Curation Hub',
                                  style: AppFonts.beVietnam(
                                    size: 12,
                                    weight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Style ',
                                        style: AppFonts.plusJakarta(
                                          size: 44,
                                          weight: FontWeight.w800,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Arena',
                                        style: AppFonts.plusJakarta(
                                          size: 44,
                                          weight: FontWeight.w300,
                                          color: AppColors.hintText,
                                          height: 1.0,
                                        ).copyWith(fontStyle: FontStyle.italic),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Builder(
                                  builder: (_) {
                                    final rewardContest =
                                        _pickPriorityBannerContest();
                                    if (rewardContest == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return _RewardHighlightCard(
                                      contest: rewardContest,
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                if (_controller.isInitialLoading.value)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                else if (_controller.selectedCategory.value ==
                                    ContestCategory.admin)
                                  _controller.adminContests.isEmpty
                                      ? _EmptyBattleState(
                                          title:
                                              _controller.searchQuery.value.isEmpty
                                              ? 'No battle is there!'
                                              : 'No participants found',
                                          subtitle:
                                              _controller.searchQuery.value.isEmpty
                                              ? 'Admin arena is quiet right now. Check back soon for featured battles.'
                                              : 'No contest has a matching participant. Try another name.',
                                          icon: Icons.workspace_premium_rounded,
                                        )
                                      : AdminContestSection(
                                          contests: _controller.adminContests,
                                          onViewLeaderboard: _openLeaderboard,
                                          onOpenContest: _openContestDetail,
                                        )
                                else
                                  _controller.communityContests.isEmpty
                                      ? _EmptyBattleState(
                                          title:
                                              _controller.searchQuery.value.isEmpty
                                              ? 'No battle is there!'
                                              : 'No participants found',
                                          subtitle:
                                              _controller.searchQuery.value.isEmpty
                                              ? 'Community battles have not started yet. Be the first to create one.'
                                              : 'No contest has a matching participant. Try another name.',
                                          icon: Icons.groups_rounded,
                                        )
                                      : CommunityContestSection(
                                          contests:
                                              _controller.communityContests,
                                          onOpenContest: _openContestDetail,
                                        ),
                                if (_controller.isLoadingMore.value) ...[
                                  const SizedBox(height: 16),
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final p = _scrollController.position;
    if (p.pixels > p.maxScrollExtent - 240) {
      _controller.fetchContests(reset: false);
    }
  }

  void _openContestDetail(ContestModel contest) {
    final args = <String, dynamic>{'contestId': contest.id};
    final participantQuery = _controller.searchQuery.value.trim();
    if (participantQuery.isNotEmpty) {
      args['participantQuery'] = participantQuery;
    }
    Get.toNamed(AppRoutes.contestDetail, arguments: args);
  }

  void _openLeaderboard(int contestId) {
    Get.toNamed(AppRoutes.contestRanking, arguments: {'contestId': contestId});
  }

  ContestModel? _pickPriorityBannerContest() {
    final now = DateTime.now();
    final rewardList = _controller.adminContests
        .where((c) => c.hasReward)
        .toList(growable: false);
    if (rewardList.isEmpty) {
      return null;
    }

    final openEnrollment = rewardList
        .where(
          (c) => c.enrollmentEndAt != null && c.enrollmentEndAt!.isAfter(now),
        )
        .toList(growable: false);
    if (openEnrollment.isEmpty) {
      return rewardList.first;
    }

    openEnrollment.sort((a, b) {
      final aMinutes = a.enrollmentEndAt!.difference(now).inMinutes;
      final bMinutes = b.enrollmentEndAt!.difference(now).inMinutes;
      return aMinutes.compareTo(bMinutes);
    });
    return openEnrollment.first;
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: AppColors.background.withValues(alpha: 0.8),
      child: Row(
        children: [
          Row(
            children: [
              Image.asset(
                AppAssets.brandLogo,
                width: 30,
                height: 30,
                errorBuilder: (context, error, stackTrace) =>
                    const AppHeroIconData(
                      Icons.diamond_rounded,
                      color: AppColors.primary,
                    ),
              ),
              const SizedBox(width: 6),
              Image.asset(
                AppAssets.brandTextLogo,
                height: 18,
                errorBuilder: (context, error, stackTrace) => Text(
                  'StyleBite',
                  style: AppFonts.plusJakarta(
                    size: 16,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // DecoratedBox(
          //   decoration: const BoxDecoration(
          //     gradient: LinearGradient(
          //       colors: [AppColors.primary, AppColors.secondary],
          //     ),
          //     borderRadius: BorderRadius.all(Radius.circular(999)),
          //   ),
          //   child: ElevatedButton(
          //     onPressed: onCreateTap,
          //     style: ElevatedButton.styleFrom(
          //       backgroundColor: Colors.transparent,
          //       shadowColor: Colors.transparent,
          //       padding: const EdgeInsets.symmetric(
          //         horizontal: 20,
          //         vertical: 10,
          //       ),
          //     ),
          //     child: Text(
          //       'Create',
          //       style: AppFonts.plusJakarta(
          //         size: 14,
          //         weight: FontWeight.w700,
          //         color: Colors.white,
          //       ),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }
}

class _ContestSearchField extends StatelessWidget {
  const _ContestSearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        hintText: 'Search contest participants',
        hintStyle: AppFonts.beVietnam(size: 13, color: AppColors.hintText),
        prefixIcon: const AppHeroIconData(
          Icons.search_rounded,
          color: AppColors.hintText,
        ),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                onPressed: onClear,
                icon: const AppHeroIconData(Icons.close_rounded),
                color: AppColors.hintText,
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _EmptyBattleState extends StatelessWidget {
  const _EmptyBattleState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: AppHeroIconData(icon, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppFonts.plusJakarta(
              size: 20,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppFonts.beVietnam(
              size: 13,
              color: AppColors.hintText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RewardHighlightCard extends StatelessWidget {
  const _RewardHighlightCard({required this.contest});

  final ContestModel contest;

  @override
  Widget build(BuildContext context) {
    final joinedAvatars = contest.participantsRanking
        .map((item) => item.avatarUrl.trim())
        .where((url) => url.isNotEmpty)
        .take(5)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏆 Daily Contest',
            style: AppFonts.plusJakarta(
              size: 18,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            contest.prizes.length > 1 ? 'Prize pool' : 'Today\'s Prize',
            style: AppFonts.beVietnam(
              size: 12,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'PKR ${contest.rewardAmount.toStringAsFixed(0)}',
            style: AppFonts.plusJakarta(
              size: 36,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            contest.prizes.length > 1
                ? '${contest.prizes.length} winners · ${contest.prizes.map((prize) => '${prize.placeLabel} ${prize.amountLabel}').join(' · ')}'
                : contest.prizes.length == 1
                    ? '1 winner'
                    : 'Winner gets cash + featured badge',
            style: AppFonts.beVietnam(
              size: 13,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (joinedAvatars.isNotEmpty)
                SizedBox(
                  width: (28 + (joinedAvatars.length - 1) * 20).toDouble(),
                  height: 28,
                  child: Stack(
                    children: [
                      for (int i = 0; i < joinedAvatars.length; i++)
                        Positioned(
                          left: i * 20,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              image: DecorationImage(
                                image: NetworkImage(joinedAvatars[i]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (joinedAvatars.isNotEmpty) const SizedBox(width: 8),
              Text(
                '${contest.participantCount} joined',
                style: AppFonts.beVietnam(
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.9),
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
