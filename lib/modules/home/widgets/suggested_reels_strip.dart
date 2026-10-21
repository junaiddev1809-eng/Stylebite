import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../landing/controllers/landing_controller.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../reel/utils/reel_open_helper.dart';
import '../../search/utils/explore_media_mapper.dart';
import '../models/home_post_model.dart';

class SuggestedReelsStrip extends StatelessWidget {
  const SuggestedReelsStrip({
    super.key,
    required this.reels,
    required this.feedType,
  });

  static const int previewCount = 10;
  static const double _cardWidth = 124;
  static const double _reelGap = 10;
  static const double _seeMoreGap = 28;

  final List<HomePostModel> reels;
  final HomeFeedType feedType;

  void _open(HomePostModel reel) {
    ReelOpenHelper.openFromPost(reel.copyWith(feedType: feedType));
  }

  void _openSeeMore() {
    if (reels.length > previewCount) {
      _open(reels[previewCount]);
      return;
    }
    _open(reels.first);
  }

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) {
      return const SizedBox.shrink();
    }

    final preview = reels.take(previewCount).toList(growable: false);
    final showSeeMore = preview.length >= previewCount;
    final showRestaurant = feedType == HomeFeedType.bite;
    final children = <Widget>[
      for (var i = 0; i < preview.length; i++) ...[
        if (i > 0) const SizedBox(width: _reelGap),
        _SuggestedReelCard(
          reel: preview[i],
          showRestaurant: showRestaurant,
          onTap: () => _open(preview[i]),
        ),
      ],
      if (showSeeMore) ...[
        const SizedBox(width: _seeMoreGap),
        _SeeMoreCard(onTap: _openSeeMore),
      ],
    ];
    final contentWidth = preview.length * _cardWidth +
        math.max(0, preview.length - 1) * _reelGap +
        (showSeeMore ? _seeMoreGap + _cardWidth : 0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggested reels',
            style: AppFonts.plusJakarta(
              size: 16,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 196,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: _SuggestedReelTrack(
                contentWidth: contentWidth,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal reel row that always starts at the first reel.
/// Dragging right to left reveals later reels, then See more.
class _SuggestedReelTrack extends StatefulWidget {
  const _SuggestedReelTrack({
    required this.contentWidth,
    required this.children,
  });

  final double contentWidth;
  final List<Widget> children;

  @override
  State<_SuggestedReelTrack> createState() => _SuggestedReelTrackState();
}

class _SuggestedReelTrackState extends State<_SuggestedReelTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fling;
  double _offset = 0;
  double _flingFrom = 0;
  double _flingTo = 0;
  double _viewport = 0;
  int _pointers = 0;
  int _pageLocks = 0;
  bool _horizontal = false;
  Offset? _origin;
  Offset? _last;
  Duration? _lastTime;
  double _velocity = 0;

  @override
  void initState() {
    super.initState();
    _fling = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(_onFlingTick);
  }

  void _onFlingTick() {
    setState(() {
      final t = Curves.decelerate.transform(_fling.value);
      _offset = _flingFrom + (_flingTo - _flingFrom) * t;
    });
  }

  @override
  void dispose() {
    _releasePageLocks();
    _fling.removeListener(_onFlingTick);
    _fling.dispose();
    super.dispose();
  }

  void _lockPage() {
    if (!Get.isRegistered<LandingController>()) {
      return;
    }
    Get.find<LandingController>().lockHorizontalPage();
    _pageLocks++;
  }

  void _releasePageLocks() {
    if (_pageLocks == 0 || !Get.isRegistered<LandingController>()) {
      _pageLocks = 0;
      return;
    }
    final landing = Get.find<LandingController>();
    for (var i = 0; i < _pageLocks; i++) {
      landing.unlockHorizontalPage();
    }
    _pageLocks = 0;
  }

  double get _limit => math.max(0, widget.contentWidth - _viewport);

  void _onPointerDown(PointerDownEvent event) {
    _pointers++;
    if (_pointers != 1) {
      return;
    }
    _fling.stop();
    _horizontal = false;
    _origin = event.position;
    _last = event.position;
    _lastTime = event.timeStamp;
    _velocity = 0;
    _lockPage();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _origin;
    final last = _last;
    if (origin == null || last == null || _pointers == 0) {
      return;
    }
    if (!_horizontal) {
      final delta = event.position - origin;
      if (delta.distance < 10) {
        return;
      }
      if (delta.dx.abs() <= delta.dy.abs()) {
        _origin = null;
        _last = null;
        return;
      }
      _horizontal = true;
    }
    final dx = event.position.dx - last.dx;
    final dt = _lastTime == null
        ? 0.0
        : (event.timeStamp - _lastTime!).inMicroseconds / 1000000;
    _last = event.position;
    _lastTime = event.timeStamp;
    if (dt > 0) {
      _velocity = -dx / dt;
    }
    setState(() {
      _offset = (_offset - dx).clamp(0.0, _limit);
    });
  }

  void _onPointerUp(PointerEvent event) {
    if (_pointers == 0) {
      return;
    }
    _pointers--;
    if (_pointers > 0) {
      return;
    }
    final velocity = _velocity;
    _origin = null;
    _last = null;
    _lastTime = null;
    _velocity = 0;
    // Release after this pointer-up so the tab pager cannot fling to the next
    // screen from the same swipe that scrolled the row.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pointers > 0) {
        return;
      }
      _releasePageLocks();
    });
    if (!_horizontal || velocity.abs() < 240 || _limit <= 0) {
      _horizontal = false;
      return;
    }
    _horizontal = false;
    _flingFrom = _offset.clamp(0.0, _limit);
    _flingTo = (_flingFrom + velocity * 0.16).clamp(0.0, _limit);
    _fling.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.maxWidth;
        final shown = _offset.clamp(0.0, _limit);
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragDown: (_) {},
            onHorizontalDragUpdate: (_) {},
            onHorizontalDragEnd: (_) {},
            onHorizontalDragCancel: () {},
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: -shown,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: widget.children,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeeMoreCard extends StatelessWidget {
  const _SeeMoreCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 124,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ColoredBox(
            color: const Color(0xFFE8E4E3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'See more',
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight: FontWeight.w800,
                    color: AppColors.text,
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

class _SuggestedReelCard extends StatelessWidget {
  const _SuggestedReelCard({
    required this.reel,
    required this.onTap,
    required this.showRestaurant,
  });

  final HomePostModel reel;
  final VoidCallback onTap;
  final bool showRestaurant;

  @override
  Widget build(BuildContext context) {
    final cover = ExploreMediaMapper.coverUrl(reel);
    final restaurant = showRestaurant
        ? ExploreMediaMapper.restaurantLabel(reel)
        : '';

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    cover.isEmpty
                        ? const ColoredBox(color: Color(0xFFE8E4E3))
                        : AppCachedImage(
                            imageUrl: cover,
                            fit: BoxFit.cover,
                            memCacheWidth: 360,
                          ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x99000000)],
                        ),
                      ),
                    ),
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: AppHeroIconData(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Positioned(
                      left: 8,
                      right: 8,
                      bottom: 8,
                      child: Text(
                        reel.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.beVietnam(
                          size: 11,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (restaurant.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                restaurant,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.beVietnam(
                  size: 11,
                  weight: FontWeight.w600,
                  color: AppColors.hintText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
