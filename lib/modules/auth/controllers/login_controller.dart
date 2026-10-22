import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_device_service.dart';
import 'package:stylebite/core/utils/app_helper.dart';
import 'package:stylebite/core/utils/app_location_service.dart';
import 'package:stylebite/core/utils/app_login_id_service.dart';
import 'package:stylebite/core/utils/config.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/core/utils/app_session.dart';
import 'package:stylebite/core/utils/deep_link_service.dart';

import '../../../app/routes/app_routes.dart';
import '../../post/services/post_interaction_store.dart';
import '../models/login_credentials_model.dart';

class LoginController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController(
    text: AppLoginIdService.getSavedLoginId() ?? '',
  );
  final passwordController = TextEditingController(text: "");
  final isLoading = false.obs;
  final isGoogleLoading = false.obs;
  final isAppleLoading = false.obs;

  LoginCredentialsModel? credentials;
  bool _isGoogleInitialized = false;

  Future<void> login({
    required Future<bool> Function(String loginId) rememberLoginId,
  }) async {
    try {
      if (!formKey.currentState!.validate()) {
        return;
      }

      isLoading.value = true;
      final metadata = await AppDeviceService.getLoginMetadata();
      credentials = LoginCredentialsModel(
        email: emailController.text.trim(),
        password: passwordController.text,
        deviceId: metadata.deviceId,
        platform: metadata.platform,
        pushToken: metadata.pushToken,
        appVersion: metadata.appVersion,
      );

      final response = await ApiHelper.postRequest(
        "auth/login",
        credentials!.toJson(),
      );
      if (response == null) {
        return;
      }
      await _handleAuthResponse(
        response.body,
        loginId: credentials!.email,
        rememberLoginId: rememberLoginId,
      );
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loginWithGoogle({
    required Future<bool> Function(String loginId) rememberLoginId,
  }) async {
    try {
      isGoogleLoading.value = true;
      await _ensureGoogleInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        errorSnackBar(message: 'Google sign-in is not available here.');
        return;
      }

      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const <String>['email', 'profile'],
      );
      final auth = account.authentication;
      final accessToken = await _getGoogleAccessToken(account);
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        errorSnackBar(message: 'Google did not return an ID token.');
        return;
      }

      if (accessToken == null || accessToken.isEmpty) {
        errorSnackBar(message: 'Google did not return an access token.');
        return;
      }

      final metadata = await AppDeviceService.getLoginMetadata();
      final payload = <String, dynamic>{
        'provider_user_id': account.id,
        'email': account.email,
        'name': account.displayName,
        'id_token': idToken,
        'access_token': accessToken,
        'device_id': metadata.deviceId,
        'platform': metadata.platform,
        'push_token': metadata.pushToken,
        'app_version': metadata.appVersion,
      };

      final response = await ApiHelper.postRequest(
        'auth/google-login',
        _withoutEmptyValues(payload),
      );
      if (response == null) {
        return;
      }

      await _handleAuthResponse(
        response.body,
        loginId: account.email,
        rememberLoginId: rememberLoginId,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return;
      }
      errorSnackBar(message: e.description ?? 'Google login failed.');
    } catch (e) {
      errorSnackBar(message: 'Google login failed.');
    } finally {
      isGoogleLoading.value = false;
    }
  }

  Future<void> loginWithApple({
    required Future<bool> Function(String loginId) rememberLoginId,
  }) async {
    try {
      isAppleLoading.value = true;
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        errorSnackBar(message: 'Apple sign-in is not available here.');
        return;
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final identityToken = credential.identityToken;
      if (identityToken == null || identityToken.isEmpty) {
        errorSnackBar(message: 'Apple did not return an identity token.');
        return;
      }

      final metadata = await AppDeviceService.getLoginMetadata();
      final payload = <String, dynamic>{
        'provider_user_id': credential.userIdentifier,
        'email': credential.email,
        'name': _appleDisplayName(credential),
        'identity_token': identityToken,
        'device_id': metadata.deviceId,
        'platform': metadata.platform,
        'push_token': metadata.pushToken,
        'app_version': metadata.appVersion,
      };

      final response = await ApiHelper.postRequest(
        'auth/apple-login',
        _withoutEmptyValues(payload),
      );
      if (response == null) {
        return;
      }

      await _handleAuthResponse(
        response.body,
        loginId: credential.email,
        rememberLoginId: rememberLoginId,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      errorSnackBar(message: 'Apple login failed.');
    } catch (e) {
      errorSnackBar(message: 'Apple login failed.');
    } finally {
      isAppleLoading.value = false;
    }
  }

  void goToSignUp() {
    Get.toNamed(AppRoutes.signUp);
  }

  void goToForgotPassword() {
    Get.toNamed(AppRoutes.forgotPassword);
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_isGoogleInitialized) {
      return;
    }

    await GoogleSignIn.instance.initialize(
      serverClientId: googleSignInServerClientId,
    );
    _isGoogleInitialized = true;
  }

  Future<String?> _getGoogleAccessToken(GoogleSignInAccount account) async {
    const scopes = <String>['email', 'profile'];
    final authorization = await account.authorizationClient
        .authorizationForScopes(scopes);
    if (authorization != null) {
      return authorization.accessToken;
    }

    final requestedAuthorization = await account.authorizationClient
        .authorizeScopes(scopes);
    return requestedAuthorization.accessToken;
  }

  Future<void> _handleAuthResponse(
    String responseBody, {
    String? loginId,
    required Future<bool> Function(String loginId) rememberLoginId,
  }) async {
    final responseData = jsonDecode(responseBody);
    
    if (responseData['status_code'] == 1) {
      final user = responseData['user'];
      // rememberLoginId only decides whether to save this email for
      // autofill next time — it must never gate whether the session itself
      // gets established, or answering "No" on that prompt silently
      // discards an otherwise-successful login.
      if (loginId != null && loginId.trim().isNotEmpty) {
        await rememberLoginId(loginId);
      }

      await LocalStorage.removeAvatarUrl();
      final token = AppSession.tokenFromAuthPayload(responseData);
      if (token != null) {
        LocalStorage.setAccessKey(accessKey: token);
      }
      if (user is Map<String, dynamic>) {
        final username = user['username']?.toString().trim();
        if (username != null && username.isNotEmpty) {
          LocalStorage.setUsername(username: username);
        }
        final userId = int.tryParse(user['id']?.toString() ?? '');
        if (userId != null && userId > 0) {
          LocalStorage.setUserId(userId: userId);
        }
      } else {
        LocalStorage.getUsername();
      }
      PostInteractionStore.ensure().bindCurrentUser();
      await AppSession.attachRealtimeIfNeeded();
      unawaited(AppDeviceService.syncPushToken());

      // Request location permission after successful login
      await AppLocationService.requestPermission();
      
      Get.offAllNamed(AppRoutes.landing);
      unawaited(DeepLinkService.flushPending());
    } else if (responseData['requires_verification'] == true) {
      final email = responseData['email'] ?? loginId;

      Get.toNamed(AppRoutes.otp, arguments: {
        'email': email,
        'debug_otp': responseData['debug_otp'],
      });
    } else {
      errorSnackBar(message: responseData['message']);
    }
  }

  String? _appleDisplayName(AuthorizationCredentialAppleID credential) {
    final parts = [
      credential.givenName,
      credential.familyName,
    ].where((part) => part != null && part.trim().isNotEmpty);
    final name = parts.join(' ').trim();
    return name.isEmpty ? null : name;
  }

  Map<String, dynamic> _withoutEmptyValues(Map<String, dynamic> payload) {
    return Map.fromEntries(
      payload.entries.where((entry) {
        final value = entry.value;
        if (value == null) {
          return false;
        }
        if (value is String) {
          return value.trim().isNotEmpty;
        }
        return true;
      }),
    );
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
