import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../models/contest_detail_model.dart';

/// Collapsed by default with a "See full rules" control — expands in place.
class ContestRulesCard extends StatefulWidget {
  const ContestRulesCard({
    super.key,
    required this.contest,
    this.showOuterTitle = true,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = 16,
    this.showBorder = true,
  });

  final ContestDetailModel contest;
  final bool showOuterTitle;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool showBorder;

  @override
  State<ContestRulesCard> createState() => _ContestRulesCardState();
}

class _ContestRulesCardState extends State<ContestRulesCard> {
  bool _expanded = false;

  bool get _hasWinning => widget.contest.winningRules != null;
  bool get _hasRules => widget.contest.rules.isNotEmpty;
  bool get _hasContent => _hasWinning || _hasRules;

  String get _previewLine {
    if (_hasWinning) {
      return widget.contest.winningRules!.scoreFormulaLabel;
    }
    if (_hasRules) {
      return widget.contest.rules.first;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) {
      return const SizedBox.shrink();
    }

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
              'Contest rules',
              style: AppFonts.plusJakarta(size: 16, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
          ],
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
                    _expanded ? 'Show less' : 'See full rules',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _previewLine,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppFonts.beVietnam(size: 13, color: AppColors.text),
        ),
        if (_hasWinning && _hasRules) ...[
          const SizedBox(height: 6),
          Text(
            '1. ${widget.contest.rules.first}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.beVietnam(size: 13, color: AppColors.hintText),
          ),
        ],
      ],
    );
  }

  Widget _fullBody() {
    final contest = widget.contest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          if (contest.rules.isNotEmpty) const SizedBox(height: 12),
        ],
        for (var i = 0; i < contest.rules.length; i++) ...[
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
                  contest.rules[i],
                  style: AppFonts.beVietnam(size: 13, color: AppColors.text),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
