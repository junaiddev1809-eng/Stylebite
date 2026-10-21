import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';

import '../../contest/controllers/contest_controller.dart';
import '../../home/controllers/home_controller.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../reel/controllers/reel_controller.dart';
import '../../upload/controllers/upload_controller.dart';
import '../models/landing_tab_model.dart';

class LandingController extends GetxController {
  final RxInt currentIndex = 0.obs;
  final RxBool isBottomNavCompact = false.obs;
  final PageController pageController = PageController();

  /// Suggested-reel drags and vertical feed drags hold this so a sideways
  /// swipe does not steal the gesture from the list under the finger.
  final ValueNotifier<int> horizontalChildLocks = ValueNotifier(0);

  bool _verticalDragLocksPager = false;
  double _navScrollBucket = 0;
  int _gestureSerial = 0;
  int _dragSerial = 0;
  int? _dragOriginPage;

  final List<LandingTabModel> tabs = LandingTabModel.defaultTabs;

  void lockHorizontalPage() {
    horizontalChildLocks.value++;
  }

  void unlockHorizontalPage() {
    final next = horizontalChildLocks.value - 1;
    horizontalChildLocks.value = next < 0 ? 0 : next;
  }

  @override
  void onClose() {
    pageController.dispose();
    horizontalChildLocks.dispose();
    super.onClose();
  }

  void onTabChanged(int index) {
    _gestureSerial++;
    _dragOriginPage = null;
    // Tapping the tab that is already open jumps back to the top.
    if (index == currentIndex.value) {
      isBottomNavCompact.value = false;
      _navScrollBucket = 0;
      _setVerticalDragLock(false);
      _scrollCurrentTabToTop(index);
      _moveToPage(index);
      return;
    }

    _publishIndex(index);
    _moveToPage(index);
  }

  /// The finger is on the tab pager. Stop any settle animation and remember
  /// which page the drag started on.
  void beginUserPageDrag() {
    _dragSerial = ++_gestureSerial;
    if (!pageController.hasClients) {
      _dragOriginPage = currentIndex.value;
      return;
    }
    final position = pageController.position;
    position.jumpTo(position.pixels);
    final width = position.viewportDimension;
    if (width <= 0) {
      _dragOriginPage = currentIndex.value;
      return;
    }
    _dragOriginPage = (position.pixels / width)
        .round()
        .clamp(0, tabs.length - 1)
        .toInt();
  }

  /// [dx] is the finger movement. Left is negative and reveals the next page.
  void updateUserPageDrag(double dx) {
    if (_dragOriginPage == null || !pageController.hasClients) {
      return;
    }
    final position = pageController.position;
    final next = (position.pixels - dx).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((next - position.pixels).abs() < 0.1) {
      return;
    }
    position.jumpTo(next);
  }

  /// A slow drag must bring the next page at least halfway across. A short
  /// drag springs back. A quick flick can finish the change.
  void endUserPageDrag(double velocity) {
    final origin = _dragOriginPage;
    _dragOriginPage = null;
    if (origin == null) {
      return;
    }
    final serial = _dragSerial;
    if (!pageController.hasClients) {
      _publishIndex(origin);
      return;
    }
    final width = pageController.position.viewportDimension;
    if (width <= 0) {
      unawaited(_settleTo(origin, serial, velocity));
      return;
    }
    final page = pageController.position.pixels / width;
    final delta = page - origin;
    var target = origin;
    const halfway = 0.5;
    const flickSpeed = 1200.0;
    const flickDistance = 0.12;
    if (velocity <= -flickSpeed && delta >= flickDistance) {
      target = origin + 1;
    } else if (velocity >= flickSpeed && delta <= -flickDistance) {
      target = origin - 1;
    } else if (delta >= halfway) {
      target = origin + 1;
    } else if (delta <= -halfway) {
      target = origin - 1;
    }
    unawaited(
      _settleTo(target.clamp(0, tabs.length - 1).toInt(), serial, velocity),
    );
  }

  void cancelUserPageDrag() {
    final origin = _dragOriginPage ?? currentIndex.value;
    _dragOriginPage = null;
    unawaited(_settleTo(origin, _dragSerial, 0));
  }

  Future<void> _settleTo(int index, int serial, double velocity) async {
    if (isClosed || !pageController.hasClients) {
      return;
    }
    final width = pageController.position.viewportDimension;
    final page = width <= 0
        ? index.toDouble()
        : pageController.position.pixels / width;
    final remaining = (index - page).abs();
    if (remaining >= 0.004) {
      final fast = velocity.abs() >= 1200;
      final ms = (remaining * (fast ? 220 : 340))
          .round()
          .clamp(fast ? 160 : 220, fast ? 280 : 400)
          .toInt();
      try {
        await pageController.animateToPage(
          index,
          duration: Duration(milliseconds: ms),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {
        if (isClosed) {
          return;
        }
        rethrow;
      }
    }
    if (isClosed || serial != _gestureSerial) {
      return;
    }
    _publishIndex(index);
  }

  void _publishIndex(int index) {
    if (index == currentIndex.value) {
      return;
    }
    final previous = currentIndex.value;
    currentIndex.value = index;
    isBottomNavCompact.value = false;
    _navScrollBucket = 0;
    _setVerticalDragLock(false);
    FocusManager.instance.primaryFocus?.unfocus();
    _syncReelVisibility(previous: previous, next: index);
    if (Get.isRegistered<UploadController>() && index == 2) {
      Get.find<UploadController>().clearStatusMessages();
    }
  }

  void onPrimaryScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return;
    }
    // Each screen sits inside the tab pager, so its vertical scroll arrives
    // here at depth 1. Deeper lists are nested and should not resize the bar.
    if (notification.depth > 1) {
      return;
    }

    // A vertical drag must not also move the horizontal tab pager. That fight
    // is what makes the feed stutter on the way up and on the way down.
    if (notification is UserScrollNotification) {
      _setVerticalDragLock(notification.direction != ScrollDirection.idle);
    } else if (notification is ScrollEndNotification) {
      _setVerticalDragLock(false);
    }

    if (notification.metrics.pixels <= 12) {
      _navScrollBucket = 0;
      if (isBottomNavCompact.value) {
        isBottomNavCompact.value = false;
      }
      return;
    }

    if (notification is! ScrollUpdateNotification) {
      return;
    }
    final delta = notification.scrollDelta ?? 0;
    if (delta == 0) {
      return;
    }
    // Tiny reversals used to flip the bar immediately and restart its
    // animation, which shook the viewport. Require a real run in one
    // direction before the bar changes size.
    if (_navScrollBucket != 0 && delta.sign != _navScrollBucket.sign) {
      _navScrollBucket = 0;
    }
    _navScrollBucket += delta;
    const threshold = 72.0;
    if (_navScrollBucket > threshold && !isBottomNavCompact.value) {
      isBottomNavCompact.value = true;
      _navScrollBucket = 0;
    } else if (_navScrollBucket < -threshold && isBottomNavCompact.value) {
      isBottomNavCompact.value = false;
      _navScrollBucket = 0;
    }
  }

  void _setVerticalDragLock(bool locked) {
    if (locked == _verticalDragLocksPager) {
      return;
    }
    _verticalDragLocksPager = locked;
    if (locked) {
      lockHorizontalPage();
    } else {
      unlockHorizontalPage();
    }
  }

  void _scrollCurrentTabToTop(int index) {
    switch (index) {
      case 0:
        if (Get.isRegistered<HomeController>()) {
          unawaited(Get.find<HomeController>().scrollToTop());
        }
        break;
      case 1:
        if (Get.isRegistered<ReelController>()) {
          unawaited(Get.find<ReelController>().scrollToTop());
        }
        break;
      case 3:
        if (Get.isRegistered<ContestController>()) {
          unawaited(Get.find<ContestController>().scrollToTop());
        }
        break;
      case 4:
        if (Get.isRegistered<ProfileController>()) {
          unawaited(Get.find<ProfileController>().scrollToTop());
        }
        break;
    }
  }

  void _moveToPage(int index) {
    if (!pageController.hasClients) {
      return;
    }
    final page = pageController.page ?? currentIndex.value.toDouble();
    if ((page - index).abs() < 0.01) {
      return;
    }
    // One tab slides. A longer jump would pass through empty pages.
    if ((page - index).abs() < 1.01) {
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    pageController.jumpToPage(index);
  }

  void _syncReelVisibility({required int previous, required int next}) {
    if (!Get.isRegistered<ReelController>()) {
      return;
    }
    final reels = Get.find<ReelController>();
    if (next == 1) {
      reels.setFeedVisible(true);
    } else if (previous == 1) {
      reels.setFeedVisible(false);
    }
  }
}
