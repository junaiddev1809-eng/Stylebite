import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'local_storage.dart';

class AppLoginIdService {
  AppLoginIdService._();

  static String? getSavedLoginId() => LocalStorage.getSavedLoginId();

  static Future<bool> rememberLoginIdIfAllowed(
    String loginId, {
    BuildContext? context,
  }) async {
    final normalized = loginId.trim();
    if (normalized.isEmpty) {
      return false;
    }

    final consent = LocalStorage.getRememberLoginIdConsent();
    if (consent == true) {
      LocalStorage.setSavedLoginId(loginId: normalized);
      return true;
    }

    final dialogContext = context;
    if (dialogContext == null || !dialogContext.mounted) {
      return false;
    }

    final shouldRemember = await _showRememberLoginIdDialog(dialogContext);

    if (shouldRemember == true) {
      LocalStorage.setRememberLoginIdConsent(allowed: true);
      LocalStorage.setSavedLoginId(loginId: normalized);
      return true;
    }

    LocalStorage.setRememberLoginIdConsent(allowed: false);
    LocalStorage.removeSavedLoginId();
    return false;
  }

  static Future<bool?> _showRememberLoginIdDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const AppHeroIconData(
                  Icons.key_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Remember login ID?',
                  style: AppFonts.plusJakarta(
                    size: 18,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Would you like StyleBite to save this login ID on this device? '
            'That way, next time you can sign in a little faster.',
            style: AppFonts.beVietnam(
              size: 13.5,
              weight: FontWeight.w500,
              height: 1.45,
              color: AppColors.hintText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'No',
                style: AppFonts.beVietnam(
                  size: 14,
                  weight: FontWeight.w700,
                  color: AppColors.hintText,
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'Yes',
                  style: AppFonts.beVietnam(
                    size: 14,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
