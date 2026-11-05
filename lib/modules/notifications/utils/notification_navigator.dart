import 'dart:async';

import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/utils/app_helper.dart';
import '../../landing/screen/landing_screen.dart';
import '../../messages/screen/messages_screen.dart';
import '../../post/utils/post_detail_open_helper.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../../story/controllers/story_controller.dart';
import '../models/notification_item_model.dart';

/// Single deep-link router for notification taps (in-app list + push).
///
/// Mirrors major social apps: tap opens the related content screen, not a
/// generic inbox dump — message → that chat, like/comment → that post,
/// follow → that profile, story reply → that story, contest → contest, etc.
class NotificationNavigator {
  NotificationNavigator._();

  static Future<void> openItem(NotificationItemModel item) async {
    switch (item.kind) {
      case NotificationKind.message:
        _openChat(
          username: item.profileHandle.isNotEmpty
              ? item.profileHandle
              : item.actorUsername,
          conversationId: item.entityType.toLowerCase() == 'message' ||
                  item.entityType.toLowerCase() == 'conversation' ||
                  item.entityType.toLowerCase() == 'chat'
              ? item.entityId
              : 0,
          actionUrl: item.actionUrl,
        );
        return;
      case NotificationKind.storyReply:
        await _openStoryReply(item);
        return;
      case NotificationKind.like:
      case NotificationKind.comment:
        if (_openActionUrl(item.actionUrl)) {
          return;
        }
        if (item.entityId > 0 &&
            (item.kind == NotificationKind.like ||
                item.entityType.toLowerCase() == 'post' ||
                item.entityType.toLowerCase() == 'reel')) {
          PostDetailOpenHelper.openById(item.entityId.toString());
          return;
        }
        _openHomeFeed();
        return;
      case NotificationKind.follow:
      case NotificationKind.followRequest:
        if (_openActionUrl(item.actionUrl)) {
          return;
        }
        _openProfile(item.profileHandle);
        return;
      case NotificationKind.contest:
        _openContest(item);
        return;
      case NotificationKind.support:
        if (item.entityType == 'support_ticket' && item.entityId > 0) {
          Get.toNamed(
            AppRoutes.supportTicketDetail,
            arguments: {'ticketId': item.entityId},
          );
          return;
        }
        if (_openActionUrl(item.actionUrl)) {
          return;
        }
        Get.toNamed(AppRoutes.supportTickets);
        return;
      case NotificationKind.vibeRequest:
        if (_openActionUrl(item.actionUrl)) {
          return;
        }
        _openProfile(item.profileHandle);
        return;
      case NotificationKind.other:
        if (_openActionUrl(item.actionUrl)) {
          return;
        }
        _openSystemFallback(item);
        return;
    }
  }

  /// Push / FCM payload entry point — same destinations as [openItem].
  static Future<void> openPayload(Map<String, dynamic> payload) async {
    final type = _text(payload['type'], payload['notification_type']);
    final entityType = _text(payload['entity_type']);
    final entityId = _int(payload['entity_id']);
    final actionUrl = _text(payload['action_url'], payload['click_action']);
    final blob =
        '${payload['title'] ?? ''} ${payload['body'] ?? ''} ${payload['message'] ?? ''} ${payload['text'] ?? ''}'
            .toLowerCase();
    final username = _resolveUsername(payload);
    final conversationId = _resolveConversationId(payload);

    // 1) Message → that user's chat box
    final isMessage = type == 'message' ||
        type.contains('chat') ||
        entityType == 'message' ||
        entityType == 'chat' ||
        entityType == 'conversation';
    if (isMessage && !blob.contains('story')) {
      _openChat(
        username: username,
        conversationId: conversationId > 0 ? conversationId : entityId,
        actionUrl: actionUrl,
      );
      return;
    }

    // 2) Story reply → owner's story
    final isStoryReply = type == 'story_reply' ||
        type.contains('story_reply') ||
        entityType == 'story' ||
        blob.contains('replied to your story') ||
        blob.contains('reacted to your story');
    if (isStoryReply) {
      final storyId = entityType == 'story' && entityId > 0
          ? entityId.toString()
          : _storyIdFromActionUrl(actionUrl);
      if (storyId.isNotEmpty) {
        final opened =
            await StoryController.ensure().openStoryByRemoteId(storyId);
        if (opened) {
          return;
        }
      }
      // Fall back to the chat that carried the reply.
      _openChat(
        username: username,
        conversationId: conversationId,
        actionUrl: actionUrl,
      );
      return;
    }

    // 3) Like → that post/reel
    final isLike = NotificationItemModel.isLikeType(type) ||
        NotificationItemModel.isLikeType(entityType) ||
        blob.contains('liked your') ||
        blob.contains('like your') ||
        blob.contains('likes your') ||
        blob.contains('loved your');
    if (isLike) {
      if (_openActionUrl(actionUrl)) {
        return;
      }
      if (entityId > 0 &&
          (entityType == 'post' || entityType == 'reel' || entityType.isEmpty)) {
        PostDetailOpenHelper.openById(entityId.toString());
        return;
      }
      _openHomeFeed();
      return;
    }

    // 4) Comment → that post
    final isComment = type == 'comment' ||
        type.contains('comment') ||
        entityType == 'comment' ||
        blob.contains('commented');
    if (isComment) {
      if (_openActionUrl(actionUrl)) {
        return;
      }
      if (entityType == 'post' && entityId > 0) {
        PostDetailOpenHelper.openById(entityId.toString());
        return;
      }
      _openHomeFeed();
      return;
    }

    // 5) Follow / follow request → that profile
    final isFollowRequest = type == 'follow_request' ||
        type.contains('follow_request') ||
        blob.contains('requested to follow') ||
        blob.contains('follow request');
    final isFollow = type == 'follow' ||
        type == 'followed' ||
        type == 'follower' ||
        blob.contains('started following') ||
        blob.contains('following you') ||
        blob.contains('accepted your follow');
    if (isFollowRequest || isFollow) {
      if (_openActionUrl(actionUrl)) {
        return;
      }
      if (username.isNotEmpty) {
        ProfileOpenHelper.open(username: username);
        return;
      }
    }

    // 6) Contest → contest detail / leaderboard
    if (type == 'contest' ||
        type.contains('contest') ||
        entityType == 'contest' ||
        entityType.contains('contest')) {
      final contestId = entityId > 0
          ? entityId
          : _resourceIdFromActionUrl(actionUrl, const ['contests', 'contest']);
      final postId = _queryInt(actionUrl, 'post_id');
      final isResults = _hasResultsQuery(actionUrl) ||
          blob.contains('see who won') ||
          blob.contains('you ate') ||
          blob.contains('you won') ||
          blob.contains('podium secured');
      if (contestId > 0 && isResults) {
        Get.toNamed(
          AppRoutes.contestRanking,
          arguments: {'contestId': contestId},
        );
        return;
      }
      if (contestId > 0) {
        Get.toNamed(
          AppRoutes.contestDetail,
          arguments: <String, dynamic>{
            'contestId': contestId,
            if (postId > 0) 'postId': postId,
          },
        );
        return;
      }
    }

    // 7) Support ticket
    if ((type == 'support' || entityType == 'support_ticket') && entityId > 0) {
      Get.toNamed(
        AppRoutes.supportTicketDetail,
        arguments: {'ticketId': entityId},
      );
      return;
    }

    // 8) System / monetization / earnings / verification via action_url
    if (_openActionUrl(actionUrl)) {
      return;
    }

    // Verification / system with no URL → own edit profile when it looks like one.
    if (type == 'system' || entityType == 'system' || entityType == 'user') {
      if (blob.contains('verification')) {
        Get.toNamed(AppRoutes.editProfile);
        return;
      }
      if (blob.contains('monetization') || blob.contains('ads earnings')) {
        Get.toNamed(AppRoutes.monetization);
        return;
      }
      if (blob.contains('money') ||
          blob.contains('withdraw') ||
          blob.contains('transferred') ||
          blob.contains('payout')) {
        Get.toNamed(AppRoutes.myEarnings);
        return;
      }
    }

    // Last resort: still try to land somewhere useful.
    if (username.isNotEmpty) {
      ProfileOpenHelper.open(username: username);
      return;
    }
    _openHomeFeed();
  }

  static void _openChat({
    required String username,
    required int conversationId,
    required String actionUrl,
  }) {
    var resolvedUsername = username.trim().replaceFirst('@', '');
    var resolvedConversationId = conversationId;

    if (resolvedUsername.isEmpty || resolvedConversationId <= 0) {
      final fromUrl = _chatFromActionUrl(actionUrl);
      if (resolvedUsername.isEmpty) {
        resolvedUsername = fromUrl.username;
      }
      if (resolvedConversationId <= 0) {
        resolvedConversationId = fromUrl.conversationId;
      }
    }

    if (resolvedUsername.isEmpty && resolvedConversationId <= 0) {
      Get.toNamed(AppRoutes.messages);
      return;
    }

    Get.to<void>(
      () => MessagesScreen(
        initialUsername:
            resolvedUsername.isNotEmpty ? resolvedUsername : null,
        initialConversationId:
            resolvedConversationId > 0 ? resolvedConversationId : null,
      ),
    );
  }

  static Future<void> _openStoryReply(NotificationItemModel item) async {
    final storyId = item.entityType.toLowerCase() == 'story' && item.entityId > 0
        ? item.entityId.toString()
        : _storyIdFromActionUrl(item.actionUrl);
    if (storyId.isEmpty) {
      _openChat(
        username: item.profileHandle,
        conversationId: 0,
        actionUrl: item.actionUrl,
      );
      return;
    }
    final opened =
        await StoryController.ensure().openStoryByRemoteId(storyId);
    if (!opened) {
      errorSnackBar(message: 'That story is no longer available.');
      // Soft fallback to the reply chat when the story expired.
      _openChat(
        username: item.profileHandle,
        conversationId: 0,
        actionUrl: item.actionUrl,
      );
    }
  }

  static void _openContest(NotificationItemModel item) {
    final contestId = item.entityId > 0
        ? item.entityId
        : _resourceIdFromActionUrl(
            item.actionUrl,
            const ['contests', 'contest'],
          );
    if (contestId <= 0) {
      _openHomeFeed(tabIndex: 3);
      return;
    }
    if (item.isContestResultsNotification) {
      Get.toNamed(
        AppRoutes.contestRanking,
        arguments: {'contestId': contestId},
      );
      return;
    }
    final postId = _queryInt(item.actionUrl, 'post_id');
    Get.toNamed(
      AppRoutes.contestDetail,
      arguments: <String, dynamic>{
        'contestId': contestId,
        if (postId > 0) 'postId': postId,
      },
    );
  }

  static void _openSystemFallback(NotificationItemModel item) {
    final blob = '${item.title} ${item.message} ${item.type}'.toLowerCase();
    if (blob.contains('verification')) {
      Get.toNamed(AppRoutes.editProfile);
      return;
    }
    if (blob.contains('monetization')) {
      Get.toNamed(AppRoutes.monetization);
      return;
    }
    if (blob.contains('money') ||
        blob.contains('withdraw') ||
        blob.contains('transferred') ||
        blob.contains('payout') ||
        blob.contains('earnings')) {
      Get.toNamed(AppRoutes.myEarnings);
      return;
    }
    if (item.profileHandle.isNotEmpty) {
      ProfileOpenHelper.open(username: item.profileHandle);
      return;
    }
    _openHomeFeed();
  }

  static void _openProfile(String username) {
    final cleaned = username.trim().replaceFirst('@', '');
    if (cleaned.isEmpty) {
      return;
    }
    ProfileOpenHelper.open(username: cleaned);
  }

  static void _openHomeFeed({int tabIndex = 0}) {
    Get.offAll<void>(() => LandingScreen(initialIndex: tabIndex));
  }

  static bool _openActionUrl(String actionUrl) {
    final uri = Uri.tryParse(actionUrl.trim());
    final segments =
        uri?.pathSegments.where((segment) => segment.isNotEmpty).toList() ??
            const <String>[];
    if (segments.isEmpty) {
      return false;
    }

    if (segments.length == 1) {
      switch (segments[0].toLowerCase()) {
        case 'my-earnings':
        case 'earnings':
          Get.toNamed(AppRoutes.myEarnings);
          return true;
        case 'monetization':
          Get.toNamed(AppRoutes.monetization);
          return true;
        case 'edit-profile':
        case 'edit_profile':
          Get.toNamed(AppRoutes.editProfile);
          return true;
        case 'messages':
        case 'chats':
          Get.toNamed(AppRoutes.messages);
          return true;
        default:
          return false;
      }
    }

    final resource = segments[0].toLowerCase();
    final identifier = segments[1];

    if (resource == 'settings' && identifier.toLowerCase() == 'monetization') {
      Get.toNamed(AppRoutes.monetization);
      return true;
    }

    switch (resource) {
      case 'my-earnings':
      case 'earnings':
        Get.toNamed(AppRoutes.myEarnings);
        return true;
      case 'monetization':
        Get.toNamed(AppRoutes.monetization);
        return true;
      case 'posts':
      case 'post':
      case 'reels':
      case 'reel':
        PostDetailOpenHelper.openById(identifier);
        return true;
      case 'stories':
      case 'story':
        unawaited(StoryController.ensure().openStoryByRemoteId(identifier));
        return true;
      case 'contests':
      case 'contest':
        final contestId = int.tryParse(identifier);
        if (contestId == null || contestId <= 0) {
          return false;
        }
        final hasResults =
            (uri?.queryParameters['results'] ?? '').trim().isNotEmpty;
        final postId =
            int.tryParse((uri?.queryParameters['post_id'] ?? '').trim()) ?? 0;
        Get.toNamed(
          hasResults ? AppRoutes.contestRanking : AppRoutes.contestDetail,
          arguments: <String, dynamic>{
            'contestId': contestId,
            if (!hasResults && postId > 0) 'postId': postId,
          },
        );
        return true;
      case 'chats':
      case 'chat':
        final chat = _chatFromActionUrl(actionUrl);
        _openChat(
          username: chat.username,
          conversationId: chat.conversationId,
          actionUrl: '',
        );
        return true;
      case 'support-tickets':
      case 'support_tickets':
        final ticketId = int.tryParse(identifier);
        if (ticketId != null && ticketId > 0) {
          Get.toNamed(
            AppRoutes.supportTicketDetail,
            arguments: {'ticketId': ticketId},
          );
          return true;
        }
        return false;
      case 'profiles':
      case 'profile':
      case 'users':
      case 'user':
      case 'u':
        ProfileOpenHelper.open(username: identifier);
        return true;
      default:
        return false;
    }
  }

  static ({String username, int conversationId}) _chatFromActionUrl(
    String actionUrl,
  ) {
    final uri = Uri.tryParse(actionUrl.trim());
    final segments =
        uri?.pathSegments.where((segment) => segment.isNotEmpty).toList() ??
            const <String>[];
    if (segments.length < 2) {
      return (
        username: '',
        conversationId: int.tryParse(
              (uri?.queryParameters['conversation_id'] ?? '').trim(),
            ) ??
            0,
      );
    }
    final identifier = segments[1];
    final conversationId = int.tryParse(identifier) ??
        int.tryParse(
          (uri?.queryParameters['conversation_id'] ?? '').trim(),
        ) ??
        0;
    final usernameFromPath =
        int.tryParse(identifier) == null ? identifier.replaceFirst('@', '') : '';
    final username = _text(
      uri?.queryParameters['username'],
      uri?.queryParameters['chat_username'],
      usernameFromPath,
    ).replaceFirst('@', '');
    return (username: username, conversationId: conversationId);
  }

  static String _storyIdFromActionUrl(String actionUrl) {
    final uri = Uri.tryParse(actionUrl.trim());
    final segments =
        uri?.pathSegments.where((segment) => segment.isNotEmpty).toList() ??
            const <String>[];
    if (segments.length >= 2 &&
        (segments[0].toLowerCase() == 'stories' ||
            segments[0].toLowerCase() == 'story')) {
      return segments[1].trim();
    }
    return (uri?.queryParameters['story_id'] ?? '').trim();
  }

  static int _resourceIdFromActionUrl(
    String actionUrl,
    List<String> resources,
  ) {
    final uri = Uri.tryParse(actionUrl.trim());
    final segments =
        uri?.pathSegments.where((segment) => segment.isNotEmpty).toList() ??
            const <String>[];
    if (segments.length < 2) {
      return 0;
    }
    if (!resources.contains(segments[0].toLowerCase())) {
      return 0;
    }
    return int.tryParse(segments[1]) ?? 0;
  }

  static int _queryInt(String actionUrl, String key) {
    final uri = Uri.tryParse(actionUrl.trim());
    return int.tryParse((uri?.queryParameters[key] ?? '').trim()) ?? 0;
  }

  static bool _hasResultsQuery(String actionUrl) {
    final uri = Uri.tryParse(actionUrl.trim());
    return (uri?.queryParameters['results'] ?? '').trim().isNotEmpty;
  }

  static String _resolveUsername(Map<String, dynamic> payload) {
    return _text(
      payload['username'],
      payload['sender_username'],
      payload['chat_username'],
      payload['actor_username'],
      (payload['actor'] is Map) ? (payload['actor'] as Map)['username'] : null,
    ).replaceFirst('@', '');
  }

  static int _resolveConversationId(Map<String, dynamic> payload) {
    final direct = _int(payload['conversation_id']);
    if (direct > 0) {
      return direct;
    }
    final entityType = _text(payload['entity_type']).toLowerCase();
    if (entityType == 'message' ||
        entityType == 'chat' ||
        entityType == 'conversation') {
      return _int(payload['entity_id']);
    }
    return _chatFromActionUrl(
      _text(payload['action_url'], payload['click_action']),
    ).conversationId;
  }

  static String _text(
    dynamic a, [
    dynamic b,
    dynamic c,
    dynamic d,
    dynamic e,
  ]) {
    for (final value in [a, b, c, d, e]) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  static int _int(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }
}
