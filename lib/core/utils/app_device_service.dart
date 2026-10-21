import 'dart:developer';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'api_helper.dart';
import 'local_storage.dart';
import 'push_notification_service.dart';

class LoginDeviceMetadata {
  const LoginDeviceMetadata({
    required this.deviceId,
    required this.platform,
    required this.pushToken,
    required this.appVersion,
  });

  final String deviceId;
  final String platform;
  final String pushToken;
  final String appVersion;
}

class SupportDeviceDiagnostics {
  const SupportDeviceDiagnostics({
    required this.appVersion,
    required this.platform,
    required this.deviceModel,
    required this.osVersion,
  });

  final String appVersion;
  final String platform;
  final String deviceModel;
  final String osVersion;
}

class AppDeviceService {
  AppDeviceService._();

  static Future<void> init() async {
    await _ensureDeviceId();
    await _ensureAppVersion();
  }

  static Future<LoginDeviceMetadata> getLoginMetadata() async {
    final deviceId = await _ensureDeviceId();
    final appVersion = await _ensureAppVersion();
    final pushToken = await PushNotificationService.getPushToken();

    return LoginDeviceMetadata(
      deviceId: deviceId,
      platform: _platformName,
      pushToken: pushToken,
      appVersion: appVersion,
    );
  }

  static Future<SupportDeviceDiagnostics> getSupportDiagnostics() async {
    final appVersion = await _ensureAppVersion();
    String deviceModel = 'unknown';
    String osVersion = 'unknown';

    if (!kIsWeb) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            final info = await deviceInfo.androidInfo;
            deviceModel = '${info.manufacturer} ${info.model}'.trim();
            osVersion = 'Android ${info.version.release}';
            break;
          case TargetPlatform.iOS:
            final info = await deviceInfo.iosInfo;
            deviceModel = info.utsname.machine;
            osVersion = '${info.systemName} ${info.systemVersion}';
            break;
          default:
            break;
        }
      } catch (_) {
        // Keep the 'unknown' fallbacks if the platform plugin is unavailable.
      }
    }

    return SupportDeviceDiagnostics(
      appVersion: appVersion,
      platform: _platformName,
      deviceModel: deviceModel,
      osVersion: osVersion,
    );
  }

  static Future<void> syncPushToken({String? pushToken}) async {
    final accessKey = LocalStorage.getAccessKey();
    if (accessKey == null || accessKey.isEmpty) {
      return;
    }

    try {
      final token = pushToken != null && pushToken.trim().isNotEmpty
          ? pushToken.trim()
          : await PushNotificationService.getPushToken();
      if (token.isEmpty) {
        return;
      }

      final deviceId = await _ensureDeviceId();
      final appVersion = await _ensureAppVersion();

      await ApiHelper.postRequestWithAuthorization(
        'devices/push-token',
        body: {
          'device_id': deviceId,
          'platform': _platformName,
          'push_token': token,
          'app_version': appVersion,
        },
      );
    } catch (e, stackTrace) {
      // Best-effort background sync — a failure here shouldn't interrupt
      // the user; the next launch or token refresh will retry.
      log('Unable to sync push token: $e', stackTrace: stackTrace);
    }
  }

  static Future<String> _ensureDeviceId() async {
    final savedDeviceId = LocalStorage.getDeviceId();
    if (savedDeviceId != null && savedDeviceId.isNotEmpty) {
      return savedDeviceId;
    }

    final resolvedDeviceId = await _resolveDeviceId();
    LocalStorage.setDeviceId(deviceId: resolvedDeviceId);
    return resolvedDeviceId;
  }

  static Future<String> _ensureAppVersion() async {
    final savedVersion = LocalStorage.getAppVersion();
    if (savedVersion != null && savedVersion.isNotEmpty) {
      return savedVersion;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    LocalStorage.setAppVersion(appVersion: version);
    return version;
  }

  static Future<String> _resolveDeviceId() async {
    return _buildFallbackId('generated');
  }

  static String _buildFallbackId(String seed) {
    final sanitizedSeed = seed.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-');
    return '$_platformName-${DateTime.now().microsecondsSinceEpoch}-$sanitizedSeed';
  }

  static String get _platformName {
    if (kIsWeb) {
      return 'web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
