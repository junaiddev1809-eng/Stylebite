import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_helper.dart';

import '../../../app/routes/app_routes.dart';

class RecoverAccountController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final arguments = Get.arguments;
    if (arguments is Map && arguments['email'] != null) {
      emailController.text = arguments['email'].toString();
    }
  }

  Future<void> submitEmail() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    try {
      final email = emailController.text.trim();
      final response = await ApiHelper.postRequest('account/recover/request', {
        'email': email,
      });
      if (response == null) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status_code'] == 1) {
        successSnackBar(
          message: data['message']?.toString() ?? 'OTP sent to your email',
        );
        Get.toNamed(
          AppRoutes.resetPassword,
          arguments: {
            'email': email,
            'purpose': 'recover',
          },
        );
        return;
      }

      final errors = data['errors'];
      String? detail;
      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            detail = value.first.toString();
            break;
          }
        }
      }
      errorSnackBar(
        message: detail ??
            data['message']?.toString() ??
            'Unable to start account recovery',
      );
    } catch (_) {
      errorSnackBar(message: 'Unable to start account recovery');
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
