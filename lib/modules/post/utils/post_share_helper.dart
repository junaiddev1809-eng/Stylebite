import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/app_helper.dart';
import '../../home/models/home_post_model.dart';

class PostShareHelper {
  const PostShareHelper._();

  static const String shareHost = 'https://stylebiteapp.com';

  static String postLink(String id) {
    final postId = id.trim();
    return '$shareHost/p/$postId';
  }

  static String buildShareText(HomePostModel post) {
    final username = post.profileUsername.trim().isNotEmpty
        ? post.profileUsername.trim()
        : post.username.trim();
    return buildShareTextFromParts(
      caption: post.caption,
      link: postLink(post.id),
      username: username,
    );
  }

  static String buildShareTextFromParts({
    required String caption,
    required String link,
    String username = '',
  }) {
    final handle = username.trim().replaceFirst(RegExp(r'^@+'), '');
    final parts = <String>[
      if (caption.trim().isNotEmpty) caption.trim(),
      if (handle.isNotEmpty) '@$handle on StyleBite',
      if (link.trim().isNotEmpty) link.trim(),
    ];

    return parts.join('\n\n');
  }

  static Future<bool> sharePost(HomePostModel post) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: buildShareText(post),
        subject: 'Check out this post',
      ),
    );

    return result.status == ShareResultStatus.success;
  }

  static Future<bool> shareText({
    required String caption,
    required String link,
    String username = '',
    String subject = 'Check out this post',
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        text: buildShareTextFromParts(
          caption: caption,
          link: link,
          username: username,
        ),
        subject: subject,
      ),
    );

    return result.status == ShareResultStatus.success;
  }

  static Future<bool> copyPostText(
    BuildContext context,
    HomePostModel post,
  ) async {
    final username = post.profileUsername.trim().isNotEmpty
        ? post.profileUsername.trim()
        : post.username.trim();
    return copyShareText(
      context,
      caption: post.caption,
      link: postLink(post.id),
      username: username,
    );
  }

  static Future<bool> copyShareText(
    BuildContext context, {
    required String caption,
    required String link,
    String username = '',
  }) async {
    await Clipboard.setData(
      ClipboardData(
        text: buildShareTextFromParts(
          caption: caption,
          link: link,
          username: username,
        ),
      ),
    );

    if (!context.mounted) {
      return true;
    }

    successSnackBar(message: 'Post link copied');

    return true;
  }
}
