import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'config.dart';

class LocalStorage {
  static late SharedPreferences prefs;
  static const String _accessKeyKey = 'accessKey';
  static const String _deviceIdKey = 'deviceId';
  static const String _pushTokenKey = 'pushToken';
  static const String _appVersionKey = 'appVersion';
  static const String _hasSeenIntroKey = 'hasSeenIntro';
  static const String _usernameKey = 'username';
  static const String _userIdKey = 'userId';
  static const String _avatarUrlKey = 'avatarUrl';
  static const String _savedLoginIdKey = 'savedLoginId';
  static const String _rememberLoginIdConsentKey = 'rememberLoginIdConsent';
  static const String _backendOriginKey = 'backendOrigin';

  /// Reactive view of [getAvatarUrl] for widgets that must update without
  /// starting ProfileController (for example the Home top-bar avatar).
  static final ValueNotifier<String> avatarUrlListenable = ValueNotifier<String>(
    '',
  );

  static Future<void> initStorage() async {
    prefs = await SharedPreferences.getInstance();
    await bindSessionToCurrentBackend();
    avatarUrlListenable.value = getAvatarUrl() ?? '';
  }

  /// Drop a leftover production (or other host) session when the compile-time
  /// API target changes. Otherwise restart keeps the old token and the app
  /// talks to the wrong backend / crashes on live Pusher.
  static Future<void> bindSessionToCurrentBackend() async {
    final storedOrigin = prefs.getString(_backendOriginKey);
    if (storedOrigin == baseUrl) {
      return;
    }

    await prefs.remove(_accessKeyKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_avatarUrlKey);
    avatarUrlListenable.value = '';
    await prefs.setString(_backendOriginKey, baseUrl);
  }

  static void setAccessKey({required String accessKey}) {
    prefs.setString(_accessKeyKey, _normalizeAccessKey(accessKey));
  }

  static String? getAccessKey() {
    final stored = prefs.getString(_accessKeyKey);
    if (stored == null || stored.trim().isEmpty) {
      return null;
    }
    return _normalizeAccessKey(stored);
  }

  static String _normalizeAccessKey(String accessKey) {
    var token = accessKey.trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    return token;
  }

  static Future<void> removeAccessKey() async {
    await prefs.remove(_accessKeyKey);
  }

  static void setUsername({required String username}) {
    prefs.setString(_usernameKey, _normalizeUsername(username));
  }

  static String? getUsername() {
    final stored = prefs.getString(_usernameKey);
    if (stored != null && stored.trim().isNotEmpty) {
      return _normalizeUsername(stored);
    }

    final accessKey = getAccessKey();
    if (accessKey == null || accessKey.trim().isEmpty) {
      return null;
    }

    final payload = _decodeJwtPayload(accessKey);
    final inferred = _firstNonEmptyString(
      payload['username'],
      payload['user_name'],
      payload['preferred_username'],
      payload['handle'],
      (payload['user'] is Map<String, dynamic>)
          ? (payload['user'] as Map<String, dynamic>)['username']
          : null,
    );

    if (inferred == null) {
      return null;
    }

    final normalized = _normalizeUsername(inferred);
    prefs.setString(_usernameKey, normalized);
    return normalized;
  }

  static Future<void> removeUsername() async {
    await prefs.remove(_usernameKey);
  }

  static void setUserId({required int userId}) {
    prefs.setInt(_userIdKey, userId);
  }

  static int? getUserId() {
    final stored = prefs.getInt(_userIdKey);
    if (stored != null && stored > 0) {
      return stored;
    }

    final accessKey = getAccessKey();
    if (accessKey == null || accessKey.trim().isEmpty) {
      return null;
    }

    final payload = _decodeJwtPayload(accessKey);
    final inferred = _firstNonEmptyString(
      payload['id'],
      payload['user_id'],
      payload['sub'],
      (payload['user'] is Map<String, dynamic>)
          ? (payload['user'] as Map<String, dynamic>)['id']
          : null,
    );

    final parsed = inferred == null ? null : int.tryParse(inferred);
    if (parsed == null || parsed <= 0) {
      return null;
    }

    prefs.setInt(_userIdKey, parsed);
    return parsed;
  }

  static Future<void> removeUserId() async {
    await prefs.remove(_userIdKey);
  }

  static void setAvatarUrl({required String avatarUrl}) {
    final next = avatarUrl.trim();
    prefs.setString(_avatarUrlKey, next);
    avatarUrlListenable.value = next;
  }

  static String? getAvatarUrl() {
    final stored = prefs.getString(_avatarUrlKey);
    if (stored == null || stored.trim().isEmpty) {
      return null;
    }
    return stored.trim();
  }

  static Future<void> removeAvatarUrl() async {
    await prefs.remove(_avatarUrlKey);
    avatarUrlListenable.value = '';
  }

  static void setSavedLoginId({required String loginId}) {
    prefs.setString(_savedLoginIdKey, loginId.trim());
  }

  static String? getSavedLoginId() {
    final stored = prefs.getString(_savedLoginIdKey);
    if (stored == null || stored.trim().isEmpty) {
      return null;
    }
    return stored.trim();
  }

  static Future<void> removeSavedLoginId() async {
    await prefs.remove(_savedLoginIdKey);
  }

  static void setRememberLoginIdConsent({required bool allowed}) {
    prefs.setBool(_rememberLoginIdConsentKey, allowed);
  }

  static bool? getRememberLoginIdConsent() {
    return prefs.getBool(_rememberLoginIdConsentKey);
  }

  static Future<void> removeRememberLoginIdConsent() async {
    await prefs.remove(_rememberLoginIdConsentKey);
  }

  static void setDeviceId({required String deviceId}) {
    prefs.setString(_deviceIdKey, deviceId);
  }

  static String? getDeviceId() {
    return prefs.getString(_deviceIdKey);
  }

  static void setPushToken({required String pushToken}) {
    prefs.setString(_pushTokenKey, pushToken);
  }

  static String? getPushToken() {
    return prefs.getString(_pushTokenKey);
  }

  static void setAppVersion({required String appVersion}) {
    prefs.setString(_appVersionKey, appVersion);
  }

  static String? getAppVersion() {
    return prefs.getString(_appVersionKey);
  }

  static Future<void> setHasSeenIntro({required bool hasSeenIntro}) async {
    await prefs.setBool(_hasSeenIntroKey, hasSeenIntro);
  }

  static bool hasSeenIntro() {
    return prefs.getBool(_hasSeenIntroKey) ?? false;
  }

  // Clear all stored data
  static Future<void> clearAll() async {
    await prefs.clear();
  }

  static String _normalizeUsername(String username) =>
      username.trim().replaceFirst('@', '');

  static Map<String, dynamic> _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length < 2) {
      return const <String, dynamic>{};
    }

    try {
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final parsed = jsonDecode(decoded);
      if (parsed is Map<String, dynamic>) {
        return parsed;
      }
    } catch (_) {
      return const <String, dynamic>{};
    }

    return const <String, dynamic>{};
  }

  static String? _firstNonEmptyString(
    dynamic first, [
    dynamic second,
    dynamic third,
    dynamic fourth,
    dynamic fifth,
  ]) {
    final values = [first, second, third, fourth, fifth];
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return null;
  }
}
