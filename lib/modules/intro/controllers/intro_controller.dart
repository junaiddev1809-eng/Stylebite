import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/core/utils/push_notification_service.dart';

import '../../../app/routes/app_routes.dart';
import '../models/intro_step_model.dart';

class IntroController extends GetxController {
  final PageController pageController = PageController();
  final RxInt currentIndex = 0.obs;

  final List<IntroStepModel> steps = const [
    IntroStepModel(
      icon: Icons.style_rounded,
      title: 'Discover Fresh Looks',
      description:
          'Get bite-sized style picks curated daily to keep your wardrobe up to date.',
    ),
    IntroStepModel(
      icon: Icons.auto_awesome_rounded,
      title: 'Personalized For You',
      description:
          'Swipe through trends, save favorites, and build your own fashion feed.',
    ),
    IntroStepModel(
      icon: Icons.shopping_bag_rounded,
      title: 'Shop Smart, Fast',
      description:
          'Jump from inspiration to outfit in seconds with direct product links.',
    ),
  ];

  bool get isLastStep => currentIndex.value == steps.length - 1;

  void onPageChanged(int index) {
    currentIndex.value = index;
  }

  Future<void> next() async {
    if (isLastStep) {
      await skip();
      return;
    }

    await pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> skip() async {
    await LocalStorage.setHasSeenIntro(hasSeenIntro: true);
    Get.offNamed(AppRoutes.login);
    unawaited(PushNotificationService.requestPermission());
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
