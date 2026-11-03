import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  Map<String, dynamic> get _args =>
      (Get.arguments as Map<String, dynamic>?) ?? const {};

  String get _title =>
      (_args['title'] as String?)?.trim().isNotEmpty == true
          ? (_args['title'] as String).trim()
          : 'Update required';

  String get _body =>
      (_args['body'] as String?)?.trim().isNotEmpty == true
          ? (_args['body'] as String).trim()
          : 'A new version of StyleBite is available. Please update to continue.';

  String get _storeUrl => (_args['storeUrl'] as String?)?.trim() ?? '';

  Future<void> _openStore() async {
    final raw = _storeUrl;
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
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: AppFonts.plusJakarta(
                    size: 24,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _body,
                  textAlign: TextAlign.center,
                  style: AppFonts.beVietnam(
                    size: 15,
                    weight: FontWeight.w500,
                    height: 1.45,
                    color: AppColors.hintText,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
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
        ),
      ),
    );
  }
}
