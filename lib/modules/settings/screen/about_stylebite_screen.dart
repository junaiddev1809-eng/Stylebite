import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_hero_icon.dart';

class AboutStylebiteScreen extends StatelessWidget {
  const AboutStylebiteScreen({super.key});

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
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
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
                      child: AppHeroIconData(Icons.arrow_back_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'About StyleBite',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _AboutHero(),
                    SizedBox(height: 12),
                    _AboutStory(),
                    SizedBox(height: 12),
                    _AboutHighlights(),
                    SizedBox(height: 12),
                    _AboutFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCEFE8), Color(0xFFFFF8F3)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF2DDD1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const AppHeroIconData(Icons.restaurant_menu_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'StyleBite brings food lovers together.',
            style: AppFonts.plusJakarta(
              size: 20,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Discover, share, and celebrate food moments with a community built around great taste and real connections.',
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w500,
              color: AppColors.text,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutStory extends StatelessWidget {
  const _AboutStory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Our mission',
            style: AppFonts.plusJakarta(
              size: 16,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'We want to make food discovery and sharing feel simple, social, and inspiring. StyleBite is designed to help people connect through meals, memories, and recommendations.',
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w500,
              color: const Color(0xFF3D3D3D),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutHighlights extends StatelessWidget {
  const _AboutHighlights();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you can do here',
            style: AppFonts.plusJakarta(
              size: 16,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          _HighlightRow(
            icon: Icons.explore_outlined,
            title: 'Explore ideas',
            subtitle:
                'Browse content from the community and discover new tastes.',
          ),
          const SizedBox(height: 10),
          _HighlightRow(
            icon: Icons.favorite_border_rounded,
            title: 'Save favorites',
            subtitle: 'Keep track of posts and moments that stand out to you.',
          ),
          const SizedBox(height: 10),
          _HighlightRow(
            icon: Icons.people_outline_rounded,
            title: 'Stay connected',
            subtitle:
                'Follow people, share feedback, and build your food network.',
          ),
        ],
      ),
    );
  }
}

class _HighlightRow extends StatelessWidget {
  const _HighlightRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF7E7DD),
            borderRadius: BorderRadius.circular(12),
          ),
          child: AppHeroIconData(icon,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppFonts.beVietnam(
                  size: 14,
                  weight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w500,
                  color: const Color(0xFF5C5B5B),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutFooter extends StatelessWidget {
  const _AboutFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2F2F2E), Color(0xFF4B433E)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Contact',
            style: AppFonts.plusJakarta(
              size: 16,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Questions, feedback, or partnership ideas? Reach us at support@stylebite.com.',
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Version 1.0.2',
            style: AppFonts.beVietnam(
              size: 12,
              weight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
