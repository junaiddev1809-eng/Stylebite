import 'dart:async';
import 'dart:convert';

import 'package:get/get.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_device_service.dart';
import 'package:stylebite/core/utils/app_session.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/core/utils/deep_link_service.dart';
import 'package:stylebite/core/utils/push_notification_service.dart';

import '../../../app/routes/app_routes.dart';
import '../../home/controllers/home_controller.dart';
import '../../post/services/post_interaction_store.dart';
import '../../reel/controllers/reel_controller.dart';
import '../models/splash_model.dart';

class SplashController extends GetxController {
  final SplashModel model = const SplashModel(
    title: 'Your Daily Style Bite',
    subtitle: 'Preparing your feed...',
  );

  final RxDouble progress = 0.08.obs;
  final RxString status = 'Loading StyleBite...'.obs;

  bool _hasNavigated = false;

  @override
  void onReady() {
    super.onReady();
    unawaited(_boot());
  }

  void enterNow() {
    unawaited(_finish(immediate: true));
  }

  Future<void> navigateToIntro() async {
    enterNow();
  }

  Future<void> _boot() async {
    if (_hasNavigated) {
      return;
    }

    _setProgress(0.4, model.subtitle);
    // Show the logo briefly, then leave. The feed loads on the next screen.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (_hasNavigated) {
      return;
    }
    _setProgress(1, 'Ready');
    await _finish(immediate: false);
  }

  Future<void> _finish({required bool immediate}) async {
    if (_hasNavigated) {
      return;
    }

    final route = _targetRoute();
    if (route == AppRoutes.landing) {
      _startSessionInBackground();
      HomeController.ensureController();
      ReelController.ensureTabController();
    }

    if (immediate) {
      progress.value = 1;
      status.value = 'Opening StyleBite...';
    }

    _go(route);
    if (route == AppRoutes.landing) {
      unawaited(DeepLinkService.flushPending());
    }
    if (route == AppRoutes.login) {
      unawaited(PushNotificationService.requestPermission());
    }
  }

  String _targetRoute() {
    if (!LocalStorage.hasSeenIntro()) {
      return AppRoutes.intro;
    }
    final accessKey = LocalStorage.getAccessKey();
    if (accessKey != null && accessKey.isNotEmpty) {
      return AppRoutes.landing;
    }
    return AppRoutes.login;
  }

  void _startSessionInBackground() {
    unawaited(_validateSessionInBackground());
    unawaited(AppSession.attachRealtimeIfNeeded());
    unawaited(AppDeviceService.syncPushToken());
  }

  void _setProgress(double value, String message) {
    if (value > progress.value) {
      progress.value = value.clamp(0, 1);
    }
    status.value = message;
  }

  void _go(String route) {
    if (_hasNavigated) {
      return;
    }
    _hasNavigated = true;
    Get.offNamed(route);
  }

  Future<void> _validateSessionInBackground() async {
    final session = await _checkLocalSession();
    if (session != _SessionCheck.invalid) {
      return;
    }
    await LocalStorage.removeAccessKey();
    await LocalStorage.removeUsername();
    await LocalStorage.removeUserId();
    await LocalStorage.removeAvatarUrl();
    PostInteractionStore.ensure().clear();
    if (Get.currentRoute == AppRoutes.login) {
      return;
    }
    Get.offAllNamed(AppRoutes.login);
  }

  Future<_SessionCheck> _checkLocalSession() async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'profile/me',
        interceptAuthFailure: false,
      );
      if (response == null) {
        return _SessionCheck.unreachable;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return _SessionCheck.invalid;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _SessionCheck.unreachable;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return _SessionCheck.invalid;
      }
      final ok = payload['status_code'] == 1 || payload['status_code'] == '1';
      return ok ? _SessionCheck.valid : _SessionCheck.invalid;
    } catch (_) {
      return _SessionCheck.unreachable;
    }
  }
}

enum _SessionCheck { valid, invalid, unreachable }
