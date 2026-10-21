import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../support/screen/new_support_ticket_screen.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

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
                        'Help Center',
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
                    _HelpIntro(),
                    SizedBox(height: 12),
                    _HelpCard(
                      title: 'Account and login',
                      icon: Icons.verified_user_outlined,
                      items: [
                        'Use the email address linked to your StyleBite account.',
                        'If you forgot your password, use the reset password flow from the login screen.',
                        'Make sure your app is updated if login or verification is not working as expected.',
                      ],
                    ),
                    SizedBox(height: 12),
                    _HelpCard(
                      title: 'Posting and profile',
                      icon: Icons.post_add_outlined,
                      items: [
                        'Upload clear images and keep captions concise for better engagement.',
                        'You can update your profile details from Edit Profile.',
                        'If media fails to upload, check your network connection and try again.',
                      ],
                    ),
                    SizedBox(height: 12),
                    _HelpCard(
                      title: 'Safety and moderation',
                      icon: Icons.shield_outlined,
                      items: [
                        'Use Blocked Accounts to manage people you do not want to interact with.',
                        'Report suspicious activity to our support team so we can review it.',
                        'Keep your login details private and avoid sharing your account with others.',
                      ],
                    ),
                    SizedBox(height: 12),
                    _ContactCard(),
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

class _HelpIntro extends StatelessWidget {
  const _HelpIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFCEFE8), Color(0xFFFFF8F3)],
        ),
        borderRadius: BorderRadius.circular(20),
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
          Text(
            'Support when you need it',
            style: AppFonts.plusJakarta(
              size: 18,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse quick answers below or reach out directly if you still need a hand.',
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w500,
              color: AppColors.text,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

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
          Row(
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
                child: Text(
                  title,
                  style: AppFonts.plusJakarta(
                    size: 16,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 7),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w500,
                        color: const Color(0xFF3D3D3D),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

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
            'Need more help?',
            style: AppFonts.plusJakarta(
              size: 18,
              weight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Open a support ticket and our team will get back to you as soon as possible.',
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  Get.to<int>(() => const NewSupportTicketScreen()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2D2D2D),
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Text(
                'Open a Ticket',
                style: AppFonts.beVietnam(size: 13, weight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

