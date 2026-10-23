import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_time_formatter.dart';
import '../../earnings/controllers/earnings_controller.dart';
import '../../earnings/models/earnings_model.dart';
import '../../landing/screen/landing_screen.dart';

class EarningsTopBar extends StatelessWidget {
  const EarningsTopBar({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            color: AppColors.background,
            child: Row(
              children: [
                InkWell(
                  onTap: AppBackNavigation.handleBack,
                  borderRadius: BorderRadius.circular(999),
                  child: const SizedBox(
                    width: 36,
                    height: 36,
                    child: HeroIcon(
                      HeroIcons.arrowLeft,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppFonts.plusJakarta(
                      size: 18,
                      weight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Get.offAll<void>(
                    () => const LandingScreen(initialIndex: 0),
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        AppAssets.brandLogo,
                        width: 26,
                        height: 26,
                        errorBuilder: (context, error, stackTrace) =>
                            const AppHeroIconData(Icons.diamond_rounded),
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        AppAssets.brandTextLogo,
                        height: 14,
                        errorBuilder: (context, error, stackTrace) => Text(
                          'StyleBite',
                          style: AppFonts.plusJakarta(
                            size: 14,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EarningsSectionHeader extends StatelessWidget {
  const EarningsSectionHeader({required this.title, this.onTap, super.key});

  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppFonts.plusJakarta(size: 24, weight: FontWeight.w800),
          ),
        ),
        if (onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'View All',
                style: AppFonts.beVietnam(
                  size: 11,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class EarningsBreakdownTile extends StatelessWidget {
  const EarningsBreakdownTile({required this.item, super.key});

  final EarningTransactionModel item;

  @override
  Widget build(BuildContext context) {
    final subtitlePieces = <String>[
      _formatTimeline(item.processedAt ?? item.createdAt),
      _humanize(item.reason),
    ].where((value) => value.isNotEmpty).toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _sourceColor(item.sourceType).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: HeroIcon(
              _sourceIcon(item.sourceType),
              color: _sourceColor(item.sourceType),
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title.trim().isEmpty ? 'Untitled earning' : item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.beVietnam(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitlePieces.join(' • '),
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
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.amountDisplay.trim().isEmpty
                    ? EarningsController.formatMoney(item.currencyCode, item.amount)
                    : item.amountDisplay,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.plusJakarta(
                  size: 14,
                  weight: FontWeight.w800,
                  color: item.transactionType == 'debit'
                      ? AppColors.text
                      : const Color(0xFFA13920),
                ),
              ),
              Text(
                _humanize(
                  item.status.trim().toLowerCase() == 'pending'
                      ? 'pending_approval'
                      : (item.amountDirection.isEmpty
                          ? item.status
                          : item.amountDirection),
                ),
                style: AppFonts.beVietnam(
                  size: 9,
                  weight: FontWeight.w600,
                  color: item.status.trim().toLowerCase() == 'pending'
                      ? AppColors.primary
                      : AppColors.hintText,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EarningsWithdrawalTile extends StatelessWidget {
  const EarningsWithdrawalTile({
    required this.item,
    this.withDivider = false,
    super.key,
  });

  final EarningsWithdrawalModel item;
  final bool withDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: withDivider
            ? Border(
                bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFDFDCDC),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const HeroIcon(
              HeroIcons.wallet,
              size: 18,
              color: AppColors.hintText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _withdrawalTitle(item),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.beVietnam(size: 13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  _formatTimeline(item.requestedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.beVietnam(
                    size: 10,
                    weight: FontWeight.w500,
                    color: AppColors.hintText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.amountDisplay.trim().isEmpty
                    ? '- ${EarningsController.formatMoney(item.currencyCode, item.amount)}'
                    : item.amountDisplay,
                style: AppFonts.plusJakarta(size: 13, weight: FontWeight.w800),
              ),
              Text(
                _humanize(item.status),
                style: AppFonts.beVietnam(
                  size: 10,
                  weight: FontWeight.w700,
                  color: _withdrawalStatusColor(item.status),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class EarningsEmptyCard extends StatelessWidget {
  const EarningsEmptyCard({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppFonts.beVietnam(
          size: 13,
          weight: FontWeight.w500,
          color: AppColors.hintText,
        ),
      ),
    );
  }
}

class EarningsPaginationFooter extends StatelessWidget {
  const EarningsPaginationFooter({
    required this.isLoading,
    required this.hasMore,
    super.key,
  });

  final bool isLoading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            'No more data',
            style: AppFonts.beVietnam(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.hintText,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

String _formatTimeline(String? raw) {
  final parsed = AppTimeFormatter.parse(raw);
  if (parsed == null) {
    return 'Just now';
  }
  final month = _months[parsed.month - 1];
  final hour = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final suffix = parsed.hour >= 12 ? 'PM' : 'AM';
  return '$month ${parsed.day}, ${parsed.year} • $hour:$minute $suffix';
}

String _humanize(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return '';
  }
  return normalized
      .split('_')
      .where((part) => part.trim().isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

HeroIcons _sourceIcon(String sourceType) {
  switch (sourceType) {
    case 'contest_reward':
      return HeroIcons.trophy;
    case 'engagement_bonus':
      return HeroIcons.sparkles;
    case 'withdrawal':
      return HeroIcons.arrowUpOnSquare;
    default:
      return HeroIcons.banknotes;
  }
}

Color _sourceColor(String sourceType) {
  switch (sourceType) {
    case 'contest_reward':
      return const Color(0xFFFFB200);
    case 'engagement_bonus':
      return const Color(0xFFFF4D6D);
    case 'withdrawal':
      return const Color(0xFF5C5B5B);
    default:
      return const Color(0xFF652FE7);
  }
}

String _withdrawalTitle(EarningsWithdrawalModel item) {
  final base = item.title.trim().isEmpty ? 'Withdrawal' : item.title.trim();
  final ref = item.accountRef.trim();
  if (ref.isEmpty) {
    return base;
  }
  return '$base ($ref)';
}

Color _withdrawalStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'completed':
      return const Color(0xFFA13920);
    case 'processing':
    case 'pending':
      return AppColors.primary;
    case 'failed':
      return AppColors.error;
    default:
      return AppColors.hintText;
  }
}

const List<String> _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
