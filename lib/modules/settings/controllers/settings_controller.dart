import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/core/theme/app_colors.dart';
import 'package:stylebite/core/theme/app_fonts.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/modules/messages/services/chat_presence_service.dart';
import 'package:stylebite/modules/messages/services/chat_socket_service.dart';

import '../../../app/routes/app_routes.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../post/services/post_interaction_store.dart';

class SettingsController extends GetxController {
  late final ProfileController profileController;

  final RxBool notificationsOn = true.obs;

  @override
  void onInit() {
    super.onInit();
    profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
  }

  void toggleNotifications() {
    notificationsOn.value = !notificationsOn.value;
  }

  Future<void> showLogoutConfirmation(BuildContext context) async {
    final shouldLogout = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: SizedBox(width: 42, child: Divider(thickness: 4)),
                ),
                const SizedBox(height: 10),
                Text(
                  'Log Out',
                  style: AppFonts.plusJakarta(
                    size: 20,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to log out of your account?',
                  style: AppFonts.beVietnam(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppColors.hintText,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: BorderSide(
                            color: AppColors.hintText.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppFonts.beVietnam(
                            size: 14,
                            weight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(999)),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Yes, Log Out',
                            style: AppFonts.beVietnam(
                              size: 14,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    // Authenticated cleanup calls must run before revoking the session —
    // markOffline() hits an endpoint with no interceptAuthFailure opt-out,
    // so if the token were already revoked it'd 401 and the app-wide
    // session-expired handler would show a spurious "Invalid or expired
    // token." toast right after this intentional logout.
    await ChatPresenceService.instance.markOffline();
    await ChatSocketService.instance.disconnect();
    await _revokeSession();
    PostInteractionStore.ensure().clear();
    await LocalStorage.removeAccessKey();
    await LocalStorage.removeUsername();
    await LocalStorage.removeUserId();
    await LocalStorage.removeAvatarUrl();
    Get.offAllNamed(AppRoutes.login);
  }

  Future<void> _revokeSession() async {
    try {
      // interceptAuthFailure: false — a 401 here just means the token was
      // already invalid server-side, which is a success case for logout,
      // not the app-wide "session expired" flow (which would show an error
      // toast). Any other failure shouldn't block logging out locally either
      // — this call is best-effort revocation, not a precondition for it.
      await ApiHelper.postRequestWithAuthorization(
        'auth/logout',
        interceptAuthFailure: false,
      );
    } catch (e) {
      log('Unable to revoke session on logout: $e');
    }
  }
}
