import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows a system-style notification while the app is in the foreground.
///
/// FCM already delivers notifications to the system tray on its own when the
/// app is backgrounded or killed (as long as the backend sends a
/// `notification` payload block), and tapping those already navigates
/// correctly via PushNotificationService's existing handlers. The one gap
/// this fills is that neither Android nor iOS shows anything automatically
/// while the app is actually open — this service is only ever invoked from
/// PushNotificationService's foreground `onMessage` listener.
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  static const String _channelId = 'messages_channel';
  static const String _channelName = 'Messages';
  static const String _channelDescription =
      'New messages and activity notifications';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  void Function(Map<String, dynamic> payload)? _onTap;
  bool _isInitialized = false;

  Future<void> init({
    required void Function(Map<String, dynamic> payload) onTap,
  }) async {
    if (_isInitialized) {
      return;
    }
    _onTap = onTap;

    try {
      // Android only ever draws the alpha channel of a notification icon —
      // a full-color launcher icon renders as a solid white blob. This must
      // be a dedicated white-on-transparent silhouette (see
      // android/app/src/main/res/drawable-*/ic_stat_notify.png).
      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_stat_notify',
      );
      // Permission is requested separately via
      // PushNotificationService.requestPermission (FCM covers both).
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: iosSettings,
        ),
        onDidReceiveNotificationResponse: _handleTap,
      );

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
      // Android 13+ requires this at runtime even though FCM's own
      // requestPermission() usually covers it — asking again here is a
      // harmless no-op if already granted, and closes a gap if this
      // service ever initializes before that FCM call happens.
      final granted = await androidPlugin?.requestNotificationsPermission();
      log(
        'LocalNotificationService: Android notification permission granted=$granted',
      );

      _isInitialized = true;
      log('LocalNotificationService: initialized successfully.');
    } catch (e, stackTrace) {
      log('LocalNotificationService init failed: $e', stackTrace: stackTrace);
    }
  }

  void _handleTap(NotificationResponse response) {
    final raw = response.payload;
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _onTap?.call(decoded);
      }
    } catch (e) {
      log('LocalNotificationService: failed to decode tap payload: $e');
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? payload,
    int? badgeNumber,
  }) async {
    if (!_isInitialized) {
      log(
        'LocalNotificationService: show() called before init succeeded — skipping.',
      );
      return;
    }
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            color: Color(0xFFE64C73),
            // Some OEM skins (MIUI, ColorOS, One UI) fall back to the
            // launcher icon for the notification's large icon slot when
            // none is set, which shows up looking like "a different logo".
            // Pinning it here keeps it consistent everywhere.
            largeIcon: DrawableResourceAndroidBitmap('ic_notification_large'),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: badgeNumber,
          ),
        ),
        payload: payload,
      );
      log('LocalNotificationService: show() succeeded for id=$id.');
    } catch (e) {
      log('LocalNotificationService: show failed: $e');
    }
  }
}
