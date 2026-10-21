import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../controllers/intro_controller.dart';
import '../widgets/intro_page_indicator.dart';
import '../widgets/intro_step_card.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  late final IntroController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<IntroController>()
        ? Get.find<IntroController>()
        : Get.put(IntroController());
  }

  @override
  void dispose() {
    if (Get.isRegistered<IntroController>()) {
      Get.delete<IntroController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF5F0), AppColors.background],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _controller.skip,
                      child: Text(
                        'Skip',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w600,
                          color: AppColors.hintText,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller.pageController,
                      itemCount: _controller.steps.length,
                      onPageChanged: _controller.onPageChanged,
                      itemBuilder: (context, index) {
                        return IntroStepCard(step: _controller.steps[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Obx(
                    () => IntroPageIndicator(
                      total: _controller.steps.length,
                      currentIndex: _controller.currentIndex.value,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: ElevatedButton(
                        onPressed: _controller.next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Obx(
                          () => Text(
                            _controller.isLastStep ? 'Get Started' : 'Next',
                            style: AppFonts.beVietnam(
                              size: 15,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
