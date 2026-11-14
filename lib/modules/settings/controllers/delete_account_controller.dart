import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/app/routes/app_routes.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_helper.dart';
import 'package:stylebite/core/utils/local_storage.dart';
import 'package:stylebite/modules/messages/services/chat_presence_service.dart';
import 'package:stylebite/modules/messages/services/chat_socket_service.dart';
import 'package:stylebite/modules/post/services/post_interaction_store.dart';

/// In-app account deletion with a 1-day recovery window.
class DeleteAccountController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final isLoading = false.obs;
  final acknowledged = false.obs;

  Future<void> scheduleDeletion() async {
    if (isLoading.value) return;
    if (!formKey.currentState!.validate()) return;
    if (!acknowledged.value) {
      errorSnackBar(
        message: 'Confirm that you understand the 1-day recovery window.',
      );
      return;
    }

    isLoading.value = true;
    try {
      final response = await ApiHelper.postRequestWithAuthorization(
        'account/delete',
        body: {
          'password': passwordController.text,
        },
      );
      if (response == null) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status_code'] == 1) {
        successSnackBar(
          message: data['message']?.toString() ??
              'Account scheduled for deletion. You can recover within 1 day.',
        );
        await _signOutLocally();
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
            'Could not schedule account deletion.',
      );
    } catch (_) {
      errorSnackBar(message: 'Could not schedule account deletion.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _signOutLocally() async {
    try {
      await ChatPresenceService.instance.markOffline();
    } catch (_) {}
    try {
      await ChatSocketService.instance.disconnect();
    } catch (_) {}
    try {
      await ApiHelper.postRequestWithAuthorization(
        'auth/logout',
        interceptAuthFailure: false,
      );
    } catch (_) {}
    PostInteractionStore.ensure().clear();
    await LocalStorage.removeAccessKey();
    await LocalStorage.removeUsername();
    await LocalStorage.removeUserId();
    await LocalStorage.removeAvatarUrl();
    Get.offAllNamed(AppRoutes.login);
  }

  @override
  void onClose() {
    passwordController.dispose();
    super.onClose();
  }
}
