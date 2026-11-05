import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/change_password_controller.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late final ChangePasswordController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ChangePasswordController>()
        ? Get.find<ChangePasswordController>()
        : Get.put(ChangePasswordController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<ChangePasswordController>()) {
      Get.delete<ChangePasswordController>();
    }
    super.dispose();
  }

  String? _newPasswordValidator(String? value) {
    final requiredError = AppValidators.requiredField(
      value,
      fieldName: 'New password',
    );
    if (requiredError != null) {
      return requiredError;
    }
    if (value!.trim().length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.88),
                border: Border(
                  bottom: BorderSide(color: AppColors.divider),
                ),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: AppBackNavigation.handleBack,
                    borderRadius: BorderRadius.circular(999),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: AppHeroIconData(
                        Icons.arrow_back_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Change Password',
                        style: AppFonts.plusJakarta(
                          size: 20,
                          weight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Form(
                  key: _controller.formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update your password to keep your account secure.',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w500,
                          color: AppColors.text.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 20),
                      AppTextField(
                        controller: _controller.currentPasswordController,
                        label: 'Current Password',
                        hintText: 'Enter current password',
                        textInputAction: TextInputAction.next,
                        validator: (value) => AppValidators.requiredField(
                          value,
                          fieldName: 'Current password',
                        ),
                        isPassword: true,
                        prefixIcon: Icons.lock_outline,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _controller.passwordController,
                        label: 'New Password',
                        hintText: 'Enter new password',
                        textInputAction: TextInputAction.next,
                        validator: _newPasswordValidator,
                        isPassword: true,
                        prefixIcon: Icons.lock_outline,
                      ),
                      const SizedBox(height: 14),
                      AppTextField(
                        controller: _controller.confirmPasswordController,
                        label: 'Confirm New Password',
                        hintText: 'Re-enter new password',
                        textInputAction: TextInputAction.done,
                        validator: (value) => AppValidators.confirmPassword(
                          value: value,
                          originalPassword: _controller.passwordController.text,
                        ),
                        isPassword: true,
                        prefixIcon: Icons.lock_outline,
                      ),
                      const SizedBox(height: 24),
                      Obx(
                        () => AppPrimaryButton(
                          label: 'Update Password',
                          onPressed: _controller.changePassword,
                          isLoading: _controller.isLoading.value,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
