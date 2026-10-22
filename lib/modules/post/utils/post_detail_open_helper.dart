import 'dart:convert';

import 'package:get/get.dart';

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_helper.dart';
import '../../home/models/home_post_model.dart';
import '../../reel/utils/reel_open_helper.dart';
import '../models/post_detail_model.dart';
import '../screens/post_detail_screen.dart';

class PostDetailOpenHelper {
  const PostDetailOpenHelper._();

  static bool isPendingId(String postId) {
    final id = postId.trim();
    return id.startsWith('local-') || id.startsWith('-');
  }

  static Future<bool> openIfAccessible(HomePostModel post) async {
    if (!isPendingId(post.id)) {
      final accessible = await isAccessible(post.id);
      if (!accessible) {
        errorSnackBar(message: 'Post not found or not accessible.');
        return false;
      }
    }

    if (ReelOpenHelper.isReel(post)) {
      ReelOpenHelper.openFromPost(post);
      return true;
    }

    Get.to<void>(() => PostDetailScreen(post: post));
    return true;
  }

  /// Used when only a post id is known — e.g. deep-linking from a like /
  /// comment notification, which has no cached [HomePostModel] to hand to
  /// [PostDetailScreen] up front.
  static Future<bool> openById(String postId) async {
    if (postId.trim().isEmpty) {
      errorSnackBar(message: 'Post not found or not accessible.');
      return false;
    }

    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'feed/posts/$postId?comments_page=1',
      );
      final payload = response == null
          ? null
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload?['status_code'] != 1) {
        errorSnackBar(message: 'Post not found or not accessible.');
        return false;
      }

      final detail = PostDetailResponse.fromJson(payload!);
      if (ReelOpenHelper.isReel(detail.post)) {
        ReelOpenHelper.openFromPost(detail.post);
        return true;
      }
      Get.to<void>(() => PostDetailScreen(post: detail.post));
      return true;
    } catch (_) {
      errorSnackBar(message: 'Post not found or not accessible.');
      return false;
    }
  }

  static Future<HomePostModel?> fetchPost(String postId) async {
    if (postId.trim().isEmpty) {
      return null;
    }

    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'feed/posts/$postId?comments_page=1',
      );
      final payload = response == null
          ? null
          : jsonDecode(response.body) as Map<String, dynamic>;
      if (response == null ||
          response.statusCode < 200 ||
          response.statusCode >= 300 ||
          payload?['status_code'] != 1) {
        return null;
      }

      return PostDetailResponse.fromJson(payload!).post;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isAccessible(String postId) async {
    if (postId.trim().isEmpty) {
      return false;
    }

    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'feed/posts/$postId?comments_page=1',
      );
      if (response == null) {
        return false;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return response.statusCode >= 200 &&
          response.statusCode < 300 &&
          payload['status_code'] == 1;
    } catch (_) {
      return false;
    }
  }
}
