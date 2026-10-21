import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:heroicons/heroicons.dart';

import '../theme/app_fonts.dart';
import 'app_hero_icon.dart';

/// A native ad rendered as a full-screen page inside the reels feed.
///
/// The ad's platform view registers no gesture recognizers of its own, so the
/// parent vertical `PageView` wins the drag: the user can flick the ad away at
/// any moment, while a tap still goes through to the ad as a click.
class AppAdmobNative extends StatelessWidget {
  const AppAdmobNative({super.key, required this.ad});

  final NativeAd ad;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AdWidget(key: ValueKey<NativeAd>(ad), ad: ad),
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 0,
            right: 0,
            child: const IgnorePointer(child: _SwipeToSkipHint()),
          ),
        ],
      ),
    );
  }
}

/// A small "swipe up to skip" affordance that bobs a couple of times and then
/// fades away, so it reads as a hint rather than chrome.
class _SwipeToSkipHint extends StatefulWidget {
  const _SwipeToSkipHint();

  @override
  State<_SwipeToSkipHint> createState() => _SwipeToSkipHintState();
}

class _SwipeToSkipHintState extends State<_SwipeToSkipHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bobController;
  Timer? _fadeTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _fadeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 600),
      child: Center(
        child: AnimatedBuilder(
          animation: _bobController,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -4 * _bobController.value),
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppHeroIconData(
                  HeroIcons.chevronUp,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Swipe up to skip',
                  style: AppFonts.beVietnam(
                    size: 12,
                    weight: FontWeight.w600,
                    color: Colors.white,
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
