import 'dart:async';
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
import 'package:stylebite/core/utils/app_validators.dart';
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
  /// `true` = available (green), `false` = taken (red), `null` = unknown/idle.
  final emailAvailable = RxnBool();
  final isCheckingEmail = false.obs;

  SignUpModel? signUpData;
  Timer? _emailCheckTimer;
  int _emailCheckToken = 0;

  @override
  void onInit() {
    super.onInit();
    usernameController.addListener(() {
      if (usernameError.value != null) {
        usernameError.value = null;
        formKey.currentState?.validate();
      }
    });
  }

  void onEmailChanged(String value) {
    emailError.value = null;
    emailAvailable.value = null;
    _emailCheckTimer?.cancel();

    final email = value.trim();
    if (AppValidators.signupEmail(email) != null) {
      isCheckingEmail.value = false;
      return;
    }

    final token = ++_emailCheckToken;
    isCheckingEmail.value = true;
    _emailCheckTimer = Timer(const Duration(milliseconds: 450), () {
      _checkEmailAvailability(email, token);
    });
  }

  Future<void> _checkEmailAvailability(String email, int token) async {
    try {
      final response = await ApiHelper.postRequest('auth/check-email', {
        'email': email,
      });
      if (token != _emailCheckToken) return;
      if (response == null) {
        emailAvailable.value = null;
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status_code'] != 1) {
        emailAvailable.value = null;
        return;
      }

      final available = data['available'] == true;
      emailAvailable.value = available;
      emailError.value = available
          ? null
          : (data['message']?.toString() ??
              'An account already exists with this email.');
      formKey.currentState?.validate();
    } catch (_) {
      if (token == _emailCheckToken) {
        emailAvailable.value = null;
      }
    } finally {
      if (token == _emailCheckToken) {
        isCheckingEmail.value = false;
      }
    }
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
        final editedFile = File(
          '${tempDir.path}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
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

      if (emailAvailable.value == false) {
        emailError.value = 'An account already exists with this email.';
        formKey.currentState?.validate();
        return;
      }

      // If the user tapped Sign Up before the debounce finished, re-check once.
      if (emailAvailable.value == null &&
          AppValidators.signupEmail(emailController.text.trim()) == null) {
        isLoading.value = true;
        await _checkEmailAvailability(
          emailController.text.trim(),
          ++_emailCheckToken,
        );
        if (emailAvailable.value == false) {
          return;
        }
      }

      isLoading.value = true;
      usernameError.value = null;

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

      final fields = signUpData!.toJson().map(
        (key, value) => MapEntry(key, value.toString()),
      );

      final response = await ApiHelper.multipartRequest(
        'auth/register',
        fields: fields,
        fileFieldName: 'avatar',
        filePath: selectedImagePath.value,
      );

      if (response == null) {
        return;
      }
      final responseData = jsonDecode(response.body);

      if (responseData['status_code'] == 1) {
        final user = responseData['user'];

        Get.toNamed(
          AppRoutes.otp,
          arguments: {
            'email': emailController.text.trim(),
            'user': user,
            'purpose': 'email_verification',
            'debug_otp': responseData['debug_otp'],
          },
        );
      } else {
        if (responseData['errors'] != null) {
          final errors = responseData['errors'] as Map<String, dynamic>;
          if (errors['username'] != null) {
            usernameError.value = errors['username'][0];
          }
          if (errors['email'] != null) {
            emailError.value = errors['email'][0].toString();
            emailAvailable.value = false;
          }
          formKey.currentState?.validate();
        } else {
          final message =
              responseData['message']?.toString() ?? 'Registration failed';
          if (message.toLowerCase().contains('email') ||
              message.toLowerCase().contains('account already')) {
            emailError.value = message.contains('already')
                ? 'An account already exists with this email.'
                : message;
            emailAvailable.value = false;
            formKey.currentState?.validate();
          } else {
            errorSnackBar(message: message);
          }
        }
      }
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  void goToLogin() {
    Get.offAllNamed(AppRoutes.login);
    Get.delete<SignUpController>(force: true);
  }

  @override
  void onClose() {
    _emailCheckTimer?.cancel();
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}
