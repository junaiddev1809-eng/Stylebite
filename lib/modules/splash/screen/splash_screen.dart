import 'dart:async';

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
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<SplashController>()) {
      Get.put(SplashController());
    }

    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _fade = CurvedAnimation(
      parent: _enterController,
      curve: const Interval(0, 0.75, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _enterController,
        curve: const Interval(0, 1, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startLogo());
    });
  }

  Future<void> _startLogo() async {
    if (!mounted) {
      return;
    }
    try {
      await precacheImage(const AssetImage(AppAssets.brandLogo), context);
    } catch (_) {
      // Still show fallback icon via Image.errorBuilder.
    }
    if (!mounted) {
      return;
    }
    await _enterController.forward();
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
        child: AnimatedBuilder(
          animation: _enterController,
          builder: (context, child) {
            return Opacity(
              opacity: _fade.value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: _scale.value,
                filterQuality: FilterQuality.medium,
                child: child,
              ),
            );
          },
          child: Image.asset(
            AppAssets.brandLogo,
            width: 128,
            height: 128,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
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
