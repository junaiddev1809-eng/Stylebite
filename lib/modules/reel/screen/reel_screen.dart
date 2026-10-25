import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';
import 'package:video_player/video_player.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/constants/bottom_nav_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_cached_video_player.dart';
import '../../../core/widgets/app_video_seek_bar.dart';
import '../../../core/widgets/like_heart_burst.dart';
import '../../../core/widgets/app_admob_native.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/utils/verified_flag.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/navigation/app_route_observer.dart';
import '../../landing/controllers/landing_controller.dart';
import '../../landing/widgets/landing_bottom_nav.dart';
import '../../profile/widgets/follow_user_button.dart';
import '../../post/utils/in_app_share.dart';
import '../../post/widgets/in_app_share_sheet.dart';
import '../../post/utils/hashtag_open_helper.dart';
import '../../post/widgets/comments_caption_header.dart';
import '../../post/widgets/post_hashtag_chips.dart';
import '../../post/widgets/post_options_sheet.dart';
import '../controllers/reel_controller.dart';
import '../models/reel_item_model.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../../SelectLocationScreen/restaurant_map_screen.dart';
import '../widgets/bite_reel_review_sheet.dart';

class ReelScreen extends StatefulWidget {
  const ReelScreen({
    super.key,
    this.controllerTag,
    this.viewerMode = false,
    this.showBottomNav = true,
  });

  final String? controllerTag;
  final bool viewerMode;
  /// When false (profile reel viewer), skip the landing-style bottom bar.
  final bool showBottomNav;

  @override
  State<ReelScreen> createState() => _ReelScreenState();
}

class _ReelScreenState extends State<ReelScreen> with RouteAware {
  late final ReelController _controller;
  ModalRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    final tag = widget.controllerTag;
    if (tag != null && Get.isRegistered<ReelController>(tag: tag)) {
      _controller = Get.find<ReelController>(tag: tag);
    } else if (Get.isRegistered<ReelController>()) {
      _controller = Get.find<ReelController>();
    } else {
      _controller = ReelController.ensureTabController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.setFeedVisible(_shouldPlayReels);
    });
  }

  /// Playback belongs to this screen only while it is the screen the user is
  /// actually looking at. The reels tab stays mounted under the other tabs.
  bool get _shouldPlayReels {
    if (widget.viewerMode) {
      return true;
    }
    if (!Get.isRegistered<LandingController>()) {
      return true;
    }
    return Get.find<LandingController>().currentIndex.value == 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _controller.setFeedVisible(false);
    final tag = widget.controllerTag;
    if (widget.viewerMode &&
        tag != null &&
        Get.isRegistered<ReelController>(tag: tag)) {
      Get.delete<ReelController>(tag: tag);
    }
    super.dispose();
  }

  @override
  void didPushNext() {
    _controller.setFeedVisible(false);
  }

  @override
  void didPopNext() {
    _controller.setFeedVisible(_shouldPlayReels);
  }

  void _openAuthorProfile(ReelItemModel reel) {
    final username = reel.profileUsername.trim().replaceFirst('@', '');
    if (username.isEmpty) {
      return;
    }

    ProfileOpenHelper.open(
      username: username,
      initialIsFollowing: reel.isFollowingAuthor,
      avatarUrl: reel.avatarUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = SizedBox.expand(
      child: ColoredBox(
        color: const Color(0xFF0E0E11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Obx(() {
                if (_controller.isInitialLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (_controller.hasError.value) {
                  return AppErrorState(
                    message: 'Could not load reels. Check your connection.',
                    onRetry: _controller.refreshReels,
                  );
                }

                if (_controller.pagerItemCount.value == 0) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'No reels found for this category.',
                        textAlign: TextAlign.center,
                        style: AppFonts.beVietnam(
                          size: 15,
                          weight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  );
                }

                return PageView.builder(
                  controller: _controller.pageController,
                  scrollDirection: Axis.vertical,
                  allowImplicitScrolling: true,
                  onPageChanged: _controller.onReelChanged,
                  itemCount: _controller.pagerItemCount.value,
                  itemBuilder: (context, index) {
                    return _ReelPage(
                      key: ValueKey<String>('reel-page-$index'),
                      controller: _controller,
                      pageIndex: index,
                      onTapProfile: _openAuthorProfile,
                      reserveBottomNav:
                          !widget.viewerMode || widget.showBottomNav,
                    );
                  },
                );
              }),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Hidden on ad pages: this bar sits exactly where the AdChoices
              // badge renders, and an ad must not be obscured. Dropping it also
              // leaves the ad genuinely full-screen.
              child: Obx(() {
                final onAdPage =
                    _controller.nativeAdAt(_controller.currentIndex.value) !=
                    null;
                if (onAdPage) {
                  return const SizedBox.shrink();
                }

                return SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(
                      children: [
                        if (widget.viewerMode)
                          _TopIconButton(
                            icon: HeroIcons.arrowLeft,
                            onTap: Get.back,
                          )
                        else
                          _ReelFeedToggle(controller: _controller),
                        const Spacer(),
                        if (!widget.viewerMode) ...[
                          _TopIconButton(
                            icon: HeroIcons.magnifyingGlass,
                            onTap: () => Get.toNamed(AppRoutes.search),
                          ),
                          const SizedBox(width: 10),
                          _CityButton(
                            controller: _controller,
                            onTap: _openCityPicker,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );

    if (!widget.viewerMode) {
      return body;
    }

    if (!widget.showBottomNav) {
      return Scaffold(
        backgroundColor: const Color(0xFF0E0E11),
        body: body,
      );
    }

    return _ReelViewerShell(body: body);
  }

  Future<void> _openCityPicker() async {
    _controller.citySearchController.clear();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (context) {
        String query = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _controller.filteredCities(query);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.76,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF18181D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            'Select City',
                            style: AppFonts.plusJakarta(
                              size: 22,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            icon: const AppHeroIconData(HeroIcons.xMark),
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _controller.citySearchController,
                        onChanged: (value) {
                          setModalState(() {
                            query = value;
                          });
                        },
                        style: AppFonts.beVietnam(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search city...',
                          hintStyle: AppFonts.beVietnam(
                            size: 14,
                            weight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: AppHeroIconData(
                              HeroIcons.magnifyingGlass,
                              color: Colors.white.withValues(alpha: 0.6),
                              size: 20,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Suggested Cities',
                          style: AppFonts.beVietnam(
                            size: 11,
                            weight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Obx(
                        () => SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _controller.suggestedCities.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final city = _controller.suggestedCities[index];
                              final selected =
                                  _controller.selectedCity.value == city;

                              return GestureDetector(
                                onTap: () {
                                  _controller.setCity(city);
                                  Navigator.of(context).pop();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    gradient: selected
                                        ? const LinearGradient(
                                            colors: [
                                              AppColors.primary,
                                              AppColors.secondary,
                                            ],
                                          )
                                        : null,
                                    color: selected
                                        ? null
                                        : Colors.white.withValues(alpha: 0.12),
                                  ),
                                  child: Text(
                                    city,
                                    style: AppFonts.beVietnam(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'All Cities',
                          style: AppFonts.beVietnam(
                            size: 11,
                            weight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No city found. Try another keyword.',
                                  style: AppFonts.beVietnam(
                                    size: 14,
                                    weight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.6),
                                  ),
                                ),
                              )
                            : Obx(
                                () => GridView.builder(
                                  itemCount: filtered.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                        mainAxisExtent: 48,
                                      ),
                                  itemBuilder: (context, index) {
                                    final city = filtered[index];
                                    final selected =
                                        _controller.selectedCity.value == city;

                                    return GestureDetector(
                                      onTap: () {
                                        _controller.setCity(city);
                                        Navigator.of(context).pop();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          gradient: selected
                                              ? const LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.secondary,
                                                  ],
                                                )
                                              : null,
                                          color: selected
                                              ? null
                                              : Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                          border: Border.all(
                                            color: selected
                                                ? Colors.transparent
                                                : Colors.white.withValues(
                                                    alpha: 0.15,
                                                  ),
                                          ),
                                        ),
                                        child: Text(
                                          city,
                                          style: AppFonts.beVietnam(
                                            size: 13,
                                            weight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReelPage extends StatelessWidget {
  const _ReelPage({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.onTapProfile,
    this.reserveBottomNav = true,
  });

  final ReelController controller;
  final int pageIndex;
  final Function(ReelItemModel) onTapProfile;
  final bool reserveBottomNav;

  @override
  Widget build(BuildContext context) {
    final ad = controller.nativeAdAt(pageIndex);
    if (ad != null) {
      return AppAdmobNative(
        key: ValueKey<String>('reel-ad-$pageIndex'),
        ad: ad,
      );
    }

    final reelIndex = controller.mapToReelIndex(pageIndex);
    if (reelIndex == -1 || reelIndex >= controller.visibleReels.length) {
      return const SizedBox.shrink();
    }

    final item = controller.visibleReels[reelIndex];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.prefetchAround(reelIndex);
    });
    return _ReelSlide(
      key: ValueKey<String>('reel-slide-${item.id}'),
      controller: controller,
      index: reelIndex,
      item: item,
      onTapProfile: onTapProfile,
      reserveBottomNav: reserveBottomNav,
    );
  }
}

class _ReelSlide extends StatefulWidget {
  const _ReelSlide({
    super.key,
    required this.controller,
    required this.index,
    required this.item,
    required this.onTapProfile,
    this.reserveBottomNav = true,
  });

  final ReelController controller;
  final int index;
  final ReelItemModel item;
  final Function(ReelItemModel) onTapProfile;
  final bool reserveBottomNav;

  @override
  State<_ReelSlide> createState() => _ReelSlideState();
}

class _ReelSlideState extends State<_ReelSlide>
    with AutomaticKeepAliveClientMixin<_ReelSlide> {
  Worker? _keepAliveWorker;
  int _likeBurst = 0;
  VideoPlayerController? _videoController;
  bool _isScrubbing = false;

  void _onDoubleTapLike() {
    setState(() => _likeBurst++);
    final live = _liveReel();
    if (!live.isLiked) {
      widget.controller.toggleLike(live.id);
    }
  }

  ReelItemModel _liveReel() {
    for (final reel in widget.controller.visibleReels) {
      if (reel.id == widget.item.id) {
        return reel;
      }
    }
    return widget.item;
  }

  @override
  void initState() {
    super.initState();
    _keepAliveWorker = ever<int>(widget.controller.currentIndex, (_) {
      if (mounted) {
        updateKeepAlive();
      }
    });
  }

  @override
  void dispose() {
    _keepAliveWorker?.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => _isNearActiveReel;

  bool get _isNearActiveReel {
    var active = widget.controller.mapToReelIndex(
      widget.controller.currentIndex.value,
    );
    if (active < 0) {
      active = widget.controller.mapToReelIndex(
        widget.controller.currentIndex.value + 1,
      );
    }
    if (active < 0) {
      active = widget.controller.mapToReelIndex(
        widget.controller.currentIndex.value - 1,
      );
    }
    if (active < 0) {
      return true;
    }
    return (widget.index - active).abs() <= 1;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    final index = widget.index;
    final item = widget.item;
    final onTapProfile = widget.onTapProfile;
    final seekBottom = _seekBarBottom(context);
    final metaBottom = seekBottom + 34;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (item.mediaType == ReelMediaType.video)
          Positioned.fill(
            child: Obx(() {
              // `index` is a reel index, which stops matching the page index once
              // ad pages are interleaved. Mapping the page back keeps playback on
              // the visible reel — and pauses every reel while an ad page is up,
              // since an ad page maps to -1.
              final isActive =
                  controller.isFeedVisible.value &&
                  index ==
                      controller.mapToReelIndex(controller.currentIndex.value);
              return AppCachedVideoPlayer(
                key: ValueKey<String>('reel-video-${item.id}-${item.mediaUrl}'),
                videoUrl: item.mediaUrl,
                thumbnailUrl: item.imageUrl == item.mediaUrl
                    ? null
                    : item.imageUrl,
                autoPlay: true,
                isActive: isActive,
                deferInitUntilActive: true,
                isMuted: controller.isMuted.value,
                shareMute: true,
                isPaused: controller.isReelPaused(item.id) || _isScrubbing,
                onMutedChanged: controller.setMuted,
                onPlayPauseChanged: (isPaused) =>
                    controller.setCurrentVideoPaused(item.id, isPaused),
                onProgressChanged: (progress) =>
                    controller.handleVideoProgress(item.id, progress),
                onControllerReady: (video) {
                  if (!mounted) {
                    return;
                  }
                  setState(() => _videoController = video);
                },
                showControls: false,
                showPlayPauseButton: false,
                showMuteButton: true,
                showCenterPlayPauseButton: true,
                enableTapToTogglePlayback: true,
                showPausedOverlayOnly: true,
                // Built-in bar sits under caption UI and is not reliably
                // scrubbable — seek bar is drawn above overlays instead.
                showProgressBar: false,
                showLoadingIndicator: false,
                // Match feed cards: keep the video's native ratio instead of
                // cover-cropping it to the phone screen.
                fit: BoxFit.contain,
                onDoubleTap: _onDoubleTapLike,
              );
            }),
          )
        else
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTap: _onDoubleTapLike,
              child: AppCachedImage(imageUrl: item.imageUrl, fit: BoxFit.cover),
            ),
          ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.42),
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: LikeHeartBurst(burstTick: _likeBurst),
          ),
        ),
        Positioned(
          left: 18,
          right: 14,
          bottom: metaBottom,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _ReelMeta(
                  controller: controller,
                  reel: item,
                  onTapProfile: onTapProfile,
                  onOpenComments: () =>
                      showReelCommentsSheet(context, controller, item),
                ),
              ),
              const SizedBox(width: 10),
              _ReelActions(controller: controller, reel: item),
            ],
          ),
        ),
        // Above captions so taps/drags reach the seek bar (forward + back).
        // Kept clear of the floating LandingBottomNav so scrubbing and tab
        // taps do not fight each other.
        Positioned(
          left: 12,
          right: 12,
          bottom: seekBottom,
          child: AppVideoSeekBar(
            controller: _videoController,
            onScrubbingChanged: (scrubbing) {
              if (!mounted) {
                return;
              }
              setState(() => _isScrubbing = scrubbing);
            },
          ),
        ),
      ],
    );
  }

  /// Space from screen bottom to the seek bar — clears the floating nav pill
  /// plus a gap so progress scrubbing cannot land on tab icons.
  double _seekBarBottom(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    if (!widget.reserveBottomNav) {
      return safeBottom + 12;
    }
    return safeBottom +
        kBottomNavHeight +
        kBottomNavVerticalMargin +
        20; // gap between seek bar and nav pill
  }
}

class _ReelViewerShell extends StatefulWidget {
  const _ReelViewerShell({required this.body});

  final Widget body;

  @override
  State<_ReelViewerShell> createState() => _ReelViewerShellState();
}

class _ReelViewerShellState extends State<_ReelViewerShell> {
  double _dragDx = 0;

  LandingController? get _landing => Get.isRegistered<LandingController>()
      ? Get.find<LandingController>()
      : null;

  @override
  void initState() {
    super.initState();
    // The landing bar listens to this flag. Writing it here runs while
    // ReelScreen is still building, which marks that bar dirty mid-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final landing = _landing;
      if (landing != null && landing.isBottomNavCompact.value) {
        landing.isBottomNavCompact.value = false;
      }
    });
  }

  void _openTab(int index) {
    final landing = _landing;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    if (landing != null && landing.currentIndex.value != index) {
      landing.onTabChanged(index);
    }
  }

  void _onHorizontalEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dragDx = _dragDx;
    _dragDx = 0;
    // A short sideways touch stays on this reel. Only a halfway drag or a
    // real flick moves to the next main tab.
    final minDrag = MediaQuery.sizeOf(context).width * 0.5;
    if ((velocity < -1200 && dragDx < -48) || dragDx <= -minDrag) {
      _openTab(2);
      return;
    }
    if ((velocity > 1200 && dragDx > 48) || dragDx >= minDrag) {
      _openTab(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E11),
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _landing?.onPrimaryScroll(notification);
          return false;
        },
        child: GestureDetector(
          onHorizontalDragStart: (_) => _dragDx = 0,
          onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
          onHorizontalDragEnd: _onHorizontalEnd,
          onHorizontalDragCancel: () => _dragDx = 0,
          child: widget.body,
        ),
      ),
      bottomNavigationBar: const _ReelViewerBottomNav(),
    );
  }
}

class _ReelViewerBottomNav extends StatelessWidget {
  const _ReelViewerBottomNav();

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<LandingController>()) {
      return const SizedBox.shrink();
    }
    final landing = Get.find<LandingController>();
    return Obx(
      () => LandingBottomNav(
        tabs: landing.tabs,
        currentIndex: 1,
        compact: landing.isBottomNavCompact.value,
        onTap: (index) {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
          }
          if (landing.currentIndex.value != index) {
            landing.onTabChanged(index);
          }
        },
      ),
    );
  }
}

class _ReelFeedToggle extends StatelessWidget {
  const _ReelFeedToggle({required this.controller});

  final ReelController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ReelFeedButton(
              label: 'Style',
              selected: controller.selectedFeedType.value == ReelFeedType.style,
              onTap: () => controller.setFeedType(ReelFeedType.style),
            ),
            _ReelFeedButton(
              label: 'Bite',
              selected: controller.selectedFeedType.value == ReelFeedType.bite,
              onTap: () => controller.setFeedType(ReelFeedType.bite),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelFeedButton extends StatelessWidget {
  const _ReelFeedButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: selected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                )
              : null,
        ),
        child: Text(
          label,
          style: AppFonts.beVietnam(
            size: 11,
            weight: FontWeight.w700,
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});

  final dynamic icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: AppHeroIconData(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _CityButton extends StatelessWidget {
  const _CityButton({required this.controller, required this.onTap});

  final ReelController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final city = controller.currentReelOrNull?.city.trim() ?? '';
      if (city.isEmpty) {
        return const SizedBox.shrink();
      }

      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white.withValues(alpha: 0.1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppHeroIconData(
                HeroIcons.mapPin,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                city,
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _ReelViewCount extends StatelessWidget {
  const _ReelViewCount({required this.count});

  final String count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppHeroIconData(
            HeroIcons.eye,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            count,
            style: AppFonts.beVietnam(
              size: 12,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelMeta extends StatelessWidget {
  const _ReelMeta({
    required this.controller,
    required this.reel,
    required this.onTapProfile,
    required this.onOpenComments,
  });

  final ReelController controller;
  final ReelItemModel reel;
  final Function(ReelItemModel) onTapProfile;
  final VoidCallback onOpenComments;

  Future<void> _openHashtag(ReelItemModel live, String tag) async {
    controller.setCurrentVideoPaused(live.id, true);
    await HashtagOpenHelper.open(tag);
    if (controller.isClosed) {
      return;
    }
    if (controller.pausedReelId.value == live.id) {
      controller.setCurrentVideoPaused(live.id, false);
    }
  }

  ReelItemModel get _live {
    for (final item in controller.visibleReels) {
      if (item.id == reel.id) {
        return item;
      }
    }
    return reel;
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.biteDetailsTick.value;
      controller.visibleReels.length;
      final live = _live;
      final isBite =
          live.isBite || controller.selectedFeedType.value == ReelFeedType.bite;
      final city = live.city.trim();
      final restaurant = live.restaurant.trim();
      final dish = live.dishName.trim();
      final pin = live.pinLocation.trim();
      // Contest voting score only — never show star rating on normal reels.
      final contestScore = live.rating;

      return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() {
                  controller.sessionViewCredits[live.id];
                  return _ReelViewCount(count: controller.viewLabelFor(live.id));
                }),
                const SizedBox(height: 8),
                FollowUserButton(
                  username: live.profileUsername,
                  initialIsFollowing: live.isFollowingAuthor,
                  compact: false,
                  dark: true,
                ),
              ],
            ),
            if (isBite) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: _ReelReviewButton(
                  onTap: () => BiteReelReviewSheet.open(
                    context: context,
                    controller: controller,
                    reel: live,
                  ),
                ),
              ),
            ],
            if (live.ratingEnabled) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: AppColors.primary.withValues(alpha: 0.2),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppHeroIconData(
                      HeroIcons.star,
                      color: AppColors.primary,
                      size: 16,
                      style: HeroIconStyle.solid,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      contestScore,
                      style: AppFonts.beVietnam(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => onTapProfile(live),
              child: SizedBox(
                width: 36,
                height: 36,
                child: ClipOval(
                  child: live.hasAvatar
                      ? AppCachedImage(
                          imageUrl: live.avatarUrl,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          memCacheWidth: 108,
                        )
                      : ColoredBox(
                          color: Colors.white.withValues(alpha: 0.16),
                          child: const Center(
                            child: AppHeroIconData(
                              HeroIcons.user,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => onTapProfile(live),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            live.handle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.plusJakarta(
                              size: 19,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        VerifiedBadgeSlot(
                          username: live.profileUsername,
                          fallback: live.isVerifiedBadge,
                          size: 17,
                          spacing: 5,
                        ),
                      ],
                    ),
                  ),
                  if (isBite &&
                      (restaurant.isNotEmpty ||
                          dish.isNotEmpty ||
                          pin.isNotEmpty)) ...[
                    const SizedBox(height: 4),
                    _BiteReelPlace(
                      dishName: dish,
                      restaurant: restaurant,
                      location: pin.isNotEmpty ? pin : city,
                      onOpenLocation: () =>
                          RestaurantMapScreen.openForPost(live.toHomePost()),
                    ),
                  ] else if (city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        AppHeroIconData(
                          HeroIcons.mapPin,
                          size: 15,
                          color: Colors.white.withValues(alpha: 0.82),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.beVietnam(
                              size: 12,
                              weight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (live.caption.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          _ReelCaptionPreview(
            caption: live.caption,
            onOpenComments: onOpenComments,
            onTapHashtag: (tag) => _openHashtag(live, tag),
          ),
        ],
        if (isBite && live.hasFoodRatings) ...[
          const SizedBox(height: 8),
          _BiteReelRatings(reel: live),
        ],
        const SizedBox(height: 10),
      ],
    );
    });
  }
}

class _ReelCaptionPreview extends StatelessWidget {
  const _ReelCaptionPreview({
    required this.caption,
    required this.onOpenComments,
    required this.onTapHashtag,
  });

  final String caption;
  final VoidCallback onOpenComments;
  final ValueChanged<String> onTapHashtag;

  static const int _collapsedMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    final style = AppFonts.beVietnam(
      size: 16,
      weight: FontWeight.w500,
      height: 1.35,
      color: Colors.white,
    );

    return HashtagCaptionText(
      text: caption,
      style: style,
      maxLines: _collapsedMaxLines,
      overflow: TextOverflow.ellipsis,
      onTapHashtag: onTapHashtag,
      onTapText: onOpenComments,
    );
  }
}

class _ReelReviewButton extends StatelessWidget {
  const _ReelReviewButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Review',
          style: AppFonts.beVietnam(
            size: 12,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _BiteReelPlace extends StatelessWidget {
  const _BiteReelPlace({
    required this.dishName,
    required this.restaurant,
    required this.location,
    required this.onOpenLocation,
  });

  final String dishName;
  final String restaurant;
  final String location;
  final VoidCallback onOpenLocation;

  @override
  Widget build(BuildContext context) {
    final showLocation = location.isNotEmpty &&
        location.toLowerCase() != restaurant.toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dishName.isNotEmpty)
          Text(
            dishName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        if (restaurant.isNotEmpty) ...[
          if (dishName.isNotEmpty) const SizedBox(height: 2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenLocation,
            child: Row(
              children: [
                Icon(
                  Icons.storefront_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    restaurant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.92),
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (showLocation) ...[
          const SizedBox(height: 2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenLocation,
            child: Row(
              children: [
                const AppHeroIconData(
                  Icons.location_on_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.beVietnam(
                      size: 11,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const AppHeroIconData(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ] else if (restaurant.isNotEmpty) ...[
          const SizedBox(height: 2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onOpenLocation,
            child: Row(
              children: [
                const AppHeroIconData(
                  Icons.map_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'View on map',
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BiteReelRatings extends StatelessWidget {
  const _BiteReelRatings({required this.reel});

  final ReelItemModel reel;

  @override
  Widget build(BuildContext context) {
    final items = <(String, double)>[
      if (reel.foodRating != null) ('Food', reel.foodRating!),
      if (reel.serviceRating != null) ('Service', reel.serviceRating!),
      if (reel.staffRating != null) ('Staff', reel.staffRating!),
      if (reel.ambienceRating != null) ('Ambience', reel.ambienceRating!),
    ];
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${item.$1} ${item.$2.toStringAsFixed(item.$2 % 1 == 0 ? 0 : 1)}',
              style: AppFonts.beVietnam(
                size: 10,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReelActions extends StatelessWidget {
  const _ReelActions({required this.controller, required this.reel});

  final ReelController controller;
  final ReelItemModel reel;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      ReelItemModel? match;
      for (final item in controller.visibleReels) {
        if (item.id == reel.id) {
          match = item;
          break;
        }
      }
      final live = match ?? reel;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ActionItem(
            icon: HeroIcons.heart,
            style: live.isLiked ? HeroIconStyle.solid : HeroIconStyle.outline,
            color: live.isLiked ? Colors.redAccent : Colors.white,
            label: live.likes,
            onTap: () => controller.toggleLike(live.id),
          ),
          if (reel.ratingEnabled) ...[
            const SizedBox(height: 12),
            _ActionItem(
              icon: HeroIcons.star,
              label: reel.viewerRating?.toString() ?? 'Rate',
              isLoading: controller.isVoteLoading.value,
              onTap: () => _showRatingSheet(context, controller, reel),
            ),
          ],
          const SizedBox(height: 12),
          _ActionItem(
            icon: HeroIcons.chatBubbleLeftEllipsis,
            label: reel.comments,
            isLoading: controller.isSubmittingComment.value,
            onTap: () => showReelCommentsSheet(context, controller, reel),
          ),
          const SizedBox(height: 12),
          _ActionItem(
            icon: HeroIcons.bookmark,
            style: live.isSaved ? HeroIconStyle.solid : HeroIconStyle.outline,
            color: live.isSaved ? AppColors.primary : Colors.white,
            label: 'Save',
            onTap: () => controller.toggleSave(live.id),
          ),
          const SizedBox(height: 12),
          _ActionItem(
            icon: HeroIcons.paperAirplane,
            label: 'Share',
            isLoading: controller.isShareLoading.value,
            onTap: () => _shareReel(context, controller, reel),
          ),
          if (controller.isLoadingMore.value) ...[
            const SizedBox(height: 12),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      );
    });
  }

  Future<void> _shareReel(
    BuildContext context,
    ReelController controller,
    ReelItemModel reel,
  ) async {
    final channel = await InAppShareSheet.open(
      context: context,
      payload: InAppSharePayload.fromReel(reel),
    );
    if (channel == null) {
      return;
    }

    await controller.registerShare(reel.id, shareChannel: channel);
  }

  Future<void> _showRatingSheet(
    BuildContext context,
    ReelController controller,
    ReelItemModel reel,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF18181D),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Rate Reel',
                  style: AppFonts.plusJakarta(
                    size: 20,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Obx(
                  () => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      final isSelected = reel.viewerRating == value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: GestureDetector(
                          onTap: controller.isVoteLoading.value
                              ? null
                              : () {
                                  unawaited(
                                    controller.voteReel(reel.id, value),
                                  );
                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          child: Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white,
                            ),
                            child: controller.isVoteLoading.value && isSelected
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    '$value',
                                    style: AppFonts.beVietnam(
                                      size: 14,
                                      weight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.text,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

Future<void> showReelCommentsSheet(
  BuildContext context,
  ReelController controller,
  ReelItemModel reel,
) async {
  final alreadyPaused = controller.isReelPaused(reel.id);
  controller.setCurrentVideoPaused(reel.id, true);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ReelCommentsSheet(
        controller: controller,
        reel: reel,
      ),
    );
  } finally {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!controller.isClosed &&
          !alreadyPaused &&
          controller.pausedReelId.value == reel.id) {
        controller.setCurrentVideoPaused(reel.id, false);
      }
    });
  }
}

class _ReelCommentsSheet extends StatefulWidget {
  const _ReelCommentsSheet({
    required this.controller,
    required this.reel,
  });

  final ReelController controller;
  final ReelItemModel reel;

  @override
  State<_ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<_ReelCommentsSheet> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  ReelController get _controller => widget.controller;
  ReelItemModel get _reel => widget.reel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_controller.commentsForReel(_reel.id).isEmpty &&
          !_controller.isCommentsLoading(_reel.id)) {
        _controller.fetchCommentsForReel(_reel.id, reset: true);
      }
    });
  }

  @override
  void dispose() {
    _inputFocusNode.unfocus();
    _inputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    if (_inputFocusNode.hasFocus) {
      _inputFocusNode.unfocus();
    }
  }

  Future<void> _submitComment() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _dismissKeyboard();
    await _controller.submitComment(_reel.id, text);
    if (mounted) {
      _inputController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.38,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismissKeyboard,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7E2E0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Comments',
                          style: AppFonts.plusJakarta(
                            size: 20,
                            weight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const AppHeroIconData(HeroIcons.xMark),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _dismissKeyboard(),
                  child: Obx(() {
                    final comments = _controller.commentsForReel(_reel.id);
                    final loadingComments =
                        _controller.isCommentsLoading(_reel.id) &&
                        comments.isEmpty;
                    final extra =
                        _controller.hasMoreComments(_reel.id) ? 1 : 0;
                    VerifiedBadgeCache.revision.value;

                    return NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification.metrics.extentAfter < 200) {
                          _controller.fetchCommentsForReel(_reel.id);
                        }
                        return false;
                      },
                      child: ListView.separated(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: 1 +
                            (loadingComments || comments.isEmpty
                                ? 1
                                : comments.length) +
                            extra,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return CommentsCaptionHeader(
                              handle: _reel.handle,
                              caption: _reel.caption,
                              avatarUrl: _reel.avatarUrl,
                              username: _reel.profileUsername,
                              isVerified: _reel.isVerifiedBadge,
                            );
                          }
                          if (loadingComments) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final commentIndex = index - 1;
                          if (comments.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                              ),
                              child: Center(
                                child: Text(
                                  'No comments yet',
                                  style: AppFonts.beVietnam(
                                    size: 14,
                                    weight: FontWeight.w500,
                                    color: AppColors.hintText,
                                  ),
                                ),
                              ),
                            );
                          }
                          if (commentIndex >= comments.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }

                          final comment = comments[commentIndex];
                          final canDelete = comment.isOwnedByViewer;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundImage: comment.hasAvatar
                                        ? NetworkImage(comment.avatar)
                                        : null,
                                    child: comment.hasAvatar
                                        ? null
                                        : const AppHeroIconData(
                                            HeroIcons.user,
                                            size: 16,
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: GestureDetector(
                                      onLongPress: canDelete
                                          ? () => _deleteReelComment(
                                              context,
                                              _controller,
                                              _reel.id,
                                              comment.id,
                                            )
                                          : null,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F0EF),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: RichText(
                                          text: TextSpan(
                                            children:
                                                AppVerifiedName.inlineSpans(
                                              name: comment.displayName,
                                              username: comment.user,
                                              isVerified:
                                                  comment.isVerifiedBadge,
                                              style: AppFonts.beVietnam(
                                                size: 13,
                                                weight: FontWeight.w700,
                                                color: AppColors.text,
                                              ),
                                              suffix: ' ${comment.text}',
                                              suffixStyle: AppFonts.beVietnam(
                                                size: 13,
                                                weight: FontWeight.w500,
                                                color: AppColors.text,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 42,
                                  top: 4,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      comment.time,
                                      style: AppFonts.beVietnam(
                                        size: 11,
                                        weight: FontWeight.w500,
                                        color: AppColors.hintText,
                                      ),
                                    ),
                                    if (canDelete) ...[
                                      const SizedBox(width: 10),
                                      InkWell(
                                        onTap: () => _deleteReelComment(
                                          context,
                                          _controller,
                                          _reel.id,
                                          comment.id,
                                        ),
                                        child: Text(
                                          'Delete',
                                          style: AppFonts.beVietnam(
                                            size: 11,
                                            weight: FontWeight.w700,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send,
                      onTap: () => _inputFocusNode.requestFocus(),
                      onSubmitted: (_) => _submitComment(),
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: AppFonts.beVietnam(
                          size: 13,
                          weight: FontWeight.w500,
                          color: AppColors.hintText,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF3F0EF),
                        border: OutlineInputBorder(
                          borderSide: BorderSide.none,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Obx(
                    () => InkWell(
                      onTap: _controller.isSubmittingComment.value
                          ? null
                          : _submitComment,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                        ),
                        child: _controller.isSubmittingComment.value
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const AppHeroIconData(
                                HeroIcons.paperAirplane,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

  Future<void> _deleteReelComment(
    BuildContext context,
    ReelController controller,
    String reelId,
    String commentId,
  ) async {
    final confirmed = await showDeleteCommentConfirmationSheet(context);
    if (confirmed != true) {
      return;
    }
    await controller.deleteComment(reelId, commentId);
  }

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.style,
    this.color,
  });

  final dynamic icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final HeroIconStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: isLoading ? null : onTap,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AppHeroIconData(
                  icon,
                  color: (color ?? Colors.white).withValues(
                    alpha: isLoading ? 0.72 : 1,
                  ),
                  size: 30,
                  style: style,
                ),
                if (isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: AppFonts.beVietnam(
            size: 11,
            weight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.88),
          ),
        ),
      ],
    );
  }
}
