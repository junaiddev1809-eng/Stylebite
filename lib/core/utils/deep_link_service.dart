import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../modules/home/models/home_post_model.dart';
import '../../modules/post/screens/post_detail_screen.dart';
import '../../modules/profile/utils/profile_open_helper.dart';
import '../../modules/reel/utils/reel_open_helper.dart';
import 'api_helper.dart';
import 'local_storage.dart';

class DeepLinkService {
  DeepLinkService._();

  static final _appLinks = AppLinks();
  static StreamSubscription<Uri>? _linkSubscription;
  static String? _pendingPostId;

  static Future<void> init() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        log('Deep Link (Initial): $initialUri');
        Future.delayed(const Duration(milliseconds: 700), () {
          _handleUri(initialUri);
        });
      }
    } catch (e) {
      log('Deep Link Initial Link Error: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      log('Deep Link (Stream): $uri');
      _handleUri(uri);
    }, onError: (err) {
      log('Deep Link Stream Error: $err');
    });
  }

  static void dispose() {
    _linkSubscription?.cancel();
  }

  static Future<void> flushPending() async {
    final postId = _pendingPostId;
    if (postId == null || postId.isEmpty) {
      return;
    }
    _pendingPostId = null;
    await _openSharedPost(postId);
  }

  static void _handleUri(Uri uri) {
    final username = _profileUsername(uri);
    if (username != null) {
      _navigateToProfile(username);
      return;
    }

    final postId = _postId(uri);
    if (postId != null) {
      unawaited(_openSharedPost(postId));
    }
  }

  static String? _profileUsername(Uri uri) {
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    final index = segments.indexOf('profile');
    if (index >= 0 && index + 1 < segments.length) {
      final username = segments[index + 1].trim().replaceFirst(RegExp(r'^@+'), '');
      if (username.isNotEmpty) {
        return username;
      }
    }

    if (uri.scheme == 'stylebite' && uri.host == 'profile' && segments.isNotEmpty) {
      final username = segments.first.trim().replaceFirst(RegExp(r'^@+'), '');
      if (username.isNotEmpty) {
        return username;
      }
    }

    if (uri.scheme == 'stylebite' &&
        uri.host.isNotEmpty &&
        uri.host != 'profile' &&
        uri.host != 'p' &&
        uri.host != 'post' &&
        uri.host != 'reel') {
      return uri.host.replaceFirst(RegExp(r'^@+'), '');
    }

    return null;
  }

  static String? _postId(Uri uri) {
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    const keys = ['p', 'post', 'reel'];
    for (final key in keys) {
      final index = segments.indexOf(key);
      if (index >= 0 && index + 1 < segments.length) {
        final id = segments[index + 1].trim();
        if (RegExp(r'^\d+$').hasMatch(id)) {
          return id;
        }
      }
    }

    if (uri.scheme == 'stylebite' && keys.contains(uri.host) && segments.isNotEmpty) {
      final id = segments.first.trim();
      if (RegExp(r'^\d+$').hasMatch(id)) {
        return id;
      }
    }

    return null;
  }

  static Future<void> _openSharedPost(String postId) async {
    final accessKey = LocalStorage.getAccessKey();
    if (accessKey == null || accessKey.isEmpty) {
      _pendingPostId = postId;
      return;
    }

    await _whenReady();
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'feed/posts/$postId?comments_page=1',
      );
      if (response == null || response.statusCode != 200) {
        return;
      }
      final payload = jsonDecode(response.body);
      if (payload is! Map || payload['status_code'] != 1) {
        return;
      }
      final json = payload['post'];
      if (json is! Map) {
        return;
      }
      final data = Map<String, dynamic>.from(json);
      final post = HomePostModel.fromJson(
        data,
        responseType: (data['post_type'] ?? '').toString(),
      );
      if (post.id.trim().isEmpty) {
        return;
      }
      if (ReelOpenHelper.isReel(post)) {
        ReelOpenHelper.openFromPost(post);
      } else {
        Get.to<void>(() => PostDetailScreen(post: post));
      }
    } catch (error) {
      log('Deep Link post open failed: $error');
    }
  }

  static Future<void> _whenReady() async {
    for (var attempt = 0; attempt < 25; attempt++) {
      final route = Get.currentRoute;
      if (route == AppRoutes.landing ||
          (route.isNotEmpty &&
              route != AppRoutes.splash &&
              route != AppRoutes.login &&
              route != AppRoutes.intro &&
              route != AppRoutes.otp &&
              route != AppRoutes.signUp)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  static void _navigateToProfile(String username) {
    log('Deep Link: Navigating to profile @$username');
    ProfileOpenHelper.open(username: username);
  }
}
