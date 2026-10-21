import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../home/presentation/home_page.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_IntroStep> _steps = const [
    _IntroStep(
      icon: Icons.style_rounded,
      title: 'Discover Fresh Looks',
      description:
          'Get bite-sized style picks curated daily to keep your wardrobe up to date.',
    ),
    _IntroStep(
      icon: Icons.auto_awesome_rounded,
      title: 'Personalized For You',
      description:
          'Swipe through trends, save favorites, and build your own fashion feed.',
    ),
    _IntroStep(
      icon: Icons.shopping_bag_rounded,
      title: 'Shop Smart, Fast',
      description:
          'Jump from inspiration to outfit in seconds with direct product links.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
    );
  }

  void _goNext() {
    if (_currentIndex == _steps.length - 1) {
      _goToHome();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentIndex == _steps.length - 1;

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
                      onPressed: _goToHome,
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
                      controller: _pageController,
                      itemCount: _steps.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final step = _steps[index];
                        return _StepCard(step: step);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentIndex == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          gradient: _currentIndex == index
                              ? const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary,
                                  ],
                                )
                              : null,
                          color: _currentIndex == index
                              ? null
                              : AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
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
                        onPressed: _goNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isLastPage ? 'Get Started' : 'Next',
                          style: AppFonts.beVietnam(
                            size: 15,
                            weight: FontWeight.w700,
                            color: Colors.white,
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

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final _IntroStep step;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 186,
          height: 186,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.secondary],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(255, 77, 109, 0.25),
                blurRadius: 35,
                offset: Offset(0, 18),
              ),
            ],
          ),
          child: AppHeroIconData(step.icon, size: 88, color: Colors.white),
        ),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            step.title,
            textAlign: TextAlign.center,
            style: AppFonts.plusJakarta(
              size: 30,
              height: 1.2,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            step.description,
            textAlign: TextAlign.center,
            style: AppFonts.beVietnam(
              size: 16,
              height: 1.5,
              weight: FontWeight.w500,
              color: AppColors.hintText,
            ),
          ),
        ),
      ],
    );
  }
}

class _IntroStep {
  const _IntroStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
