import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/reset_password_controller.dart';
import '../widgets/auth_header.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final ResetPasswordController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ResetPasswordController>()
        ? Get.find<ResetPasswordController>()
        : Get.put(ResetPasswordController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<ResetPasswordController>()) {
      Get.delete<ResetPasswordController>();
    }
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
                  title: 'Reset Password',
                  subtitle:
                      'Enter the 6 digit PIN sent to your email and set a new password.',
                ),
                const SizedBox(height: 18),
                Obx(
                  () => Text(
                    _controller.email.value.isEmpty
                        ? 'Email: -'
                        : 'Email: ${_controller.email.value}',
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _controller.pinController,
                  label: '6 Digit PIN',
                  hintText: '123456',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  maxLength: 6,
                  validator: AppValidators.pin,
                  prefixIcon: Icons.pin_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _controller.passwordController,
                  label: 'New Password',
                  hintText: 'Enter new password',
                  textInputAction: TextInputAction.next,
                  validator: AppValidators.password,
                  isPassword: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _controller.confirmPasswordController,
                  label: 'Confirm Password',
                  hintText: 'Re-enter new password',
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
                    label: 'Reset Password',
                    onPressed: _controller.resetPassword,
                    isLoading: _controller.isLoading.value,
                  ),
                ),

                const SizedBox(height: 400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
