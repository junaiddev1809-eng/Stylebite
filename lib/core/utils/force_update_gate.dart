import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'api_helper.dart';

class ForceUpdateResult {
  const ForceUpdateResult({
    required this.required,
    this.storeUrl = '',
    this.title = 'Update required',
    this.body =
        'A new version of StyleBite is available. Please update to continue.',
  });

  final bool required;
  final String storeUrl;
  final String title;
  final String body;
}

/// Blocks the app when admin enables force update and this build is below
/// the configured minimum. Fail-open on network errors so offline users
/// are not locked out.
class ForceUpdateGate {
  ForceUpdateGate._();

  static Future<ForceUpdateResult> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final platform = _platformKey();
      if (platform == null) {
        return const ForceUpdateResult(required: false);
      }

      final response = await ApiHelper.getRequest(
        'app/version-check?platform=$platform&app_version=${Uri.encodeQueryComponent(info.version)}',
      ).timeout(const Duration(seconds: 8));

      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300) {
        return const ForceUpdateResult(required: false);
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map) {
        return const ForceUpdateResult(required: false);
      }

      final required = payload['update_required'] == true ||
          payload['update_required'] == 1 ||
          payload['update_required'] == '1';
      if (!required) {
        return const ForceUpdateResult(required: false);
      }

      return ForceUpdateResult(
        required: true,
        storeUrl: (payload['store_url'] ?? '').toString().trim(),
        title: (payload['title'] ?? 'Update required').toString(),
        body: (payload['body'] ??
                'A new version of StyleBite is available. Please update to continue.')
            .toString(),
      );
    } catch (_) {
      return const ForceUpdateResult(required: false);
    }
  }

  /// Non-dismissible full-screen gate. Returns only if the check says no
  /// update is required (or the check failed open).
  static Future<bool> blockIfRequired() async {
    final result = await check();
    if (!result.required) {
      return false;
    }

    await Get.dialog<void>(
      PopScope(
        canPop: false,
        child: _ForceUpdateDialog(result: result),
      ),
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
    );
    return true;
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

class _ForceUpdateDialog extends StatelessWidget {
  const _ForceUpdateDialog({required this.result});

  final ForceUpdateResult result;

  Future<void> _openStore() async {
    final raw = result.storeUrl.trim();
    if (raw.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              result.title,
              textAlign: TextAlign.center,
              style: AppFonts.plusJakarta(
                size: 20,
                weight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              result.body,
              textAlign: TextAlign.center,
              style: AppFonts.beVietnam(
                size: 14,
                weight: FontWeight.w500,
                color: AppColors.hintText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => unawaited(_openStore()),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Update now',
                  style: AppFonts.beVietnam(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
