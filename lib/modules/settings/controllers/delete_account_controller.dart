import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/utils/app_helper.dart';

class DeleteAccountController extends GetxController {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  
  final RxString selectedReason = ''.obs;
  final RxBool isLoading = false.obs;

  final List<String> reasons = [
    'Privacy concerns',
    'I don\'t use the app anymore',
    'Too many notifications',
    'Found a better app',
    'Other',
  ];

  void setSelectedReason(String? reason) {
    if (reason != null) {
      selectedReason.value = reason;
    }
  }

  Future<void> submitDeleteRequest() async {
    if (!formKey.currentState!.validate()) return;

    isLoading.value = true;
    
    // Simulate API call for 2 seconds
    await Future.delayed(const Duration(seconds: 2));
    
    isLoading.value = false;
    
    successSnackBar(message: 'Account deletion request is submitted');
    
    // Navigate back or to a landing screen after a short delay
    await Future.delayed(const Duration(milliseconds: 500));
    Get.back();
  }
}
