import 'package:get/get.dart';

import '../../../core/utils/local_storage.dart';
import '../../landing/controllers/landing_controller.dart';
import '../../landing/screen/landing_screen.dart';
import '../screen/user_profile_cover_screen.dart';

class ProfileOpenHelper {
  static String normalizeUsername(String username) {
    return username.trim().replaceFirst(RegExp(r'^@'), '');
  }

  static bool isSelf(String username) {
    final current = normalizeUsername(
      LocalStorage.getUsername() ?? '',
    ).toLowerCase();
    final target = normalizeUsername(username).toLowerCase();
    return current.isNotEmpty && target.isNotEmpty && current == target;
  }

  static Future<void> open({
    required String username,
    bool initialIsFollowing = false,
    String? coverUrl,
    String? avatarUrl,
    bool replaceCurrent = false,
  }) {
    final cleaned = normalizeUsername(username);
    if (cleaned.isEmpty) {
      return Future<void>.value();
    }

    if (isSelf(cleaned)) {
      if (Get.isRegistered<LandingController>()) {
        Get.find<LandingController>().onTabChanged(4);
      }
      final canPop = Get.key.currentState?.canPop() ?? false;
      if (canPop) {
        Get.offAll<void>(() => const LandingScreen(initialIndex: 4));
      }
      return Future<void>.value();
    }

    final page = UserProfileCoverScreen(
      username: cleaned,
      initialIsFollowing: initialIsFollowing,
      initialCoverUrl: coverUrl ?? '',
      initialAvatarUrl: avatarUrl ?? '',
    );

    if (replaceCurrent) {
      Get.off<void>(() => page);
      return Future<void>.value();
    }

    Get.to<void>(() => page, preventDuplicates: false);
    return Future<void>.value();
  }
}
