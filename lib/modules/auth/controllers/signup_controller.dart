import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stylebite/core/media/cover_image_crop_screen.dart';
import 'package:stylebite/core/utils/api_helper.dart';
import 'package:stylebite/core/utils/app_device_service.dart';
import 'package:stylebite/core/utils/app_helper.dart';
import '../../../app/routes/app_routes.dart';
import '../models/signup_model.dart';

class SignUpController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final isLoading = false.obs;

  final RxnString selectedImagePath = RxnString();
  final _picker = ImagePicker();

  final usernameError = RxnString();
  final emailError = RxnString();

  SignUpModel? signUpData;

  @override
  void onInit() {
    super.onInit();
    usernameController.addListener(() {
      if (usernameError.value != null) {
        usernameError.value = null;
        formKey.currentState?.validate();
      }
    });
    emailController.addListener(() {
      if (emailError.value != null) {
        emailError.value = null;
        formKey.currentState?.validate();
      }
    });
  }

  Future<void> pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (image != null) {
      final Uint8List? editedBytes = await Get.to(
        () => CoverImageCropScreen(
          imageFile: File(image.path),
          mode: PhotoCropMode.avatar,
        ),
        fullscreenDialog: true,
        transition: Transition.fadeIn,
        duration: const Duration(milliseconds: 180),
      );

      if (editedBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final editedFile = File('${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await editedFile.writeAsBytes(editedBytes);
        selectedImagePath.value = editedFile.path;
      }
    }
  }

  Future<void> signUp({
    required Future<bool> Function(String loginId) rememberLoginId,
  }) async {
    try {
      if (!formKey.currentState!.validate()) {
        return;
      }

      isLoading.value = true;
      usernameError.value = null;
      emailError.value = null;

      final metadata = await AppDeviceService.getLoginMetadata();
      signUpData = SignUpModel(
        name: nameController.text.trim(),
        username: usernameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        passwordConfirmation: confirmPasswordController.text,
        deviceId: metadata.deviceId,
        platform: metadata.platform,
        pushToken: metadata.pushToken,
        appVersion: metadata.appVersion,
      );

      final fields = signUpData!.toJson().map((key, value) => MapEntry(key, value.toString()));

      final response = await ApiHelper.multipartRequest(
        "auth/register",
        fields: fields,
        fileFieldName: "avatar",
        filePath: selectedImagePath.value,
      );

      if (response == null) {
        return;
      }
      final responseData = jsonDecode(response.body);

      if (responseData['status_code'] == 1) {
        final bearerToken = responseData['bearer_token'];
        final user = responseData['user'];
        
        Get.toNamed(AppRoutes.otp, arguments: {
          'token': bearerToken,
          'user': user,
          'email': emailController.text.trim(),
          'debug_otp': responseData['debug_otp'],
        });
      } else {
        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          if (errors['username'] != null) {
            usernameError.value = errors['username'][0];
          }
          if (errors['email'] != null) {
            emailError.value = errors['email'][0];
          }
          formKey.currentState?.validate();
        } else {
          errorSnackBar(
            message: responseData['message'] ?? 'Registration failed',
          );
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  void goToLogin() {
    // Explicitly go to Login instead of generic handleBack to avoid landing screen issue
    Get.offAllNamed(AppRoutes.login);
    Get.delete<SignUpController>(force: true);
  }

  @override
  void onClose() {
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
