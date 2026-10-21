import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../controllers/leaderboard_controller.dart';
import '../models/leaderboard_models.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<LeaderboardController>()
        ? Get.find<LeaderboardController>()
        : Get.put(LeaderboardController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<LeaderboardController>()) {
      Get.delete<LeaderboardController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller.contest;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
          children: [
            _TopBar(),
            const SizedBox(height: 14),
            Text(
              '${c.source} Leaderboard',
              style: AppFonts.beVietnam(
                size: 11,
                weight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 1,
              ),
            ),
            Text(
              c.name,
              style: AppFonts.plusJakarta(
                size: 42,
                weight: FontWeight.w800,
                color: AppColors.text,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              c.subtitle,
              style: AppFonts.beVietnam(
                size: 13,
                weight: FontWeight.w500,
                color: AppColors.hintText,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _tag(c.format, const Color(0xFFF3F0EF), AppColors.text, true),
                _tag(
                  c.window,
                  const Color(0xFFF3F0EF),
                  AppColors.hintText,
                  false,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _HeroCard(contest: c),
            const SizedBox(height: 12),
            Obx(
              () => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['global', 'city', 'weekly', 'monthly'].map((
                    period,
                  ) {
                    final isActive = _controller.activePeriod.value == period;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => _controller.setPeriod(period),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            gradient: isActive
                                ? const LinearGradient(
                                    colors: [
                                      AppColors.primary,
                                      AppColors.secondary,
                                    ],
                                  )
                                : null,
                            color: isActive ? null : const Color(0xFFF3F0EF),
                          ),
                          child: Text(
                            _capitalize(period),
                            style: AppFonts.beVietnam(
                              size: 13,
                              weight: FontWeight.w700,
                              color: isActive
                                  ? Colors.white
                                  : AppColors.hintText,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Obx(
              () => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['outfit', 'food', 'battles'].map((cat) {
                  final isActive = _controller.activeCategory.value == cat;
                  return InkWell(
                    onTap: () => _controller.setCategory(cat),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFFDFDCDC)
                            : const Color(0xFFF3F0EF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _capitalize(cat),
                        style: AppFonts.beVietnam(
                          size: 11,
                          weight: FontWeight.w700,
                          color: isActive ? AppColors.text : AppColors.hintText,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
            _Podium(topThree: _controller.topThree),
            const SizedBox(height: 16),
            _Table(entries: _controller.tableEntries),
            const SizedBox(height: 16),
            if (c.hasTeams) _TeamStandings(contest: c),
            const SizedBox(height: 16),
            _BottomCta(),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color bg, Color fg, bool bold) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppFonts.beVietnam(
          size: 10,
          weight: bold ? FontWeight.w700 : FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  String _capitalize(String v) => v[0].toUpperCase() + v.substring(1);
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: AppBackNavigation.handleBack,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: const AppHeroIconData(
              Icons.arrow_back_rounded,
              color: AppColors.primary,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Leaderboard',
              style: AppFonts.plusJakarta(
                size: 30,
                weight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: const AppHeroIconData(
            Icons.emoji_events_rounded,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.contest});

  final LeaderboardContestContext contest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const AppHeroIconData(
                      Icons.radio_button_checked_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      contest.status,
                      style: AppFonts.beVietnam(
                        size: 10,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Participants',
                    style: AppFonts.beVietnam(
                      size: 10,
                      weight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.75),
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    contest.participants,
                    style: AppFonts.plusJakarta(
                      size: 30,
                      weight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            contest.heroTitle,
            style: AppFonts.plusJakarta(
              size: 26,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            contest.heroMeta,
            style: AppFonts.beVietnam(
              size: 12,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton(
                onPressed: () => Get.toNamed<void>(
                  AppRoutes.contestDetail,
                  arguments: {'contestId': contest.id},
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('Contest Detail'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Get.toNamed<void>(AppRoutes.myEarnings),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: const Text('My Earnings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.topThree});

  final List<LeaderboardEntry> topThree;

  @override
  Widget build(BuildContext context) {
    final second = topThree.firstWhere((e) => e.rank == 2);
    final first = topThree.firstWhere((e) => e.rank == 1);
    final third = topThree.firstWhere((e) => e.rank == 3);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _podiumItem(second, 112, false)),
        Expanded(child: _podiumItem(first, 176, true)),
        Expanded(child: _podiumItem(third, 88, false)),
      ],
    );
  }

  Widget _podiumItem(LeaderboardEntry e, double barHeight, bool winner) {
    return Column(
      children: [
        Container(
          width: winner ? 96 : 76,
          height: winner ? 96 : 76,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: winner ? AppColors.primary : const Color(0xFFE4E2E1),
              width: 3,
            ),
          ),
          child: ClipOval(child: Image.network(e.avatar, fit: BoxFit.cover)),
        ),
        const SizedBox(height: 8),
        Text(
          e.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.beVietnam(
            size: winner ? 16 : 13,
            weight: FontWeight.w700,
          ),
        ),
        Text(
          '${e.points} pts',
          style: AppFonts.beVietnam(
            size: winner ? 13 : 11,
            weight: FontWeight.w700,
            color: winner ? AppColors.primary : AppColors.hintText,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: barHeight,
          decoration: BoxDecoration(
            gradient: winner
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  )
                : null,
            color: winner ? null : const Color(0xFFF3F0EF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            '#${e.rank}',
            style: AppFonts.plusJakarta(
              size: winner ? 18 : 13,
              weight: FontWeight.w800,
              color: winner ? Colors.white : AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _head('Rank', 42, TextAlign.center),
            _head('Creator', null, TextAlign.left),
            _head('Points', 78, TextAlign.right),
            _head('Earnings', 90, TextAlign.right),
          ],
        ),
        const SizedBox(height: 8),
        ...entries.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0EF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${e.rank}',
                      textAlign: TextAlign.center,
                      style: AppFonts.plusJakarta(
                        size: 14,
                        weight: FontWeight.w800,
                        color: AppColors.hintText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(e.avatar),
                          radius: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AppVerifiedName(
                                name: e.name,
                                username: e.handle,
                                badgeSize: 13,
                                style: AppFonts.beVietnam(
                                  size: 13,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                e.handle,
                                style: AppFonts.beVietnam(
                                  size: 10,
                                  weight: FontWeight.w500,
                                  color: AppColors.hintText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 78,
                    child: Text(
                      e.points,
                      textAlign: TextAlign.right,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      e.earnings,
                      textAlign: TextAlign.right,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _head(String text, double? width, TextAlign align) {
    final child = Text(
      text.toUpperCase(),
      textAlign: align,
      style: AppFonts.beVietnam(
        size: 10,
        weight: FontWeight.w700,
        color: AppColors.hintText,
        letterSpacing: 0.8,
      ),
    );

    return width == null
        ? Expanded(child: child)
        : SizedBox(width: width, child: child);
  }
}

class _TeamStandings extends StatelessWidget {
  const _TeamStandings({required this.contest});

  final LeaderboardContestContext contest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Team Standings',
                style: AppFonts.plusJakarta(size: 26, weight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                'View Contest',
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bar(contest.team1Name!, contest.team1Pct!),
          const SizedBox(height: 10),
          _bar(contest.team2Name!, contest.team2Pct!),
        ],
      ),
    );
  }

  Widget _bar(String name, int pct) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              name,
              style: AppFonts.beVietnam(size: 13, weight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '$pct%',
              style: AppFonts.beVietnam(size: 13, weight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.white),
                FractionallySizedBox(
                  widthFactor: pct / 100,
                  alignment: Alignment.centerLeft,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Text(
            'Rise to the top?',
            style: AppFonts.plusJakarta(
              size: 28,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Participate in the latest battle and improve your rank before weekly reset.',
            textAlign: TextAlign.center,
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                child: const Text('Enter Battle'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Get.toNamed<void>(AppRoutes.myEarnings),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: const Text('My Earnings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
