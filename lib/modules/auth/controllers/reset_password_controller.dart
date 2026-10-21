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
  ResetPasswordModel? resetData;

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    if (arguments is Map<String, dynamic>) {
      email.value = (arguments['email'] ?? '').toString();
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

      final response = await ApiHelper.postRequest(
        "auth/reset-password",
        resetData!.toJson(),
      );
      if (response == null) {
        return;
      }
      final responseData = jsonDecode(response.body);

      if (responseData['status_code'] == 1) {
        successSnackBar(
          message: responseData['message'] ?? 'Password reset successful',
        );
        Get.offAllNamed(AppRoutes.login);
      } else {
        errorSnackBar(
          message: responseData['message'] ?? 'Unable to reset password',
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
