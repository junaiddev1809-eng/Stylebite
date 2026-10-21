import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_validators.dart';
import '../../../core/widgets/app_primary_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/utils/app_login_id_service.dart';
import '../controllers/login_controller.dart';
import '../widgets/auth_header.dart';
import '../widgets/social_login_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<LoginController>()
        ? Get.find<LoginController>()
        : Get.put(LoginController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<LoginController>()) {
      Get.delete<LoginController>();
    }
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
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthHeader(
                  title: 'Welcome Back',
                  subtitle: 'Sign in to continue your style journey.',
                ),
                const SizedBox(height: 28),
                AppTextField(
                  controller: _controller.emailController,
                  label: 'Email',
                  hintText: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: AppValidators.email,
                  prefixIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  controller: _controller.passwordController,
                  label: 'Password',
                  hintText: 'Enter password',
                  textInputAction: TextInputAction.done,
                  validator: AppValidators.password,
                  isPassword: true,
                  prefixIcon: Icons.lock_outline,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _controller.goToForgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),
                Obx(
                  () => AppPrimaryButton(
                    label: 'Login',
                    onPressed: () => _controller.login(
                      rememberLoginId: (loginId) =>
                          AppLoginIdService.rememberLoginIdIfAllowed(
                            loginId,
                            context: context,
                          ),
                    ),
                    isLoading: _controller.isLoading.value,
                  ),
                ),
                const SizedBox(height: 18),
                // Apple only allows Sign In with Apple to appear alongside
                // other third-party logins on iOS; showing it on Android
                // (where it isn't properly supported here either) would
                // just offer a broken button, so each platform only shows
                // its own native provider.
                if (Platform.isAndroid) ...[
                  Obx(
                    () => SocialLoginButton(
                      label: 'Continue with Google',
                      icon: Icons.g_mobiledata_rounded,
                      onPressed: () => _controller.loginWithGoogle(
                        rememberLoginId: (loginId) =>
                            AppLoginIdService.rememberLoginIdIfAllowed(
                              loginId,
                              context: context,
                            ),
                      ),
                      isLoading: _controller.isGoogleLoading.value,
                    ),
                  ),
                  const SizedBox(height: 18),
                ] else if (Platform.isIOS) ...[
                  Obx(
                    () => SocialLoginButton(
                      label: 'Continue with Apple',
                      icon: Icons.apple,
                      onPressed: () => _controller.loginWithApple(
                        rememberLoginId: (loginId) =>
                            AppLoginIdService.rememberLoginIdIfAllowed(
                              loginId,
                              context: context,
                            ),
                      ),
                      isLoading: _controller.isAppleLoading.value,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? "),
                    TextButton(
                      onPressed: _controller.goToSignUp,
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
                 SizedBox(height: 250),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
