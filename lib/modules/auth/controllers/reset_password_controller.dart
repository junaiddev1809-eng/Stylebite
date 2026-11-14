import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_helper.dart';

import '../../../app/routes/app_routes.dart';
import '../models/reset_password_model.dart';

class ResetPasswordController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final pinController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final isLoading = false.obs;

  final RxString email = ''.obs;
  final RxString purpose = 'reset'.obs;
  ResetPasswordModel? resetData;

  bool get isRecoverFlow => purpose.value == 'recover';

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    if (arguments is Map) {
      email.value = (arguments['email'] ?? '').toString();
      purpose.value = (arguments['purpose'] ?? 'reset').toString();
    }
  }

  Future<void> resetPassword() async {
    try {
      if (!formKey.currentState!.validate()) {
        return;
      }

      isLoading.value = true;
      resetData = ResetPasswordModel(
        email: email.value,
        code: pinController.text.trim(),
        password: passwordController.text,
        passwordConfirmation: confirmPasswordController.text,
      );

      final endpoint =
          isRecoverFlow ? 'account/recover/confirm' : 'auth/reset-password';
      final response = await ApiHelper.postRequest(
        endpoint,
        resetData!.toJson(),
      );
      if (response == null) {
        return;
      }
      final responseData = jsonDecode(response.body);

      if (responseData['status_code'] == 1) {
        successSnackBar(
          message: responseData['message'] ??
              (isRecoverFlow
                  ? 'Account recovered. Sign in with your new password.'
                  : 'Password reset successful'),
        );
        Get.offAllNamed(AppRoutes.login);
      } else {
        errorSnackBar(
          message: responseData['message'] ??
              (isRecoverFlow
                  ? 'Unable to recover account'
                  : 'Unable to reset password'),
        );
      }
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    pinController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
