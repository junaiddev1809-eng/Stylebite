import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_hero_icon.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
                        'Privacy Policy',
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
                    _PolicyIntro(),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '1. Information We Collect',
                      body:
                          'We may collect the following categories of information:',
                      bullets: [
                        'Account information such as name, email address, and profile details.',
                        'Content you upload or share, including posts, comments, and media files.',
                        'Usage information such as pages visited, actions taken, and device/browser details.',
                        'Communications you send to us, including support inquiries and feedback.',
                      ],
                    ),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '2. How We Use Your Information',
                      body: 'We use your information to:',
                      bullets: [
                        'Provide, operate, and maintain our services.',
                        'Personalize your experience and improve platform performance.',
                        'Communicate with you about updates, security alerts, and support.',
                        'Detect, prevent, and address fraud, abuse, and policy violations.',
                        'Comply with legal obligations and enforce our terms.',
                      ],
                    ),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '3. How We Share Information',
                      body:
                          'We do not sell your personal information. We may share information with service providers, legal authorities when required by law, or in connection with a merger, acquisition, or asset transfer.',
                    ),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '4. Data Retention',
                      body:
                          'We retain personal information only as long as necessary for the purposes described in this policy, unless a longer retention period is required by law.',
                    ),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '5. Security',
                      body:
                          'We implement reasonable administrative, technical, and organizational safeguards to protect your information. However, no method of transmission over the internet is completely secure.',
                    ),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '6. Your Choices and Rights',
                      body:
                          'Depending on your location, you may have rights to access, update, delete, or restrict use of your data.',
                      extraBody:
                          'You can request these actions by contacting us. We may need to verify your identity before processing certain requests.',
                    ),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '7. Third-Party Links',
                      body:
                          'Our website may contain links to third-party websites. We are not responsible for the privacy practices or content of those sites.',
                    ),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '8. Children\'s Privacy',
                      body:
                          'Our services are not directed to children under 13, and we do not knowingly collect personal information from children under 13.',
                    ),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '9. Changes to This Policy',
                      body:
                          'We may update this Privacy Policy from time to time. If we make material changes, we will update the "Last updated" date and post the revised policy on this page.',
                    ),
                    SizedBox(height: 12),
                    _PolicySection(
                      title: '10. Contact Us',
                      body:
                          'If you have questions about this Privacy Policy, please contact us at support@stylebite.com.',
                    ),
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

class _PolicyIntro extends StatelessWidget {
  const _PolicyIntro();

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
            'Last updated: June 2, 2026',
            style: AppFonts.beVietnam(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This Privacy Policy explains how we collect, use, disclose, and protect your information when you use our website and related services.',
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

class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.title,
    required this.body,
    this.bullets = const [],
    this.extraBody,
  });

  final String title;
  final String body;
  final List<String> bullets;
  final String? extraBody;

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
            title,
            style: AppFonts.plusJakarta(
              size: 16,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w500,
              color: const Color(0xFF3D3D3D),
              height: 1.55,
            ),
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...bullets.map(
              (bullet) => Padding(
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
                        bullet,
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
          if (extraBody != null) ...[
            const SizedBox(height: 10),
            Text(
              extraBody!,
              style: AppFonts.beVietnam(
                size: 14,
                weight: FontWeight.w500,
                color: const Color(0xFF3D3D3D),
                height: 1.55,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
