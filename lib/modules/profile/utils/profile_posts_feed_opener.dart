import 'package:get/get.dart';

import '../../../core/utils/app_helper.dart';
import '../../home/models/home_post_model.dart';
import '../../post/utils/post_detail_open_helper.dart';
import '../../reel/utils/reel_open_helper.dart';
import '../models/profile_model.dart';
import '../screen/profile_posts_feed_screen.dart';

class ProfilePostsFeedOpener {
  const ProfilePostsFeedOpener._();

  static Future<void> open({
    required ProfilePostModel selected,
    required List<ProfilePostModel> tabPosts,
    required ProfileUserModel user,
    required ProfileContentTab tab,
    required bool isOwnProfile,
    required int currentPage,
    required bool hasMore,
  }) async {
    if (selected.id >= 0) {
      final accessible = await PostDetailOpenHelper.isAccessible(
        selected.id.toString(),
      );
      if (!accessible) {
        errorSnackBar(message: 'Post not found or not accessible.');
        return;
      }
    }

    final authorName = user.displayName.trim().isNotEmpty
        ? user.displayName
        : (user.fullName.trim().isNotEmpty ? user.fullName : user.username);

    HomePostModel toHome(ProfilePostModel post) {
      return post.toHomePostModel(
        username: user.username,
        avatarUrl: user.avatarUrl,
        profileUsername: user.username,
        authorName: authorName,
      );
    }

    final ordered = <ProfilePostModel>[];
    final seen = <int>{};
    void addPost(ProfilePostModel post) {
      if (seen.add(post.id)) {
        ordered.add(post);
      }
    }

    for (final post in tabPosts) {
      addPost(post);
    }
    if (!seen.contains(selected.id)) {
      ordered.insert(0, selected);
    }

    final initialPosts = ordered.map(toHome).toList(growable: false);
    if (initialPosts.isEmpty) {
      errorSnackBar(message: 'Post not found or not accessible.');
      return;
    }

    final selectedHome = toHome(selected);
    if (ReelOpenHelper.isReel(selectedHome)) {
      ReelOpenHelper.openFromProfile(
        selected: selectedHome,
        authorPosts: initialPosts,
        username: user.username,
        tab: tab,
        isOwnProfile: isOwnProfile,
        authorName: authorName,
        avatarUrl: user.avatarUrl,
        currentPage: currentPage,
        hasMore: hasMore,
      );
      return;
    }

    Get.to<void>(
      () => ProfilePostsFeedScreen(
        username: user.username,
        tab: tab,
        isOwnProfile: isOwnProfile,
        authorName: authorName,
        avatarUrl: user.avatarUrl,
        initialPosts: initialPosts,
        selectedPostId: selected.id.toString(),
        initialPage: currentPage,
        initialHasMore: hasMore,
      ),
    );
  }
}
