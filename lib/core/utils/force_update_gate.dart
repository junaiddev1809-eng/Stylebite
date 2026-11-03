import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/routes/app_routes.dart';
import 'config.dart';

class ForceUpdateResult {
  const ForceUpdateResult({
    required this.requiredUpdate,
    this.storeUrl = '',
    this.title = 'Update required',
    this.body =
        'A new version of StyleBite is available. Please update to continue.',
  });

  final bool requiredUpdate;
  final String storeUrl;
  final String title;
  final String body;
}

/// Blocks the app when admin enables force update and this build is below
/// the configured minimum. Uses a dedicated full-screen route (not a dialog)
/// so splash dispose cannot dismiss it.
class ForceUpdateGate {
  ForceUpdateGate._();

  static bool _showing = false;

  static Future<ForceUpdateResult> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final platform = _platformKey();
      if (platform == null) {
        return const ForceUpdateResult(requiredUpdate: false);
      }

      final uri = Uri.parse(
        '${kcBaseAPIUrl}app/version-check'
        '?platform=$platform'
        '&app_version=${Uri.encodeQueryComponent(info.version)}',
      );

      final response = await http
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const ForceUpdateResult(requiredUpdate: false);
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return const ForceUpdateResult(requiredUpdate: false);
      }

      final needsUpdate = payload['update_required'] == true ||
          payload['update_required'] == 1 ||
          payload['update_required'] == '1' ||
          payload['update_required'] == 'true';
      if (!needsUpdate) {
        return const ForceUpdateResult(requiredUpdate: false);
      }

      return ForceUpdateResult(
        requiredUpdate: true,
        storeUrl: (payload['store_url'] ?? '').toString().trim(),
        title: (payload['title'] ?? 'Update required').toString(),
        body: (payload['body'] ??
                'A new version of StyleBite is available. Please update to continue.')
            .toString(),
      );
    } catch (_) {
      return const ForceUpdateResult(requiredUpdate: false);
    }
  }

  /// Replaces the navigation stack with the non-dismissible update screen.
  /// Returns true when the app is blocked.
  static Future<bool> blockIfRequired() async {
    final result = await check();
    if (!result.requiredUpdate) {
      return false;
    }
    await show(result);
    return true;
  }

  static Future<void> show(ForceUpdateResult result) async {
    if (_showing) {
      return;
    }
    _showing = true;
    try {
      await Get.offAllNamed(
        AppRoutes.forceUpdate,
        arguments: {
          'title': result.title,
          'body': result.body,
          'storeUrl': result.storeUrl,
        },
      );
    } finally {
      // Keep locked — screen has no back navigation.
      _showing = true;
    }
  }

  static Future<void> showFromPayload(Map<String, dynamic> payload) async {
    await show(
      ForceUpdateResult(
        requiredUpdate: true,
        storeUrl: (payload['store_url'] ?? '').toString().trim(),
        title: (payload['title'] ?? 'Update required').toString(),
        body: (payload['body'] ??
                'A new version of StyleBite is available. Please update to continue.')
            .toString(),
      ),
    );
  }

  static String? _platformKey() {
    if (kIsWeb) {
      return null;
    }
    if (Platform.isIOS) {
      return 'ios';
    }
    if (Platform.isAndroid) {
      return 'android';
    }
    return null;
  }
}
