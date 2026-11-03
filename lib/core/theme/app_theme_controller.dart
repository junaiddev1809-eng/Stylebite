import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../utils/local_storage.dart';
import 'app_palette.dart';

/// Owns appearance mode. Default is [ThemeMode.light] so existing UI is unchanged
/// until the user picks Dark / System in Settings.
class AppThemeController extends GetxController with WidgetsBindingObserver {
  final Rx<ThemeMode> themeMode = ThemeMode.light.obs;

  /// Bumped on every appearance change so Obx shells rebuild even when they
  /// only read [AppColors] getters (which are not InheritedWidget-based).
  final RxInt revision = 0.obs;

  static AppThemeController get instance => Get.find<AppThemeController>();

  static bool get isRegistered => Get.isRegistered<AppThemeController>();

  /// Safe for [AppColors] getters before/after Get registration.
  static StyleBitePalette get paletteOrLight {
    if (!isRegistered) {
      return StyleBitePalette.light;
    }
    return instance.palette;
  }

  /// Call at the top of Obx builders that paint [AppColors] surfaces.
  static int get watchRevision {
    if (!isRegistered) {
      return 0;
    }
    return instance.revision.value;
  }

  StyleBitePalette get palette {
    switch (themeMode.value) {
      case ThemeMode.light:
        return StyleBitePalette.light;
      case ThemeMode.dark:
        return StyleBitePalette.dark;
      case ThemeMode.system:
        return _platformBrightness == Brightness.dark
            ? StyleBitePalette.dark
            : StyleBitePalette.light;
    }
  }

  bool get isDark => palette == StyleBitePalette.dark;

  Brightness get _platformBrightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void onInit() {
    super.onInit();
    themeMode.value = _readStoredMode();
    WidgetsBinding.instance.addObserver(this);
    _applySystemUi();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangePlatformBrightness() {
    if (themeMode.value == ThemeMode.system) {
      revision.value++;
      _applySystemUi();
      Get.forceAppUpdate();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode.value == mode) {
      return;
    }
    themeMode.value = mode;
    revision.value++;
    await LocalStorage.setThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
    _applySystemUi();
    // IndexedStack / cached routes also need a rebuild for AppColors getters.
    Get.forceAppUpdate();
  }

  void _applySystemUi() {
    final p = palette;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: p.statusBarIconBrightness,
        statusBarBrightness: p.statusBarIconBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: p.navBar,
        systemNavigationBarIconBrightness: p.systemNavIconBrightness,
      ),
    );
  }

  ThemeMode _readStoredMode() {
    final raw = LocalStorage.getThemeMode();
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  static String labelFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}
