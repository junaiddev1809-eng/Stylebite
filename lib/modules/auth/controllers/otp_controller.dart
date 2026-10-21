import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_helper.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/utils/app_device_service.dart';
import '../../../core/utils/app_location_service.dart';
import '../../../core/utils/local_storage.dart';
import '../../../core/utils/app_session.dart';
import '../../../core/utils/deep_link_service.dart';

class OtpController extends GetxController {
  final otpController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  var isLoading = false.obs;
  var secondsRemaining = 120.obs; // 2 minutes
  var canResend = false.obs;
  Timer? _timer;

  // Data passed from signup/login
  late String? _token;
  late Map<String, dynamic>? _user;
  late String? _email;
  final debugOtp = RxnString();

  @override
  void onInit() {
    super.onInit();
    _token = Get.arguments?['token'];
    _user = Get.arguments?['user'];
    _email = Get.arguments?['email'];
    _applyDebugOtp(Get.arguments?['debug_otp']);
    startTimer();
  }

  void _applyDebugOtp(dynamic rawCode) {
    final code = rawCode?.toString().trim() ?? '';
    if (code.length != 6) {
      return;
    }
    debugOtp.value = code;
    otpController.text = code;
  }

  void startTimer() {
    canResend.value = false;
    secondsRemaining.value = 120;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining.value > 0) {
        secondsRemaining.value--;
      } else {
        canResend.value = true;
        _timer?.cancel();
      }
    });
  }

  String get timerText {
    int minutes = secondsRemaining.value ~/ 60;
    int seconds = secondsRemaining.value % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> verifyOtp() async {
    if (formKey.currentState?.validate() ?? false) {
      isLoading.value = true;
      try {
        final response = await ApiHelper.postRequest(
          "auth/verify-email-otp",
          {
            'email': _email,
            'code': otpController.text.trim(),
          },
        );

        if (response == null) return;

        final responseData = jsonDecode(response.body);

        if (responseData['status_code'] == 1) {
          // Token aur User data save karna
          final finalToken =
              AppSession.tokenFromAuthPayload(responseData) ?? _token;
          if (finalToken != null) {
            LocalStorage.setAccessKey(accessKey: finalToken);
          }

          final userData = responseData['user'] ?? _user;
          if (userData != null) {
            final username = userData['username']?.toString().trim();
            if (username != null && username.isNotEmpty) {
              LocalStorage.setUsername(username: username);
            }
            final userId = int.tryParse(userData['id']?.toString() ?? '');
            if (userId != null && userId > 0) {
              LocalStorage.setUserId(userId: userId);
            }
            final avatarUrl = userData['avatar_url']?.toString().trim();
            if (avatarUrl != null && avatarUrl.isNotEmpty) {
              LocalStorage.setAvatarUrl(avatarUrl: avatarUrl);
            }
          }

          await AppSession.attachRealtimeIfNeeded();
          unawaited(AppDeviceService.syncPushToken());
          await AppLocationService.requestPermission();

          successSnackBar(message: responseData['message'] ?? 'OTP Verified successfully');
          Get.offAllNamed(AppRoutes.landing);
          unawaited(DeepLinkService.flushPending());
        } else {
          errorSnackBar(message: responseData['message'] ?? 'OTP Verification failed');
        }
      } catch (e) {
        errorSnackBar(message: 'Something went wrong');
      } finally {
        isLoading.value = false;
      }
    }
  }

  Future<void> resendOtp() async {
    try {
      isLoading.value = true;
      final response = await ApiHelper.postRequest(
        "auth/resend-email-otp",
        {
          'email': _email,
        },
      );

      if (response == null) return;

      final responseData = jsonDecode(response.body);

      if (responseData['status_code'] == 1) {
        startTimer();
        _applyDebugOtp(responseData['debug_otp']);
        successSnackBar(
          message: debugOtp.value == null
              ? (responseData['message'] ?? 'OTP Resent successfully')
              : 'Local OTP: ${debugOtp.value}',
        );
      } else {
        errorSnackBar(message: responseData['message'] ?? 'Failed to resend OTP');
      }
    } catch (e) {
      errorSnackBar(message: 'Something went wrong');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    otpController.dispose();
    super.onClose();
  }
}
