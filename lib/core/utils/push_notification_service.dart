import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get/get.dart';

import '../../firebase_options.dart';
import '../../modules/messages/services/chat_event_bus.dart';
import '../../modules/notifications/controllers/notifications_controller.dart';
import '../../modules/notifications/models/notification_item_model.dart';
import '../../modules/notifications/utils/like_notification_store.dart';
import '../../modules/notifications/utils/notification_navigator.dart';
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
    // Shared router: every notification type opens its specific destination
    // (chat, post, profile, story, contest, earnings, etc.).
    unawaited(NotificationNavigator.openPayload(payload));
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
      } else if (username.isNotEmpty ||
          type == 'message' ||
          type.contains('chat') ||
          _firstText(data['entity_type']) == 'message') {
        if (title.isEmpty) {
          title = username.isNotEmpty
              ? '$username sent you a message'
              : 'New message';
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
    final direct = _readInt(
      payload['conversation_id'] ??
          payload['chat_id'] ??
          payload['conversationId'],
    );
    if (direct > 0) {
      return direct;
    }

    final type = _firstText(payload['type'], payload['notification_type']);
    final entityType = _firstText(payload['entity_type']);
    final isMessage = type == 'message' ||
        type.contains('chat') ||
        entityType == 'message' ||
        entityType == 'chat' ||
        entityType == 'conversation';
    if (isMessage) {
      final fromEntity = _readInt(payload['entity_id']);
      if (fromEntity > 0) {
        return fromEntity;
      }
    }

    final actionUrl = _firstText(
      payload['action_url'],
      payload['click_action'],
    );
    final fromQuery = _queryIntFromActionUrl(actionUrl, 'conversation_id');
    if (fromQuery > 0) {
      return fromQuery;
    }

    return _resourceIdFromActionUrl(actionUrl, const ['chat', 'chats', 'conversation']);
  }

  static int _queryIntFromActionUrl(String actionUrl, String key) {
    final uri = Uri.tryParse(actionUrl.trim());
    if (uri == null) {
      return 0;
    }
    return _readInt(uri.queryParameters[key]);
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
    final resource = segments[0].toLowerCase();
    if (!resources.contains(resource)) {
      return 0;
    }
    return int.tryParse(segments[1]) ?? 0;
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
