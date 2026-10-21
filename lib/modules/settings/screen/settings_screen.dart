import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_media_source_sheet.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../memories/screen/memories_screen.dart';
import '../../reports/screen/my_reports_screen.dart';
import '../../support/screen/support_tickets_screen.dart';
import '../screen/about_stylebite_screen.dart';
import '../screen/blocked_users_screen.dart';
import '../screen/help_center_screen.dart';
import '../screen/privacy_policy_screen.dart';
import '../controllers/settings_controller.dart';
import '../widgets/settings_row_tile.dart';
import '../widgets/settings_section_card.dart';
import 'delete_account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<SettingsController>()
        ? Get.find<SettingsController>()
        : Get.put(SettingsController());
  }

  @override
  Widget build(BuildContext context) {
    final profileController = _controller.profileController;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.85),
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
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      child: const AppHeroIconData(Icons.arrow_back_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ).createShader(bounds);
                        },
                        child: Text(
                          'Settings',
                          style: AppFonts.plusJakarta(
                            size: 22,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  children: [
                    SettingsSectionCard(
                      title: 'Account',
                      children: [
                        SettingsRowTile(
                          title: 'Open Profile',
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: AppBackNavigation.handleBack,
                        ),
                        SettingsRowTile(
                          title: 'Change Password',
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: () {},
                        ),
                        SettingsRowTile(
                          title: 'Privacy Policy',
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: () =>
                              Get.to<void>(() => const PrivacyPolicyScreen()),
                        ),
                        SettingsRowTile(
                          title: 'Blocked Accounts',
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: () =>
                              Get.to<void>(() => const BlockedUsersScreen()),
                        ),
                        SettingsRowTile(
                          title: 'My Reports',
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: () =>
                              Get.to<void>(() => const MyReportsScreen()),
                        ),
                        SettingsRowTile(
                          title: 'Memories Archive',
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: () =>
                              Get.to<void>(() => const MemoriesScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Obx(() {
                      final coverUrl = profileController.wallpaperImageUrl.value
                          .trim();

                      return SettingsSectionCard(
                        title: 'Profile Appearance',
                        subtitle:
                            'Your wallpaper preview and profile styling at a glance.',
                        children: [
                          Container(
                            width: double.infinity,
                            height: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF6E9DF), Color(0xFFFFF8F3)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(18),
                                    child: coverUrl.isEmpty
                                        ? Container(
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0xFFF7E6D8),
                                                  Color(0xFFFFF3EC),
                                                ],
                                              ),
                                            ),
                                            child: const Center(
                                              child: AppHeroIconData(Icons.wallpaper_outlined,
                                                color: AppColors.primary,
                                                size: 42,
                                              ),
                                            ),
                                          )
                                        : CachedNetworkImage(
                                            imageUrl: coverUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              color: const Color(0xFFF9F6F5),
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              color: const Color(0xFFF9F6F5),
                                              child: const Center(
                                                child: AppHeroIconData(Icons
                                                      .image_not_supported_outlined,
                                                  color:
                                                      AppColors.hintText,
                                                  size: 38,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  left: 12,
                                  top: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.84,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'Wallpaper',
                                      style: AppFonts.beVietnam(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.42,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: AppVerifiedName(
                                      name: profileController.displayName,
                                      username: profileController.username,
                                      isVerified:
                                          profileController
                                              .user
                                              .value
                                              ?.isVerifiedBadge ==
                                          true,
                                      badgeSize: 12,
                                      style: AppFonts.beVietnam(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F0EF),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Live preview',
                                  style: AppFonts.beVietnam(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8EBDD),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Wallpaper ready',
                                  style: AppFonts.beVietnam(
                                    size: 11,
                                    weight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Edit wallpaper from your profile screen to keep this preview in sync.',
                            style: AppFonts.beVietnam(
                              size: 12,
                              weight: FontWeight.w500,
                              color: AppColors.hintText,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: ElevatedButton(
                                onPressed:
                                    profileController.isUploadingCover.value
                                    ? null
                                    : () async {
                                        final source =
                                            await showMediaSourceSheet(context);
                                        if (source == null) {
                                          return;
                                        }
                                        await _controller.profileController
                                            .pickAndUploadCover(
                                              fromCamera:
                                                  source ==
                                                  MediaSourceChoice.camera,
                                            );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: profileController.isUploadingCover.value
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        'Upload Cover Photo',
                                        style: AppFonts.beVietnam(
                                          size: 14,
                                          weight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),
                    SettingsSectionCard(
                      title: 'Support',
                      children: [
                        SettingsRowTile(
                          title: 'Support Tickets',
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: () =>
                              Get.to<void>(() => const SupportTicketsScreen()),
                        ),
                        SettingsRowTile(
                          title: 'Help Center',
                          trailingIcon: Icons.open_in_new_rounded,
                          onTap: () =>
                              Get.to<void>(() => const HelpCenterScreen()),
                        ),
                        SettingsRowTile(
                          title: 'Delete Account',
                          trailingIcon: Icons.chevron_right_rounded,
                          onTap: () =>
                              Get.to<void>(() => const DeleteAccountScreen()),
                        ),
                        SettingsRowTile(
                          title: 'About StyleBite',
                          trailingIcon: Icons.info_outline_rounded,
                          onTap: () =>
                              Get.to<void>(() => const AboutStylebiteScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () =>
                              _controller.showLogoutConfirmation(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            'Log Out',
                            style: AppFonts.beVietnam(
                              size: 14,
                              weight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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
