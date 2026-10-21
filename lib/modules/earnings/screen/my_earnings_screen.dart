import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../earnings/controllers/earnings_controller.dart';
import '../../earnings/models/earnings_model.dart';
import '../../earnings/screen/earnings_breakdowns_screen.dart';
import '../../earnings/screen/earnings_withdrawals_screen.dart';
import '../../earnings/screen/withdraw_request_screen.dart';
import '../../earnings/widgets/earnings_widgets.dart';

class MyEarningsScreen extends StatelessWidget {
  MyEarningsScreen({super.key})
    : _controller = Get.isRegistered<EarningsController>()
          ? Get.find<EarningsController>()
          : Get.put(EarningsController());

  final EarningsController _controller;

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Obx(() {
            if (_controller.isOverviewLoading.value &&
                _controller.summary.value == null) {
              return _MyEarningsShimmer(
                safeTop: safeTop,
                safeBottom: safeBottom,
              );
            }

            if (_controller.hasOverviewError.value &&
                _controller.summary.value == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EarningsEmptyCard(
                    message: _controller.overviewErrorMessage.value,
                  ),
                ),
              );
            }

            final summary = _controller.currentSummary;
            return RefreshIndicator(
              onRefresh: _controller.refreshOverview,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      safeTop + 78,
                      16,
                      safeBottom + 36,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F0EF),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const HeroIcon(
                                  HeroIcons.lockClosed,
                                  size: 18,
                                  color: AppColors.hintText,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'This information is private to you.',
                                    style: AppFonts.beVietnam(
                                      size: 13,
                                      weight: FontWeight.w500,
                                      color: AppColors.hintText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          _BalanceHero(
                            balanceLabel: _controller.availableBalanceDisplay,
                            onWithdraw: () =>
                                Get.to<void>(() => WithdrawRequestScreen()),
                          ),
                          const SizedBox(height: 14),
                          _StatsGrid(
                            contestWins: summary.contestWins.toString(),
                            changeDisplay: _controller.lastMonthChangeDisplay,
                            adEarnings: _controller.adEarningsDisplay,
                          ),
                          const SizedBox(height: 24),
                          Obx(() {
                            final eligibility = _controller.eligibility.value;
                            if (eligibility == null && _controller.isEligibilityLoading.value) {
                              return const _EligibilityShimmer();
                            }
                            if (eligibility != null) {
                              if (eligibility.isEligible) {
                                return Column(
                                  children: [
                                    _AdsToggleSection(controller: _controller),
                                    const SizedBox(height: 32),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    _MonetizationEligibilitySection(eligibility: eligibility),
                                    const SizedBox(height: 32),
                                  ],
                                );
                              }
                            }
                            return const SizedBox.shrink();
                          }),
                          _BreakdownSection(
                            items: _controller.breakdownPreview,
                            onViewAll: () {
                              _controller.ensureBreakdownsLoaded();
                              Get.to<void>(
                                () => const EarningsBreakdownsScreen(),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          _WithdrawalSection(
                            items: _controller.withdrawalsPreview,
                            onViewAll: () {
                              _controller.ensureWithdrawalsLoaded();
                              Get.to<void>(
                                () => const EarningsWithdrawalsScreen(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: EarningsTopBar(title: 'My Earnings'),
          ),
        ],
      ),
    );
  }
}

class _MyEarningsShimmer extends StatelessWidget {
  const _MyEarningsShimmer({required this.safeTop, required this.safeBottom});

  final double safeTop;
  final double safeBottom;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, safeTop + 78, 16, safeBottom + 36),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0EF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      AppShimmerBox(
                        width: 18,
                        height: 18,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: AppShimmerBox(
                          height: 14,
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(255, 77, 109, 0.12),
                        blurRadius: 40,
                        offset: Offset(0, 12),
                        spreadRadius: -12,
                      ),
                    ],
                  ),
                  child: Column(
                    children: const [
                      AppShimmerBox(
                        width: 128,
                        height: 12,
                        borderRadius: BorderRadius.all(Radius.circular(6)),
                      ),
                      SizedBox(height: 12),
                      AppShimmerBox(
                        width: 220,
                        height: 52,
                        borderRadius: BorderRadius.all(Radius.circular(14)),
                      ),
                      SizedBox(height: 18),
                      AppShimmerBox(
                        height: 50,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Expanded(child: _StatCardShimmer()),
                    SizedBox(width: 10),
                    Expanded(child: _StatCardShimmer()),
                  ],
                ),
                const SizedBox(height: 10),
                const _StatCardShimmer(),
                const SizedBox(height: 16),
                const _EligibilityShimmer(),
                const SizedBox(height: 16),
                const _SectionShimmer(tileCount: 3, isWithdrawal: false),
                const SizedBox(height: 16),
                const _SectionShimmer(tileCount: 3, isWithdrawal: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCardShimmer extends StatelessWidget {
  const _StatCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppShimmerBox(
            width: 22,
            height: 22,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          SizedBox(height: 8),
          AppShimmerBox(
            width: 68,
            height: 28,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          SizedBox(height: 6),
          AppShimmerBox(
            width: 92,
            height: 12,
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ],
      ),
    );
  }
}

class _SectionShimmer extends StatelessWidget {
  const _SectionShimmer({required this.tileCount, required this.isWithdrawal});

  final int tileCount;
  final bool isWithdrawal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: AppShimmerBox(
                height: 26,
                width: 180,
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            SizedBox(width: 10),
            AppShimmerBox(
              width: 62,
              height: 28,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...List<Widget>.generate(
          tileCount,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == tileCount - 1 ? 0 : 8),
            child: isWithdrawal
                ? const _WithdrawalTileShimmer()
                : const _BreakdownTileShimmer(),
          ),
        ),
      ],
    );
  }
}

class _BreakdownTileShimmer extends StatelessWidget {
  const _BreakdownTileShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          AppShimmerBox(
            width: 46,
            height: 46,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox(
                  height: 14,
                  width: 120,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                SizedBox(height: 6),
                AppShimmerBox(
                  height: 11,
                  width: 160,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppShimmerBox(
                height: 14,
                width: 82,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(height: 6),
              AppShimmerBox(
                height: 10,
                width: 54,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WithdrawalTileShimmer extends StatelessWidget {
  const _WithdrawalTileShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          AppShimmerBox(
            width: 34,
            height: 34,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerBox(
                  height: 13,
                  width: 140,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                SizedBox(height: 6),
                AppShimmerBox(
                  height: 10,
                  width: 120,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppShimmerBox(
                height: 13,
                width: 88,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(height: 6),
              AppShimmerBox(
                height: 10,
                width: 58,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EligibilityShimmer extends StatelessWidget {
  const _EligibilityShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppShimmerBox(
          height: 24,
          width: 150,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        const SizedBox(height: 16),
        ...List.generate(2, (index) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: const [
              AppShimmerBox(height: 4, width: double.infinity, borderRadius: BorderRadius.all(Radius.circular(2))),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AppShimmerBox(height: 14, width: 180, borderRadius: BorderRadius.all(Radius.circular(4))),
                  AppShimmerBox(height: 14, width: 40, borderRadius: BorderRadius.all(Radius.circular(4))),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }
}

class _BalanceHero extends StatelessWidget {
  const _BalanceHero({required this.balanceLabel, required this.onWithdraw});

  final String balanceLabel;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(255, 77, 109, 0.12),
            blurRadius: 40,
            offset: Offset(0, 12),
            spreadRadius: -12,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'AVAILABLE BALANCE',
            style: AppFonts.beVietnam(
              size: 11,
              weight: FontWeight.w600,
              color: AppColors.hintText,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              balanceLabel,
              style: AppFonts.plusJakarta(
                size: 46,
                weight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: ElevatedButton(
                onPressed: onWithdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text(
                  'Withdraw',
                  style: AppFonts.plusJakarta(
                    size: 18,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.contestWins,
    required this.changeDisplay,
    required this.adEarnings,
  });

  final String contestWins;
  final String changeDisplay;
  final String adEarnings;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: HeroIcons.trophy,
                iconColor: const Color(0xFFFFD166),
                value: contestWins,
                label: 'Contests Won',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                icon: HeroIcons.arrowTrendingUp,
                iconColor: AppColors.primary,
                value: changeDisplay,
                label: 'Vs Last Month',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _StatCard(
          icon: HeroIcons.megaphone,
          iconColor: const Color(0xFF4CC9F0),
          value: adEarnings,
          label: 'Total Earning',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final HeroIcons icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeroIcon(icon, color: iconColor, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppFonts.plusJakarta(size: 25, weight: FontWeight.w800),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.beVietnam(
              size: 11,
              weight: FontWeight.w500,
              color: AppColors.hintText,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdsToggleSection extends StatelessWidget {
  const _AdsToggleSection({required this.controller});

  final EarningsController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable ads on my reels',
                  style: AppFonts.plusJakarta(
                    size: 16,
                    weight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start earning from ads on your videos.',
                  style: AppFonts.beVietnam(
                    size: 13,
                    color: AppColors.hintText,
                  ),
                ),
              ],
            ),
          ),
          Obx(() {
            final adsEnabled = controller.eligibility.value?.adsEnabled ?? false;
            final isToggling = controller.isTogglingAds.value;
            
            return Switch.adaptive(
              value: adsEnabled,
              onChanged: isToggling ? null : (val) => controller.toggleAds(val),
              activeColor: AppColors.primary,
            );
          }),
        ],
      ),
    );
  }
}

class _MonetizationEligibilitySection extends StatelessWidget {
  const _MonetizationEligibilitySection({required this.eligibility});

  final AdEligibilityModel eligibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How to join',
          style: AppFonts.plusJakarta(
            size: 18,
            weight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 20),
        ...eligibility.requirements.map((req) => Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: _RequirementTile(requirement: req),
        )),
      ],
    );
  }
}

class _RequirementTile extends StatelessWidget {
  const _RequirementTile({required this.requirement});

  final AdRequirementModel requirement;

  @override
  Widget build(BuildContext context) {
    final isWatchHours = requirement.type.toLowerCase().contains('watch');
    
    // Format current value
    String currentStr;
    if (isWatchHours) {
      if (requirement.current == 0) {
        currentStr = '0';
      } else if (requirement.current < 1) {
        currentStr = requirement.current.toStringAsFixed(2);
      } else if (requirement.current % 1 == 0) {
        currentStr = requirement.current.toInt().toString();
      } else {
        currentStr = requirement.current.toStringAsFixed(1);
      }
    } else {
      currentStr = requirement.current.toInt().toString();
    }
    
    // Format threshold
    String thresholdStr;
    if (requirement.threshold >= 1000000) {
       thresholdStr = '${(requirement.threshold / 1000000).toStringAsFixed(requirement.threshold % 1000000 == 0 ? 0 : 1)}M';
    } else if (requirement.threshold >= 1000) {
      final str = requirement.threshold.toInt().toString();
      // Simple thousand separator
      thresholdStr = str.length > 3 ? "${str.substring(0, str.length - 3)},${str.substring(str.length - 3)}" : str;
    } else {
      thresholdStr = requirement.threshold.toInt().toString();
    }

    final subtitle = isWatchHours 
        ? 'last 365 days' 
        : (requirement.type.toLowerCase().contains('view') ? 'last 90 days' : 'total followers');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar on top (thin and grey)
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E0E0),
            borderRadius: BorderRadius.circular(2),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    width: (constraints.maxWidth * requirement.progress).clamp(0.0, constraints.maxWidth),
                    decoration: BoxDecoration(
                      color: const Color(0xFF606060),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$currentStr valid public ${requirement.label.toLowerCase()}',
                    style: AppFonts.beVietnam(
                      size: 14,
                      color: AppColors.text,
                      weight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: AppFonts.beVietnam(
                        size: 12,
                        color: AppColors.hintText,
                        weight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              thresholdStr,
              style: AppFonts.beVietnam(
                size: 14,
                color: AppColors.text,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BreakdownSection extends StatelessWidget {
  const _BreakdownSection({required this.items, required this.onViewAll});

  final List<EarningTransactionModel> items;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EarningsSectionHeader(title: 'Earning Breakdown', onTap: onViewAll),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const EarningsEmptyCard(message: 'No earning breakdown found yet.')
        else
          ...List<Widget>.generate(
            items.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == items.length - 1 ? 0 : 8,
              ),
              child: EarningsBreakdownTile(item: items[index]),
            ),
          ),
      ],
    );
  }
}

class _WithdrawalSection extends StatelessWidget {
  const _WithdrawalSection({required this.items, required this.onViewAll});

  final List<EarningsWithdrawalModel> items;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EarningsSectionHeader(title: 'Recent Withdrawals', onTap: onViewAll),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const EarningsEmptyCard(message: 'No withdrawals found yet.')
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0EF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: List<Widget>.generate(
                items.length,
                (index) => EarningsWithdrawalTile(
                  item: items[index],
                  withDivider: index != items.length - 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
