import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../controllers/splash_controller.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterController;
  late final Animation<double> _enter;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<SplashController>()) {
      Get.put(SplashController());
    }
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _enter = CurvedAnimation(parent: _enterController, curve: Curves.easeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      precacheImage(const AssetImage(AppAssets.brandLogo), context);
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<SplashController>()) {
      Get.delete<SplashController>();
    }
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _enter,
          child: Image.asset(
            AppAssets.brandLogo,
            width: 128,
            height: 128,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.restaurant_menu_rounded,
              size: 72,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
