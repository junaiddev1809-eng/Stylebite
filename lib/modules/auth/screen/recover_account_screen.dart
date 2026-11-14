import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/recover_account_controller.dart';
import '../widgets/auth_header.dart';

class RecoverAccountScreen extends StatefulWidget {
  const RecoverAccountScreen({super.key});

  @override
  State<RecoverAccountScreen> createState() => _RecoverAccountScreenState();
}

class _RecoverAccountScreenState extends State<RecoverAccountScreen> {
  late final RecoverAccountController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<RecoverAccountController>()
        ? Get.find<RecoverAccountController>()
        : Get.put(RecoverAccountController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<RecoverAccountController>()) {
      Get.delete<RecoverAccountController>();
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
                  title: 'Recover Account',
                  subtitle:
                      'Enter the email for the account you want to recover. We’ll send a 6-digit code.',
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
                    label: 'Send recovery code',
                    onPressed: _controller.submitEmail,
                    isLoading: _controller.isLoading.value,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
