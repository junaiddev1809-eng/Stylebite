import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_helper.dart';

class ChangePasswordController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final currentPasswordController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final isLoading = false.obs;

  Future<void> changePassword() async {
    if (!formKey.currentState!.validate()) {
      return;
    }

    isLoading.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'auth/change-password',
        body: {
          'current_password': currentPasswordController.text,
          'password': passwordController.text,
          'password_confirmation': confirmPasswordController.text,
        },
      );
      if (response == null) {
        return;
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      if (responseData['status_code'] == 1) {
        successSnackBar(
          message: responseData['message']?.toString() ??
              'Password changed successfully',
        );
        currentPasswordController.clear();
        passwordController.clear();
        confirmPasswordController.clear();
        Get.back<void>();
        return;
      }

      final errors = responseData['errors'];
      String? detail;
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            detail = value.first.toString();
            break;
          }
          if (value != null) {
            detail = value.toString();
            break;
          }
        }
      }

      errorSnackBar(
        message: detail ??
            responseData['message']?.toString() ??
            'Unable to change password',
      );
    } catch (e) {
      errorSnackBar(message: 'Unable to change password right now.');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    currentPasswordController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
