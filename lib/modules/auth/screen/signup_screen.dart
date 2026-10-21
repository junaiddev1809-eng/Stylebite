import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_login_id_service.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/signup_controller.dart';
import '../widgets/auth_header.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  late final SignUpController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<SignUpController>()
        ? Get.find<SignUpController>()
        : Get.put(SignUpController());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Form(
            key: _controller.formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthHeader(
                  title: 'Create Account',
                  subtitle: 'Join StyleBite and personalize your fashion feed.',
                ),
                const SizedBox(height: 28),
                Center(
                  child: Stack(
                    children: [
                      Obx(
                        () => CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.grey[200],
                          backgroundImage: _controller.selectedImagePath.value != null
                              ? FileImage(File(_controller.selectedImagePath.value!))
                              : null,
                          child: _controller.selectedImagePath.value == null
                              ? Icon(
                                  Icons.person_outline,
                                  size: 50,
                                  color: Colors.grey[400],
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _controller.pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _controller.nameController,
                  label: 'Name',
                  hintText: 'Your full name',
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      AppValidators.requiredField(value, fieldName: 'Name'),
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _controller.usernameController,
                  label: 'Username',
                  hintText: 'Choose a unique username',
                  textInputAction: TextInputAction.next,
                  errorMaxLines: 2,
                  validator: (value) {
                    final requiredError =
                    AppValidators.requiredField(value, fieldName: 'Username');
                    if (requiredError != null) return requiredError;

                    return _controller.usernameError.value;
                  },
                  prefixIcon: Icons.alternate_email,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _controller.emailController,
                  label: 'Email',
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final validatorError = AppValidators.email(value);
                    if (validatorError != null) return validatorError;
                    
                    return _controller.emailError.value;
                  },
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _controller.passwordController,
                  label: 'Password',
                  hintText: 'Create password',
                  textInputAction: TextInputAction.next,
                  validator: AppValidators.password,
                  isPassword: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _controller.confirmPasswordController,
                  label: 'Confirm Password',
                  hintText: 'Re-enter password',
                  textInputAction: TextInputAction.done,
                  validator: (value) => AppValidators.confirmPassword(
                    value: value,
                    originalPassword: _controller.passwordController.text,
                  ),
                  isPassword: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 20),
                Obx(
                  () => AppPrimaryButton(
                    label: 'Sign Up',
                    onPressed: () => _controller.signUp(
                      rememberLoginId: (loginId) =>
                          AppLoginIdService.rememberLoginIdIfAllowed(
                            loginId,
                            context: context,
                          ),
                    ),
                    isLoading: _controller.isLoading.value,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: _controller.goToLogin,
                      child: const Text('Login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
