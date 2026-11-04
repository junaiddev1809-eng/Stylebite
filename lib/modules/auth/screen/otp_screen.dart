import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/app/routes/app_routes.dart';
import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../controllers/otp_controller.dart';
import '../widgets/auth_header.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  late final OtpController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(OtpController());
  }

  @override
  void dispose() {
    Get.delete<OtpController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Form(
            key: _controller.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(
                  () => AuthHeader(
                    title: _controller.isLoginTwoFactor
                        ? 'Confirm login'
                        : 'Verify OTP',
                    subtitle: _controller.debugOtp.value == null
                        ? (_controller.isLoginTwoFactor
                            ? 'We emailed a 6-digit code to your Gmail. Enter it to finish signing in.'
                            : 'Enter the 6-digit code sent to your email.')
                        : 'Local backend — use this code: ${_controller.debugOtp.value}',
                  ),
                ),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _controller.otpController,
                  label: 'OTP Code',
                  hintText: '000000',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  validator: AppValidators.pin,
                  prefixIcon: Icons.lock_clock_outlined,
                ),
                const SizedBox(height: 14),
                Center(
                  child: Obx(() => Column(
                        children: [
                          if (!_controller.canResend.value)
                            Text(
                              'Resend code in ${_controller.timerText}',
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          if (_controller.canResend.value)
                            TextButton(
                              onPressed: _controller.resendOtp,
                              child: const Text('Resend OTP'),
                            ),
                        ],
                      )),
                ),
                const SizedBox(height: 24),
                Obx(
                  () => AppPrimaryButton(
                    label: 'Confirm',
                    onPressed: _controller.verifyOtp,
                    isLoading: _controller.isLoading.value,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _controller.isLoginTwoFactor
                          ? 'Back to '
                          : "Don't have an account? ",
                    ),
                    TextButton(
                      onPressed: () => Get.offAllNamed(
                        _controller.isLoginTwoFactor
                            ? AppRoutes.login
                            : AppRoutes.signUp,
                      ),
                      child: Text(
                        _controller.isLoginTwoFactor ? 'Log In' : 'Sign Up',
                      ),
                    ),
                  ],
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
