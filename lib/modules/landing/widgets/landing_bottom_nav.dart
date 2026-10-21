import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/constants/bottom_nav_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../models/landing_tab_model.dart';

class LandingBottomNav extends StatelessWidget {
  const LandingBottomNav({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    this.compact = false,
  });

  final List<LandingTabModel> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool compact;

  static const Duration _indicatorDuration = Duration(milliseconds: 380);
  static const Curve _indicatorCurve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return RepaintBoundary(
      child: Padding(
      padding: EdgeInsets.fromLTRB(
        kBottomNavHorizontalMargin,
        0,
        kBottomNavHorizontalMargin,
        kBottomNavVerticalMargin + bottomInset,
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        scale: compact ? 0.84 : 1,
        child: SizedBox(
          height: kBottomNavHeight,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: kBottomNavHorizontalPadding,
                  vertical: kBottomNavVerticalPadding,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: compact ? 0.96 : 0.98),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: compact ? 0.62 : 0.95,
                    ),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(47, 47, 46, 0.16),
                      blurRadius: 26,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slotWidth = constraints.maxWidth / tabs.length;
                    final selectedSize = _itemSize(currentIndex);
                    final indicatorLeft =
                        currentIndex * slotWidth +
                        (slotWidth - selectedSize) / 2;
                    final indicatorTop =
                        (constraints.maxHeight - selectedSize) / 2;
                    final centerSize = kBottomNavCenterItemSize;
                    final centerLeft =
                        2 * slotWidth + (slotWidth - centerSize) / 2;
                    final centerTop = (constraints.maxHeight - centerSize) / 2;

                    return Stack(
                      children: [
                        AnimatedPositioned(
                          duration: _indicatorDuration,
                          curve: _indicatorCurve,
                          left: centerLeft,
                          top: centerTop,
                          width: centerSize,
                          height: centerSize,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            opacity: currentIndex == 2 ? 0 : 1,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFE7E7E7),
                              ),
                            ),
                          ),
                        ),
                        AnimatedPositioned(
                          duration: _indicatorDuration,
                          curve: _indicatorCurve,
                          left: indicatorLeft,
                          top: indicatorTop,
                          width: selectedSize,
                          height: selectedSize,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: Color.fromRGBO(255, 77, 109, 0.38),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: List.generate(tabs.length, (index) {
                            final tab = tabs[index];
                            final isSelected = index == currentIndex;
                            final isCenterButton = index == 2;

                            return Expanded(
                              child: InkWell(
                                splashFactory: NoSplash.splashFactory,
                                highlightColor: Colors.transparent,
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => onTap(index),
                                child: Center(
                                  child: SizedBox(
                                    width: _itemSize(index),
                                    height: _itemSize(index),
                                    child: AnimatedScale(
                                      duration: _indicatorDuration,
                                      curve: _indicatorCurve,
                                      scale: isSelected ? 1 : 0.92,
                                      child: _LandingNavIconGlyph(
                                        icon: isSelected
                                            ? tab.activeIcon
                                            : tab.icon,
                                        size: isCenterButton
                                            ? kBottomNavCenterIconSize
                                            : kBottomNavIconSize,
                                        color: isSelected
                                            ? Colors.white
                                            : isCenterButton
                                            ? AppColors.text.withValues(
                                                alpha: 0.9,
                                              )
                                            : AppColors.hintText.withValues(
                                                alpha: 0.85,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ),
        ),
      ),
      ),
    );
  }

  double _itemSize(int index) {
    return index == 2 ? kBottomNavCenterItemSize : kBottomNavItemSize;
  }
}

class _LandingNavIconGlyph extends StatelessWidget {
  const _LandingNavIconGlyph({
    required this.icon,
    required this.size,
    required this.color,
  });

  final dynamic icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      tween: ColorTween(end: color),
      builder: (context, animatedColor, child) {
        return AppHeroIconData(icon, size: size, color: animatedColor ?? color);
      },
    );
  }
}
