import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// Two-option pill control with a sliding gradient thumb.
class AppSlidingToggle extends StatelessWidget {
  const AppSlidingToggle({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.trackColor,
    this.padding = const EdgeInsets.all(4),
    this.segmentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 8,
    ),
    this.minSegmentWidth,
    this.fontSize = 11,
    this.letterSpacing = 0.4,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final Color? trackColor;
  final EdgeInsets padding;
  final EdgeInsets segmentPadding;
  final double? minSegmentWidth;
  final double fontSize;
  final double letterSpacing;

  static const _duration = Duration(milliseconds: 320);
  static const _curve = Curves.easeOutCubic;

  Alignment get _thumbAlignment {
    if (labels.length <= 1) {
      return Alignment.center;
    }
    final t = selectedIndex.clamp(0, labels.length - 1) / (labels.length - 1);
    return Alignment(-1 + (2 * t), 0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: trackColor ?? Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedAlign(
                duration: _duration,
                curve: _curve,
                alignment: _thumbAlignment,
                child: FractionallySizedBox(
                  widthFactor: labels.isEmpty ? 1 : 1 / labels.length,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < labels.length; i++)
                _Segment(
                  label: labels[i],
                  selected: i == selectedIndex,
                  onTap: () {
                    if (i == selectedIndex) {
                      return;
                    }
                    onChanged(i);
                  },
                  padding: segmentPadding,
                  width: minSegmentWidth,
                  fontSize: fontSize,
                  letterSpacing: letterSpacing,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.padding,
    required this.fontSize,
    required this.letterSpacing,
    this.width,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final double? width;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final text = AnimatedDefaultTextStyle(
      duration: AppSlidingToggle._duration,
      curve: AppSlidingToggle._curve,
      style: AppFonts.beVietnam(
        size: fontSize,
        weight: selected ? FontWeight.w700 : FontWeight.w600,
        color: selected ? Colors.white : AppColors.hintText,
        letterSpacing: letterSpacing,
      ),
      child: Text(label, textAlign: TextAlign.center),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Padding(
          padding: padding,
          child: width == null ? text : Center(child: text),
        ),
      ),
    );
  }
}
