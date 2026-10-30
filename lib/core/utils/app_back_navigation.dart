import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../modules/landing/controllers/landing_controller.dart';

class AppBackNavigation {
  const AppBackNavigation._();

  /// Blocks a second back in the same gesture/frame (predictive back +
  /// PopScope can invoke the handler twice and skip a page).
  static bool _locked = false;

  static Future<void> handleBack() async {
    if (_locked) {
      return;
    }
    _locked = true;
    try {
      FocusManager.instance.primaryFocus?.unfocus();

      // One press should dismiss an overlay first — not the page under it.
      if (Get.isDialogOpen == true) {
        Get.back<void>();
        return;
      }
      if (Get.isBottomSheetOpen == true) {
        Get.back<void>();
        return;
      }
      if (Get.isSnackbarOpen) {
        Get.closeCurrentSnackbar();
        return;
      }

      final navigator = Get.key.currentState;
      if (navigator != null && navigator.canPop()) {
        // Prefer Navigator.pop once. Get.back() can race with PopScope /
        // Cupertino popGesture and remove a second route.
        navigator.pop();
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
    } finally {
      // Cover route transition (~220ms) so a duplicate pop event is ignored.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _locked = false;
      });
    }
  }
}
