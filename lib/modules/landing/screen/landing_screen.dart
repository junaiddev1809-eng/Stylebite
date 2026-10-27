import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../controllers/landing_controller.dart';
import '../widgets/landing_bottom_nav.dart';
import '../widgets/landing_home_tab.dart';
import '../../contest/screen/contest_screen.dart';
import '../../notifications/controllers/notifications_controller.dart';
import '../../post/controllers/restaurant_review_store.dart';
import '../../post/services/post_interaction_store.dart';
import '../../profile/screen/profile_swipe_screen.dart';
import '../../reel/controllers/reel_controller.dart';
import '../../reel/screen/reel_screen.dart';
import '../../upload/screen/upload_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  late final LandingController _controller;
  final List<Widget?> _pages = List<Widget?>.filled(5, null);

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<LandingController>()
        ? Get.find<LandingController>()
        : Get.put(LandingController());
    if (!Get.isRegistered<NotificationsController>()) {
      Get.put(NotificationsController(), permanent: true);
    }
    if (!Get.isRegistered<RestaurantReviewStore>()) {
      Get.put(RestaurantReviewStore(), permanent: true);
    }
    PostInteractionStore.ensure();
    ReelController.ensureTabController();
    _warm(0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetIndex = widget.initialIndex.clamp(0, 4);
      if (_controller.currentIndex.value != targetIndex) {
        _controller.onTabChanged(targetIndex);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _warm(int index) {
    for (final i in <int>[index - 1, index, index + 1]) {
      if (i < 0 || i >= _pages.length || _pages[i] != null) {
        continue;
      }
      _pages[i] = _pageFor(i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (_controller.currentIndex.value != 0) {
          _controller.onTabChanged(0);
          return;
        }
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        extendBody: true,
        backgroundColor: AppColors.background,
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _controller.onPrimaryScroll(notification);
            return false;
          },
          // The pager does not listen to every touch. A carousel or other
          // horizontal control wins its own drag. A clear sideways drag
          // follows the finger, then settles only if it was a real page swipe.
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              _LandingPageSwipeRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                      _LandingPageSwipeRecognizer>(
                () => _LandingPageSwipeRecognizer(
                  isLocked: () => _controller.horizontalChildLocks.value > 0,
                ),
                (recognizer) {
                  recognizer
                    ..onStart = (_) {
                      _warm(_controller.currentIndex.value);
                      _controller.beginUserPageDrag();
                    }
                    ..onUpdate = (details) {
                      _controller.updateUserPageDrag(
                        details.primaryDelta ?? details.delta.dx,
                      );
                    }
                    ..onEnd = (details) {
                      _controller.endUserPageDrag(details.primaryVelocity ?? 0);
                    }
                    ..onCancel = _controller.cancelUserPageDrag;
                },
              ),
            },
            child: Obx(() {
              final index = _controller.currentIndex.value;
              _warm(index);
              return PageView.builder(
                controller: _controller.pageController,
                physics: const NeverScrollableScrollPhysics(),
                allowImplicitScrolling: true,
                itemCount: _pages.length,
                itemBuilder: (context, pageIndex) {
                  final page = _pages[pageIndex];
                  return TickerMode(
                    enabled: pageIndex == index,
                    child: ColoredBox(
                      color: pageIndex == 1
                          ? const Color(0xFF0E0E11)
                          : AppColors.background,
                      child: page ?? const SizedBox.expand(),
                    ),
                  );
                },
              );
            }),
          ),
        ),
        // Reels are full-bleed like TikTok/IG — no docked pill on that tab.
        bottomNavigationBar: Obx(() {
          if (_controller.currentIndex.value == 1) {
            return const SizedBox.shrink();
          }
          return LandingBottomNav(
            tabs: _controller.tabs,
            currentIndex: _controller.currentIndex.value,
            onTap: _controller.onTabChanged,
            compact: _controller.isBottomNavCompact.value,
          );
        }),
      ),
    );
  }
}

Widget _pageFor(int index) {
  switch (index) {
    case 0:
      return const LandingHomeTab();
    case 1:
      return const ReelScreen();
    case 2:
      return const UploadScreen();
    case 3:
      return const ContestScreen();
    case 4:
      return const ProfileSwipeScreen();
    default:
      return const LandingHomeTab();
  }
}

/// Claims a sideways drag only after horizontal controls have had a chance
/// to take it. A short move is not enough to switch tabs.
class _LandingPageSwipeRecognizer extends OneSequenceGestureRecognizer {
  _LandingPageSwipeRecognizer({required this.isLocked});

  final bool Function() isLocked;

  GestureDragStartCallback? onStart;
  GestureDragUpdateCallback? onUpdate;
  GestureDragEndCallback? onEnd;
  GestureDragCancelCallback? onCancel;

  int? _pointer;
  Offset _origin = Offset.zero;
  Offset _pending = Offset.zero;
  bool _accepted = false;
  bool _dead = false;
  bool _acceptQueued = false;
  bool _tracking = false;
  final List<_SwipeSample> _samples = <_SwipeSample>[];

  @override
  String get debugDescription => 'landingPageSwipe';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) {
      resolvePointer(event.pointer, GestureDisposition.rejected);
      return;
    }
    _pointer = event.pointer;
    _origin = event.position;
    _pending = Offset.zero;
    _accepted = false;
    _dead = false;
    _acceptQueued = false;
    _samples.clear();
    _tracking = true;
    startTrackingPointer(event.pointer, event.transform);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (_dead || event.pointer != _pointer) {
      return;
    }
    if (event is PointerMoveEvent) {
      _pending += event.delta;
      _remember(event);
      if (_accepted) {
        onUpdate?.call(
          DragUpdateDetails(
            sourceTimeStamp: event.timeStamp,
            delta: Offset(event.delta.dx, 0),
            primaryDelta: event.delta.dx,
            globalPosition: event.position,
            localPosition: event.localPosition,
          ),
        );
        return;
      }
      if (_pending.distance < kTouchSlop) {
        return;
      }
      // A feed scroll is almost never a perfect vertical line. Accept a tab
      // change only when the finger is clearly moving sideways. Anything else
      // goes back to the list immediately, or the list freezes under the finger.
      if (!_isClearlyHorizontal() || isLocked()) {
        resolve(GestureDisposition.rejected);
        return;
      }
      _queueAccept();
      return;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _remember(event);
      if (_accepted && event is PointerUpEvent) {
        final velocity = _velocityX();
        onEnd?.call(
          DragEndDetails(
            velocity: Velocity(pixelsPerSecond: Offset(velocity, 0)),
            primaryVelocity: velocity,
            globalPosition: event.position,
            localPosition: event.localPosition,
          ),
        );
      } else if (_accepted) {
        onCancel?.call();
      } else {
        resolve(GestureDisposition.rejected);
      }
      _stop(event.pointer);
    }
  }

  bool _isClearlyHorizontal() {
    return _pending.dx.abs() >= kTouchSlop &&
        _pending.dx.abs() >= _pending.dy.abs() * 2.2;
  }

  void _queueAccept() {
    if (_acceptQueued || _dead || _accepted) {
      return;
    }
    _acceptQueued = true;
    // Let a carousel or horizontal list accept this same move first.
    scheduleMicrotask(() {
      if (_dead || _accepted || _pointer == null) {
        return;
      }
      if (!_isClearlyHorizontal() || isLocked()) {
        resolve(GestureDisposition.rejected);
        return;
      }
      resolve(GestureDisposition.accepted);
    });
  }

  @override
  void acceptGesture(int pointer) {
    if (pointer != _pointer || _dead) {
      return;
    }
    _accepted = true;
    final caughtUp = _pending.dx;
    onStart?.call(DragStartDetails(globalPosition: _origin));
    if (caughtUp != 0) {
      onUpdate?.call(
        DragUpdateDetails(
          delta: Offset(caughtUp, 0),
          primaryDelta: caughtUp,
          globalPosition: _origin + _pending,
          localPosition: _origin + _pending,
        ),
      );
    }
  }

  @override
  void rejectGesture(int pointer) {
    final accepted = _accepted;
    _dead = true;
    _accepted = false;
    _acceptQueued = false;
    if (accepted) {
      onCancel?.call();
    }
    _stop(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    _tracking = false;
  }

  void _stop(int pointer) {
    if (!_tracking) {
      _pointer = null;
      return;
    }
    _tracking = false;
    stopTrackingPointer(pointer);
  }

  void _remember(PointerEvent event) {
    final now = event.timeStamp;
    _samples.add(_SwipeSample(now, event.position));
    while (
        _samples.length > 2 &&
        now - _samples.first.time > const Duration(milliseconds: 90)) {
      _samples.removeAt(0);
    }
  }

  double _velocityX() {
    if (_samples.length < 2) {
      return 0;
    }
    final first = _samples.first;
    final last = _samples.last;
    final seconds = (last.time - first.time).inMicroseconds / 1000000.0;
    if (seconds <= 0.001) {
      return 0;
    }
    return (last.position.dx - first.position.dx) / seconds;
  }

  @override
  void dispose() {
    onStart = null;
    onUpdate = null;
    onEnd = null;
    onCancel = null;
    super.dispose();
  }
}

class _SwipeSample {
  const _SwipeSample(this.time, this.position);

  final Duration time;
  final Offset position;
}
