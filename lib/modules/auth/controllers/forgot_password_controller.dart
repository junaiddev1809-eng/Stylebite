import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_helper.dart';

import '../../../app/routes/app_routes.dart';

class ForgotPasswordController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final isLoading = false.obs;

  Future<void> submitEmail() async {
    try {
      if (!formKey.currentState!.validate()) {
        return;
      }

      isLoading.value = true;
      final email = emailController.text.trim();
      final response = await ApiHelper.postRequest("auth/forgot-password", {
        "email": email,
      });
      if (response == null) {
        return;
      }
      final responseData = jsonDecode(response.body);

      if (responseData['status_code'] == 1) {
        successSnackBar(
          message: responseData['message'] ?? 'OTP sent to your email',
        );
        Get.toNamed(AppRoutes.resetPassword, arguments: {'email': email});
      } else {
        errorSnackBar(message: responseData['message'] ?? 'Unable to send OTP');
      }
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    emailController.dispose();
    super.onClose();
  }
}
