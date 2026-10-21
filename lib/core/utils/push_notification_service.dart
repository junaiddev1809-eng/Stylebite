import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../firebase_options.dart';
import '../../modules/messages/screen/messages_screen.dart';
import '../../modules/messages/services/chat_event_bus.dart';
import '../../modules/notifications/controllers/notifications_controller.dart';
import '../../modules/notifications/models/notification_item_model.dart';
import '../../modules/notifications/screen/notifications_screen.dart';
import '../../modules/notifications/utils/like_notification_store.dart';
import '../../modules/post/utils/post_detail_open_helper.dart';
import 'app_device_service.dart';
import 'local_notification_service.dart';
import 'local_storage.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {
    // Firebase may be unavailable until native config files are added.
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _hasRegisteredNavigationHandlers = false;

  static Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await _messaging.setAutoInitEnabled(true);

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );
      await LocalNotificationService.instance.init(onTap: _openChatFromPayload);

      final token = await _resolveFcmToken();
      if (token != null && token.isNotEmpty) {
        LocalStorage.setPushToken(pushToken: token);
      }

      _messaging.onTokenRefresh.listen((token) {
        if (token.isNotEmpty) {
          LocalStorage.setPushToken(pushToken: token);
          AppDeviceService.syncPushToken(pushToken: token);
        }
      });

      FirebaseMessaging.onMessage.listen((message) {
        log(
          'Foreground push received: ${message.messageId} :: '
          'notification.title=${message.notification?.title} :: '
          'notification.body=${message.notification?.body} :: '
          'data=${message.data}',
        );
        _publishRefreshEvent(_mergedPushPayload(message));
        _showForegroundNotification(message);
      });
      registerNavigationHandlers();
    } catch (e, stackTrace) {
      log('Push notification init skipped: $e', stackTrace: stackTrace);
    }
  }

  static Future<void> requestPermission() async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      log('Error requesting notification permission: $e');
    }
  }

  static Future<String> getPushToken() async {
    final savedToken = LocalStorage.getPushToken();
    if (savedToken != null && savedToken.isNotEmpty) {
      return savedToken;
    }

    try {
      final token = await _resolveFcmToken();
      if (token != null && token.isNotEmpty) {
        LocalStorage.setPushToken(pushToken: token);
        return token;
      }
    } catch (e, stackTrace) {
      log('Unable to fetch push token: $e', stackTrace: stackTrace);
    }

    return '';
  }

  static Future<String?> _resolveFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        return token;
      }

      // getToken() can return null right after a fresh permission grant,
      // before APNs has finished handing the app its device token — one
      // retry after a short delay covers that without needing to poll
      // getAPNSToken() (which only reads an already-cached value and
      // doesn't itself trigger or wait for registration).
      await Future<void>.delayed(const Duration(seconds: 2));
      return await _messaging.getToken();
    } catch (e, stackTrace) {
      log('getToken() failed: $e', stackTrace: stackTrace);
      return null;
    }
  }

  static void registerNavigationHandlers() {
    if (_hasRegisteredNavigationHandlers || Firebase.apps.isEmpty) {
      return;
    }
    _hasRegisteredNavigationHandlers = true;

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _publishRefreshEvent(_mergedPushPayload(message));
      _openChatFromPayload(_mergedPushPayload(message));
    });

    _messaging.getInitialMessage().then((message) {
      if (message == null) {
        return;
      }

      Future<void>.delayed(const Duration(milliseconds: 500), () {
        _publishRefreshEvent(_mergedPushPayload(message));
        _openChatFromPayload(_mergedPushPayload(message));
      });
    });
  }

  static void _openChatFromPayload(Map<String, dynamic> payload) {
    final type = _firstText(payload['type']);
    final entityType = _firstText(payload['entity_type']);
    final entityId = _readInt(payload['entity_id']);
    final actionUrl = _firstText(
      payload['action_url'],
      payload['click_action'],
    );
    if ((type == 'contest' || entityType == 'contest') && entityId > 0) {
      Get.toNamed(AppRoutes.contestDetail, arguments: {'contestId': entityId});
      return;
    }
    if ((type == 'support' || entityType == 'support_ticket') && entityId > 0) {
      Get.toNamed(
        AppRoutes.supportTicketDetail,
        arguments: {'ticketId': entityId},
      );
      return;
    }
    if (NotificationItemModel.isLikeType(type) ||
        NotificationItemModel.isLikeType(entityType) ||
        type == 'comment' ||
        type.contains('comment') ||
        entityType == 'post') {
      // For a comment notification, entity_id/entity_type describe the
      // COMMENT, not the post — action_url ("/posts/{id}") is the only
      // reliable source of the post id here. entity_id is only trustworthy
      // as a post id when entity_type actually says "post".
      if (_openFromActionUrlPath(actionUrl)) {
        return;
      }
      if (entityType == 'post' && entityId > 0) {
        PostDetailOpenHelper.openById(entityId.toString());
        return;
      }
      Get.to<void>(() => const NotificationsScreen());
      return;
    }

    final isMessage = type == 'message' ||
        type.contains('chat') ||
        entityType == 'message' ||
        entityType == 'chat';
    final username = _resolveUsername(payload);
    final conversationId = _resolveConversationId(payload);
    if (isMessage && username.isNotEmpty) {
      Get.to<void>(
        () => MessagesScreen(
          initialUsername: username,
          initialConversationId: conversationId > 0 ? conversationId : null,
        ),
      );
      return;
    }

    // Anything else this client doesn't special-case still usually carries
    // action_url pointing exactly where to go — worth trying before giving
    // up on a deep link.
    if (_openFromActionUrlPath(actionUrl)) {
      return;
    }

    // Anything else (system notices like "streak ends tonight", or any
    // future type this client doesn't special-case) still deserves to go
    // somewhere on tap rather than silently doing nothing — the
    // notifications list is the correct catch-all destination.
    Get.to<void>(() => const NotificationsScreen());
  }

  static bool _openFromActionUrlPath(String actionUrl) {
    final uri = Uri.tryParse(actionUrl.trim());
    final segments =
        uri?.pathSegments.where((segment) => segment.isNotEmpty).toList() ??
        const <String>[];
    if (segments.length < 2) {
      return false;
    }

    final resource = segments[0].toLowerCase();
    final identifier = segments[1];

    switch (resource) {
      case 'posts':
      case 'post':
        PostDetailOpenHelper.openById(identifier);
        return true;
      case 'contests':
      case 'contest':
        final contestId = int.tryParse(identifier);
        if (contestId != null && contestId > 0) {
          Get.toNamed(
            AppRoutes.contestDetail,
            arguments: {'contestId': contestId},
          );
          return true;
        }
        return false;
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
      default:
        return false;
    }
  }

  static Map<String, dynamic> _mergedPushPayload(RemoteMessage message) {
    return <String, dynamic>{
      ...message.data,
      if ((message.notification?.title ?? '').trim().isNotEmpty)
        'title': message.data['title'] ?? message.notification!.title,
      if ((message.notification?.body ?? '').trim().isNotEmpty)
        'body': message.data['body'] ?? message.notification!.body,
    };
  }

  static void _publishRefreshEvent(Map<String, dynamic> payload) {
    var type = _firstText(
      payload['type'],
      payload['notification_type'],
      payload['entity_type'],
    );
    if (type.isEmpty) {
      type = _firstText(payload['event'], payload['action']);
    }
    final blob =
        '${payload['title'] ?? ''} ${payload['body'] ?? ''} ${payload['message'] ?? ''} ${payload['text'] ?? ''}'
            .toLowerCase();
    if (type.isEmpty &&
        (blob.contains('liked') ||
            blob.contains('like your') ||
            blob.contains('likes your') ||
            blob.contains('loved your'))) {
      type = 'like';
    }
    if (type.isEmpty &&
        (blob.contains('comment') || blob.contains('replied'))) {
      type = 'comment';
    }
    if (type.isEmpty) {
      return;
    }

    if (NotificationItemModel.isLikeType(type) ||
        NotificationItemModel.isLikeType(
          _firstText(payload['entity_type']),
        ) ||
        blob.contains('liked') ||
        blob.contains('like your')) {
      if (!Get.isRegistered<NotificationsController>()) {
        Get.put(NotificationsController(), permanent: true);
      }
      try {
        LikeNotificationStore.upsert(
          NotificationItemModel.fromJson(<String, dynamic>{
            ...payload,
            'type': type,
          }),
        );
      } catch (_) {}
    }
    ChatEventBus.instance.publish(ChatPushEvent(type: type, payload: payload));
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final data = message.data;
    var title = message.notification?.title ?? '';
    var body = message.notification?.body ?? '';

    // Data-only messages (no `notification` block) need a title/body built
    // defensively from whatever fields the payload actually has.
    if (title.isEmpty || body.isEmpty) {
      final username = _resolveUsername(data);
      final type = _firstText(
        data['type'],
        data['notification_type'],
        data['entity_type'],
      );
      if (NotificationItemModel.isLikeType(type) ||
          '$title $body'.toLowerCase().contains('liked')) {
        if (title.isEmpty) {
          title = username.isNotEmpty ? username : 'StyleBite';
        }
        if (body.isEmpty) {
          body = 'liked your post';
        }
      } else if (username.isNotEmpty) {
        if (title.isEmpty) {
          title = 'New message from @$username';
        }
        if (body.isEmpty) {
          final resolvedBody = _firstText(
            data['body'],
            data['message'],
            data['preview'],
          );
          body = resolvedBody.isEmpty ? 'Sent you a message' : resolvedBody;
        }
      }
    }

    if (title.isEmpty && body.isEmpty) {
      log(
        'PushNotificationService: skipping foreground notification — no '
        'title/body could be resolved from notification block or data '
        'payload $data.',
      );
      return;
    }

    final conversationId = _resolveConversationId(data);
    final notificationId = conversationId > 0
        ? conversationId
        : (message.messageId ?? DateTime.now().toIso8601String()).hashCode;

    log(
      'PushNotificationService: showing foreground notification id='
      '$notificationId title="$title" body="$body"',
    );
    LocalNotificationService.instance.show(
      id: notificationId,
      title: title.isEmpty ? 'StyleBite' : title,
      body: body,
      payload: jsonEncode(data),
      // iOS has no "dot without a number" badge style — 1 is the closest
      // equivalent, a plain "something's new" indicator rather than an
      // exact unread count.
      badgeNumber: 1,
    );
  }

  static String _resolveUsername(Map<String, dynamic> payload) {
    final direct = _firstText(
      payload['username'],
      payload['sender_username'],
      payload['chat_username'],
    );
    if (direct.isNotEmpty) {
      return direct.replaceFirst('@', '');
    }

    final actionUrl = _firstText(
      payload['action_url'],
      payload['click_action'],
    );
    if (actionUrl.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(actionUrl);
    if (uri != null) {
      final queryUsername = _firstText(
        uri.queryParameters['username'],
        uri.queryParameters['chat_username'],
      );
      if (queryUsername.isNotEmpty) {
        return queryUsername.replaceFirst('@', '');
      }

      final segments = uri.pathSegments;
      final chatsIndex = segments.indexOf('chats');
      if (chatsIndex >= 0 && chatsIndex + 1 < segments.length) {
        return segments[chatsIndex + 1].replaceFirst('@', '');
      }
    }

    return '';
  }

  static int _resolveConversationId(Map<String, dynamic> payload) {
    return _readInt(
      payload['conversation_id'] ??
          payload['chat_id'] ??
          payload['conversationId'],
    );
  }

  static String _firstText(dynamic first, [dynamic second, dynamic third]) {
    final values = <dynamic>[first, second, third];
    for (final value in values) {
      final resolved = value?.toString().trim();
      if (resolved != null && resolved.isNotEmpty && resolved != 'null') {
        return resolved;
      }
    }
    return '';
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }
}
