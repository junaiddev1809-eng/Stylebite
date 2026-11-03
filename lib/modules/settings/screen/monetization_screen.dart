import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../earnings/controllers/earnings_controller.dart';
import '../../earnings/models/earnings_model.dart';
import '../../earnings/screen/my_earnings_screen.dart';

class MonetizationScreen extends StatefulWidget {
  const MonetizationScreen({super.key});

  @override
  State<MonetizationScreen> createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends State<MonetizationScreen>
    with SingleTickerProviderStateMixin {
  late final EarningsController _controller;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<EarningsController>()
        ? Get.find<EarningsController>()
        : Get.put(EarningsController());
    _controller.fetchEligibility();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.backgroundThemed,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: AppBackNavigation.handleBack),
            Expanded(
              child: Obx(() {
                if (_controller.isEligibilityLoading.value &&
                    _controller.eligibility.value == null) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                final eligibility = _controller.eligibility.value;
                if (eligibility == null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Could not load monetization status.',
                            textAlign: TextAlign.center,
                            style: AppFonts.beVietnam(
                              size: 14,
                              color: AppColors.hintText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _controller.fetchEligibility,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _controller.fetchEligibility,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(16, 8, 16, safeBottom + 28),
                    children: [
                      _HeroCard(
                        eligibility: eligibility,
                        pulse: _pulse,
                      ),
                      const SizedBox(height: 16),
                      if (eligibility.info.trim().isNotEmpty) ...[
                        _InfoCard(text: eligibility.info.trim()),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        'Your progress',
                        style: AppFonts.plusJakarta(
                          size: 18,
                          weight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hit both goals, then send a request for StyleBite review.',
                        style: AppFonts.beVietnam(
                          size: 13,
                          color: AppColors.hintText,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...eligibility.requirements.map(
                        (req) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RequirementCard(requirement: req),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _StatusBanner(eligibility: eligibility),
                      const SizedBox(height: 16),
                      _PrimaryAction(
                        controller: _controller,
                        eligibility: eligibility,
                      ),
                      if (eligibility.isApproved) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () =>
                              Get.to<void>(() => MyEarningsScreen()),
                          child: Text(
                            'Open My Earnings',
                            style: AppFonts.beVietnam(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundThemed.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onBack,
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
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ).createShader(bounds);
                },
                child: Text(
                  'Monetization',
                  style: AppFonts.plusJakarta(
                    size: 22,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.eligibility,
    required this.pulse,
  });

  final AdEligibilityModel eligibility;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final progress = eligibility.overallProgress.clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final status = eligibility.monetizationStatus;

    String headline;
    if (eligibility.isApproved) {
      headline = 'You\'re monetized';
    } else if (status == 'pending') {
      headline = 'Under review';
    } else if (eligibility.isEligible) {
      headline = 'Ready to request';
    } else {
      headline = 'Keep growing';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF6B81),
            Color(0xFFFF8A5B),
            Color(0xFFFFB347),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (context, child) {
              final scale = 1 + (pulse.value * 0.035);
              return Transform.scale(scale: scale, child: child);
            },
            child: SizedBox(
              width: 108,
              height: 108,
              child: CustomPaint(
                painter: _RingPainter(progress: progress),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percent%',
                        style: AppFonts.plusJakarta(
                          size: 26,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'ready',
                        style: AppFonts.beVietnam(
                          size: 11,
                          weight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: AppFonts.plusJakarta(
                    size: 22,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  eligibility.isApproved
                      ? 'Ads earnings are unlocked on your account.'
                      : 'Unlock StyleBite Monetization with Vibe Count and Watch Time.',
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HeroIcon(HeroIcons.informationCircle, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppFonts.beVietnam(
                size: 13,
                weight: FontWeight.w500,
                color: AppColors.text,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.requirement});

  final AdRequirementModel requirement;

  @override
  Widget build(BuildContext context) {
    final isWatch = requirement.type.toLowerCase().contains('watch');
    final progress = requirement.progress;

    String format(double value) {
      if (isWatch) {
        if (value == 0) return '0';
        if (value < 1) return value.toStringAsFixed(2);
        if (value % 1 == 0) return value.toInt().toString();
        return value.toStringAsFixed(1);
      }
      if (value >= 1000000) {
        return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
      }
      if (value >= 1000) {
        final n = value.toInt().toString();
        return n.length > 3
            ? '${n.substring(0, n.length - 3)},${n.substring(n.length - 3)}'
            : n;
      }
      return value.toInt().toString();
    }

    final unit = isWatch ? 'hrs' : 'vibes';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: requirement.isPassed
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.chip,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: HeroIcon(
                  isWatch ? HeroIcons.clock : HeroIcons.users,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requirement.label,
                      style: AppFonts.plusJakarta(
                        size: 15,
                        weight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      requirement.isPassed
                          ? 'Goal reached'
                          : requirement.remainingText,
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w500,
                        color: requirement.isPassed
                            ? AppColors.primary
                            : AppColors.hintText,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${format(requirement.current)} / ${format(requirement.threshold)} $unit',
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.chip,
              valueColor: AlwaysStoppedAnimation<Color>(
                requirement.isPassed
                    ? const Color(0xFF2ECC71)
                    : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.eligibility});

  final AdEligibilityModel eligibility;

  @override
  Widget build(BuildContext context) {
    final status = eligibility.monetizationStatus;
    late Color bg;
    late Color fg;
    late String title;
    late String body;

    if (eligibility.isApproved) {
      bg = const Color(0xFFE8F8EF);
      fg = const Color(0xFF1B7A45);
      title = 'Approved';
      body = 'Monetization is active. Manage ads from My Earnings.';
    } else if (status == 'pending') {
      bg = const Color(0xFFFFF4E5);
      fg = const Color(0xFF9A5B00);
      title = 'Pending review';
      body = 'We received your request. You\'ll be notified when it\'s reviewed.';
    } else if (status == 'rejected') {
      bg = const Color(0xFFFFEBEE);
      fg = const Color(0xFFB71C1C);
      title = 'Not approved yet';
      body = eligibility.adminNote?.trim().isNotEmpty == true
          ? eligibility.adminNote!.trim()
          : 'Keep growing and request again once you meet the criteria.';
    } else if (eligibility.isEligible) {
      bg = AppColors.chip;
      fg = AppColors.text;
      title = 'Criteria met';
      body = 'Send a monetization request for admin review.';
    } else {
      bg = AppColors.chip;
      fg = AppColors.hintText;
      title = 'Almost there';
      body =
          'Reach the Vibe Count and Watch Time goals to unlock the request button.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFonts.plusJakarta(
              size: 14,
              weight: FontWeight.w800,
              color: fg,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: AppFonts.beVietnam(
              size: 12,
              weight: FontWeight.w500,
              color: fg.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.controller,
    required this.eligibility,
  });

  final EarningsController controller;
  final AdEligibilityModel eligibility;

  @override
  Widget build(BuildContext context) {
    final canRequest = eligibility.canRequest;
    final pending = eligibility.monetizationStatus == 'pending';
    final approved = eligibility.isApproved;

    String label;
    if (approved) {
      label = 'Monetization unlocked';
    } else if (pending) {
      label = 'Request pending';
    } else if (canRequest) {
      label = 'Send monetization request';
    } else {
      label = 'Keep building your vibes';
    }

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: canRequest
                ? const [AppColors.primary, AppColors.secondary]
                : [
                    AppColors.hintText.withValues(alpha: 0.35),
                    AppColors.hintText.withValues(alpha: 0.25),
                  ],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: canRequest
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Obx(() {
          final loading = controller.isRequestingMonetization.value;
          return ElevatedButton(
            onPressed: (!canRequest || loading)
                ? null
                : () => controller.requestMonetization(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: AppFonts.beVietnam(
                      size: 15,
                      weight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          );
        }),
      ),
    );
  }
}
