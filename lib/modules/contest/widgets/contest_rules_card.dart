import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/contest_detail_model.dart';
import '../utils/contest_official_rules.dart';

/// Official Contest Rules — always available for App Store Guideline 5.3.2.
class ContestRulesCard extends StatefulWidget {
  const ContestRulesCard({
    super.key,
    required this.contest,
    this.showOuterTitle = true,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 16,
    this.showBorder = true,
    this.startExpanded = true,
  });

  final ContestDetailModel contest;
  final bool showOuterTitle;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showBorder;
  final bool startExpanded;

  @override
  State<ContestRulesCard> createState() => _ContestRulesCardState();
}

class _ContestRulesCardState extends State<ContestRulesCard> {
  late bool _expanded = widget.startExpanded;

  List<String> get _officialRules =>
      ContestOfficialRules.mergeWithRequired(widget.contest.rules);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: widget.showBorder
            ? Border.all(color: AppColors.cardBorder)
            : null,
        boxShadow: widget.showBorder
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showOuterTitle) ...[
            Text(
              'Official Contest Rules',
              style: AppFonts.plusJakarta(size: 16, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
          ],
          // Always visible — reviewers must see Apple non-involvement without expanding.
          Text(
            ContestOfficialRules.appleDisclaimer,
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ContestOfficialRules.sponsor,
            style: AppFonts.beVietnam(size: 13, color: AppColors.hintText),
          ),
          const SizedBox(height: 10),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded ? _fullBody() : _collapsedBody(),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _expanded ? 'Show less' : 'See full official rules',
                    style: AppFonts.beVietnam(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _collapsedBody() {
    final preview = _officialRules
        .where(
          (rule) =>
              !ContestOfficialRules.isAppleDisclaimer(rule) &&
              !ContestOfficialRules.isSponsorLine(rule),
        )
        .take(2)
        .toList(growable: false);

    if (preview.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < preview.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          Text(
            preview[i],
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.beVietnam(size: 13, color: AppColors.hintText),
          ),
        ],
      ],
    );
  }

  Widget _fullBody() {
    final contest = widget.contest;
    final rules = _officialRules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (contest.hasMinParticipantsToStart) ...[
          Text(
            contest.minParticipantsToStartLabel,
            style: AppFonts.beVietnam(size: 13, color: AppColors.text),
          ),
          if (!contest.participantsToStartMet) ...[
            const SizedBox(height: 6),
            Text(
              'Waiting for entrants: ${contest.liveParticipantCount}/${contest.minParticipantsToStart}.',
              style: AppFonts.beVietnam(size: 13, color: AppColors.hintText),
            ),
          ],
          const SizedBox(height: 12),
        ],
        if (contest.winningRules != null) ...[
          Text(
            contest.winningRules!.scoreFormulaLabel,
            style: AppFonts.beVietnam(size: 13, color: AppColors.text),
          ),
          const SizedBox(height: 6),
          Text(
            'Need at least ${contest.winningRules!.minRatingVoters} active ratings to win a prize place.',
            style: AppFonts.beVietnam(size: 13, color: AppColors.hintText),
          ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < rules.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${i + 1}.',
                style: AppFonts.plusJakarta(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rules[i],
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight:
                        ContestOfficialRules.isAppleDisclaimer(rules[i]) ||
                            ContestOfficialRules.isSponsorLine(rules[i])
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
