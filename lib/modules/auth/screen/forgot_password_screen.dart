import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/forgot_password_controller.dart';
import '../widgets/auth_header.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final ForgotPasswordController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ForgotPasswordController>()
        ? Get.find<ForgotPasswordController>()
        : Get.put(ForgotPasswordController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<ForgotPasswordController>()) {
      Get.delete<ForgotPasswordController>();
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
                  title: 'Forgot Password',
                  subtitle: 'Enter your email to receive a reset PIN.',
                ),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _controller.emailController,
                  label: 'Email',
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: AppValidators.email,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 20),
                Obx(
                  () => AppPrimaryButton(
                    label: 'Continue',
                    onPressed: _controller.submitEmail,
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
