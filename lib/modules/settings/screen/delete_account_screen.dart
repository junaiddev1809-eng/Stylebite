import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../controllers/delete_account_controller.dart';

class DeleteAccountScreen extends GetView<DeleteAccountController> {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the controller
    Get.put(DeleteAccountController());

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
                      child: AppHeroIconData(
                        Icons.arrow_back_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Delete Account',
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
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _DeleteAccountIntro(),
                      const SizedBox(height: 24),
                      Text(
                        'Reason for deletion',
                        style: AppFonts.plusJakarta(
                          size: 16,
                          weight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Obx(() => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF2DDD1),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButtonFormField<String>(
                                value: controller.selectedReason.value.isEmpty
                                    ? null
                                    : controller.selectedReason.value,
                                hint: Text(
                                  'Select a reason',
                                  style: AppFonts.beVietnam(
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.primary,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                items: controller.reasons.map((reason) {
                                  return DropdownMenuItem(
                                    value: reason,
                                    child: Text(
                                      reason,
                                      style: AppFonts.beVietnam(
                                        size: 14,
                                        weight: FontWeight.w500,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: controller.setSelectedReason,
                                validator: (value) => value == null || value.isEmpty
                                    ? 'Please select a reason'
                                    : null,
                              ),
                            ),
                          )),
                      const SizedBox(height: 24),
                      const _DeleteAccountCard(),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Obx(() => SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value
                          ? null
                          : controller.submitDeleteRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            AppColors.primary.withValues(alpha: 0.6),
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        elevation: 0,
                      ),
                      child: controller.isLoading.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Delete My Account',
                              style: AppFonts.beVietnam(
                                size: 14,
                                weight: FontWeight.w700,
                              ),
                            ),
                    ),
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeleteAccountIntro extends StatelessWidget {
  const _DeleteAccountIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF7E7DD),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const AppHeroIconData(
              Icons.delete_outline_rounded,
              color: AppColors.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Delete your account',
            textAlign: TextAlign.center,
            style: AppFonts.plusJakarta(
              size: 20,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We’re sorry to see you go. Please review what happens when you delete your StyleBite account.',
            textAlign: TextAlign.center,
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

class _DeleteAccountCard extends StatelessWidget {
  const _DeleteAccountCard();

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
                child: const AppHeroIconData(
                  Icons.warning_amber_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Before you delete your account',
                  style: AppFonts.plusJakarta(
                    size: 16,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _DeletePoint(
            text:
                'Your account and associated profile information will be permanently deleted.',
          ),
          const _DeletePoint(
            text:
                'Your posts, comments, and other account-related data may no longer be available.',
          ),
          const _DeletePoint(
            text:
                'This action cannot be undone once the account deletion is completed.',
          ),
          const _DeletePoint(
            text:
                'If you change your mind, you may need to create a new account.',
          ),
        ],
      ),
    );
  }
}

class _DeletePoint extends StatelessWidget {
  const _DeletePoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
              text,
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
    );
  }
}
