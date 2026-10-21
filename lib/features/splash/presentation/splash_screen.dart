import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../intro/presentation/intro_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _cardController;
  late final AnimationController _logoFloatController;
  late final AnimationController _textController;
  late final AnimationController _taglineController;
  late final AnimationController _loaderController;
  Timer? _autoNavTimer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..forward();

    _logoFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat(reverse: true);

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _loaderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();

    _textController.forward();
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (mounted) {
        _taglineController.forward();
      }
    });

    _autoNavTimer = Timer(const Duration(milliseconds: 2600), _goToIntro);
  }

  @override
  void dispose() {
    _autoNavTimer?.cancel();
    _cardController.dispose();
    _logoFloatController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  void _goToIntro() {
    if (!mounted || _hasNavigated) {
      return;
    }

    _hasNavigated = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const IntroScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardOpacity = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOut,
    );
    final cardSlide = Tween<double>(begin: 16, end: 0).animate(cardOpacity);
    final cardScale = Tween<double>(begin: 0.98, end: 1).animate(cardOpacity);

    final logoOffset = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _logoFloatController, curve: Curves.easeInOut),
    );

    final textScale = Tween<double>(
      begin: 0.96,
      end: 1,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    final textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    final taglineOpacity = CurvedAnimation(
      parent: _taglineController,
      curve: Curves.easeOut,
    );
    final taglineOffset = Tween<double>(
      begin: 8,
      end: 0,
    ).animate(taglineOpacity);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.background),
          const _BgGlow(
            alignment: Alignment(0.8, -1.2),
            width: 1200,
            height: 520,
            innerColor: Color.fromRGBO(255, 77, 109, 0.2),
          ),
          const _BgGlow(
            alignment: Alignment(-1, 1),
            width: 850,
            height: 450,
            innerColor: Color.fromRGBO(255, 138, 91, 0.18),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _cardController,
              builder: (context, child) {
                return Opacity(
                  opacity: cardOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, cardSlide.value),
                    child: Transform.scale(
                      scale: cardScale.value,
                      child: child,
                    ),
                  ),
                );
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.card),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(47, 47, 46, 0.35),
                              offset: Offset(0, 26),
                              blurRadius: 45,
                              spreadRadius: -28,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              children: [
                                AnimatedBuilder(
                                  animation: _logoFloatController,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(0, logoOffset.value),
                                      child: child,
                                    );
                                  },
                                  child: Image.asset(
                                    AppAssets.brandLogo,
                                    width: 88,
                                    height: 88,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const _FallbackBrandIcon(),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                FadeTransition(
                                  opacity: textOpacity,
                                  child: ScaleTransition(
                                    scale: textScale,
                                    child: Image.asset(
                                      AppAssets.brandTextLogo,
                                      width: 220,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) => Text(
                                            'StyleBite',
                                            style: AppFonts.plusJakarta(
                                              size: 38,
                                              weight: FontWeight.w800,
                                              color: AppColors.text,
                                            ),
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            FadeTransition(
                              opacity: taglineOpacity,
                              child: AnimatedBuilder(
                                animation: _taglineController,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(0, taglineOffset.value),
                                    child: child,
                                  );
                                },
                                child: ShaderMask(
                                  shaderCallback: (bounds) {
                                    return const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary,
                                        AppColors.secondary,
                                      ],
                                    ).createShader(bounds);
                                  },
                                  child: Text(
                                    'Your Daily Style Bite',
                                    textAlign: TextAlign.center,
                                    style: AppFonts.plusJakarta(
                                      size: 22,
                                      weight: FontWeight.w800,
                                      height: 1.25,
                                      letterSpacing: 0.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(255, 77, 109, 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: AnimatedBuilder(
                                animation: _loaderController,
                                builder: (context, child) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: _loaderController.value,
                                      child: child,
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.primary,
                                        AppColors.secondary,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Preparing your feed...',
                              style: AppFonts.beVietnam(
                                size: 12,
                                weight: FontWeight.w500,
                                color: AppColors.hintText.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.all(
                                  Radius.circular(999),
                                ),
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  _autoNavTimer?.cancel();
                                  _goToIntro();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                child: Text(
                                  'Enter App',
                                  style: AppFonts.beVietnam(
                                    size: 12,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BgGlow extends StatelessWidget {
  const _BgGlow({
    required this.alignment,
    required this.width,
    required this.height,
    required this.innerColor,
  });

  final Alignment alignment;
  final double width;
  final double height;
  final Color innerColor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [innerColor, Colors.transparent],
              stops: const [0, 0.6],
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackBrandIcon extends StatelessWidget {
  const _FallbackBrandIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
      ),
      child: const AppHeroIconData(Icons.restaurant_menu_rounded, color: Colors.white),
    );
  }
}
