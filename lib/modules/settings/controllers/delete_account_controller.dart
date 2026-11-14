import 'package:get/get.dart';
import 'package:stylebite/app/routes/app_routes.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_helper.dart';
import 'package:stylebite/core/utils/config.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/modules/messages/services/chat_presence_service.dart';
import 'package:stylebite/modules/messages/services/chat_socket_service.dart';
import 'package:stylebite/modules/post/services/post_interaction_store.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the StyleBite Account Center web page where account deletion
/// is completed (App Store 5.1.1(v) allows finishing deletion on a website
/// when the app links directly to that page).
class DeleteAccountController extends GetxController {
  final isLoading = false.obs;

  static Uri deleteAccountWebUri({String? email, String? username}) {
    final base = remoteBaseUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base/delete-account.html').replace(
      queryParameters: <String, String>{
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim().replaceFirst(RegExp(r'^@'), ''),
      },
    );
  }

  Future<void> openDeleteAccountWebsite() async {
    if (isLoading.value) return;
    isLoading.value = true;
    try {
      final username = LocalStorage.getUsername();
      final uri = deleteAccountWebUri(username: username);
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        errorSnackBar(message: 'Could not open the account deletion page.');
        return;
      }
      // After sending the user to the website, clear the local session so a
      // deleted account cannot keep using a stale token on this device.
      await _signOutLocally();
    } catch (_) {
      errorSnackBar(message: 'Could not open the account deletion page.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _signOutLocally() async {
    try {
      await ChatPresenceService.instance.markOffline();
    } catch (_) {}
    try {
      await ChatSocketService.instance.disconnect();
    } catch (_) {}
    try {
      await ApiHelper.postRequestWithAuthorization(
        'auth/logout',
        interceptAuthFailure: false,
      );
    } catch (_) {}
    PostInteractionStore.ensure().clear();
    await LocalStorage.removeAccessKey();
    await LocalStorage.removeUsername();
    await LocalStorage.removeUserId();
    await LocalStorage.removeAvatarUrl();
    Get.offAllNamed(AppRoutes.login);
  }
}
