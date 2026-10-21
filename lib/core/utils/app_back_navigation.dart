import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../modules/landing/controllers/landing_controller.dart';

class AppBackNavigation {
  const AppBackNavigation._();

  static Future<void> handleBack() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final navigator = Get.key.currentState;
    if (navigator?.canPop() ?? false) {
      Get.back();
      return;
    }

    if (Get.currentRoute == AppRoutes.landing &&
        Get.isRegistered<LandingController>()) {
      final landingController = Get.find<LandingController>();
      if (landingController.currentIndex.value != 0) {
        landingController.currentIndex.value = 0;
        landingController.isBottomNavCompact.value = false;
        return;
      }

      await SystemNavigator.pop();
      return;
    }

    await Get.offAllNamed(AppRoutes.landing);
  }
}
