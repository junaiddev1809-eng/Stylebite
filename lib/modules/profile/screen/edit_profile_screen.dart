import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../settings/widgets/settings_section_card.dart';
import '../controllers/edit_profile_controller.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<EditProfileController>()
        ? Get.find<EditProfileController>()
        : Get.put(EditProfileController());
  }

  @override
  void dispose() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (Get.isRegistered<EditProfileController>()) {
      Get.delete<EditProfileController>();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Obx(() {
          final user = _controller.user.value;
          final isLoading = _controller.isLoading.value && user == null;

          return Column(
            children: [
              _TopBar(isSaving: _controller.isSaving.value),
              if (isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    child: Column(
                      children: [
                        _VerificationCard(controller: _controller),
                        const SizedBox(height: 12),
                        SettingsSectionCard(
                          title: 'Basic Info',
                          subtitle:
                              'Update the public identity details shown on your profile.',
                          children: [
                            Obx(
                              () => _FormField(
                                label: 'Username',
                                controller: _controller.usernameController,
                                textInputAction: TextInputAction.next,
                                onChanged: _controller.onUsernameChanged,
                                helperText:
                                    _controller.usernameMessage.value
                                        .trim()
                                        .isEmpty
                                    ? null
                                    : _controller.usernameMessage.value,
                                helperColor:
                                    _controller.isUsernameAvailable.value
                                    ? AppColors.success
                                    : AppColors.error,
                                suffixIcon: _controller.isCheckingUsername.value
                                    ? const Padding(
                                        padding: EdgeInsets.all(14),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : _controller.isUsernameAvailable.value
                                    ? const AppHeroIconData(Icons.check_circle_rounded,
                                        color: AppColors.success,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            ),
                            _FormField(
                              label: 'Full Name',
                              controller: _controller.fullNameController,
                              textInputAction: TextInputAction.next,
                            ),
                            _FormField(
                              label: 'Display Name',
                              controller: _controller.displayNameController,
                              textInputAction: TextInputAction.next,
                            ),
                            _FormField(
                              label: 'Headline',
                              controller: _controller.headlineController,
                              textInputAction: TextInputAction.next,
                            ),
                            _FormField(
                              label: 'Bio',
                              controller: _controller.bioController,
                              maxLines: 4,
                              textInputAction: TextInputAction.newline,
                            ),
                            _FormField(
                              label: 'Website',
                              controller: _controller.websiteController,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SettingsSectionCard(
                          title: 'Location & Identity',
                          children: [
                            _FormField(
                              label: 'City',
                              controller: _controller.cityController,
                              textInputAction: TextInputAction.next,
                            ),
                            _FormField(
                              label: 'Country',
                              controller: _controller.countryController,
                              textInputAction: TextInputAction.next,
                            ),
                            _DropdownField(
                              label: 'Gender',
                              value: _controller.selectedGender.value,
                              items: const <String>['male', 'female', 'other'],
                              onChanged: (value) =>
                                  _controller.selectedGender.value = value,
                            ),
                            _FormField(
                              label: 'Birth Date',
                              controller: _controller.birthDateController,
                              readOnly: true,
                              onTap: () => _controller.pickBirthDate(context),
                              suffixIcon: const AppHeroIconData(Icons.chevron_right_rounded,
                                color: AppColors.hintText,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SettingsSectionCard(
                          title: 'Privacy & Contact',
                          children: [
                            _DropdownField(
                              label: 'Visibility',
                              value: _controller.selectedVisibility.value,
                              items: const <String>['public', 'private'],
                              onChanged: (value) =>
                                  _controller.selectedVisibility.value = value,
                            ),
                            _SwitchField(
                              label: 'Private Account',
                              value: _controller.isPrivate.value,
                              onChanged: (value) =>
                                  _controller.isPrivate.value = value,
                            ),
                            _FormField(
                              label: 'Phone Country Code',
                              controller:
                                  _controller.phoneCountryCodeController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                            ),
                            _FormField(
                              label: 'Phone Number',
                              controller: _controller.phoneNumberController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                            ),
                            _FormField(
                              label: 'Timezone',
                              controller: _controller.timezoneController,
                              textInputAction: TextInputAction.done,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
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
                              onPressed: _controller.isSaving.value
                                  ? null
                                  : _controller.saveProfile,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                disabledBackgroundColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 15,
                                ),
                              ),
                              child: _controller.isSaving.value
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Save Changes',
                                      style: AppFonts.beVietnam(
                                        size: 15,
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
          );
        }),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.isSaving});

  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: isSaving ? null : Get.back,
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
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ).createShader(bounds);
                },
                child: Text(
                  'Edit Profile',
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
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.controller});

  final EditProfileController controller;

  @override
  Widget build(BuildContext context) {
    final user = controller.user.value;
    final isVerified = user?.isVerifiedBadge == true;
    final canRequest = user?.canRequestVerification == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
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
                  color: const Color(0xFFF8E8E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const AppHeroIconData(Icons.verified_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verification Badge',
                  style: AppFonts.plusJakarta(
                    size: 18,
                    weight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isVerified
                ? 'Your profile is already verified.'
                : canRequest
                ? 'Your email or phone is verified. You can claim your verification badge now.'
                : 'Verify your email or phone first, then come back here to claim the badge.',
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w500,
              color: AppColors.hintText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isVerified || controller.isVerifying.value
                  ? null
                  : controller.requestVerificationBadge,
              style: ElevatedButton.styleFrom(
                backgroundColor: isVerified
                    ? const Color(0xFFE8F7EE)
                    : AppColors.text,
                disabledBackgroundColor: isVerified
                    ? const Color(0xFFE8F7EE)
                    : const Color(0xFFCCC7C6),
                foregroundColor: isVerified ? AppColors.success : Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: controller.isVerifying.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isVerified
                          ? 'Verified Badge Active'
                          : 'Get Verification Badge',
                      style: AppFonts.beVietnam(
                        size: 14,
                        weight: FontWeight.w700,
                        color: isVerified ? AppColors.success : Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.suffixIcon,
    this.helperText,
    this.helperColor,
  });

  final String label;
  final TextEditingController controller;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Widget? suffixIcon;
  final String? helperText;
  final Color? helperColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label.toUpperCase(),
              style: AppFonts.beVietnam(
                size: 10,
                weight: FontWeight.w700,
                color: AppColors.hintText,
                letterSpacing: 1.0,
              ),
            ),
          ),
          TextField(
            controller: controller,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w600,
              color: AppColors.text,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF3F0EF),
              suffixIcon: suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.24),
                  width: 1.2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
          if (helperText != null && helperText!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                helperText!,
                style: AppFonts.beVietnam(
                  size: 11,
                  weight: FontWeight.w600,
                  color: helperColor ?? AppColors.hintText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = value.trim();
    final dropdownValue = items.contains(normalizedValue)
        ? normalizedValue
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              label.toUpperCase(),
              style: AppFonts.beVietnam(
                size: 10,
                weight: FontWeight.w700,
                color: AppColors.hintText,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0EF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: dropdownValue,
                isExpanded: true,
                hint: Text(
                  'Select $label',
                  style: AppFonts.beVietnam(
                    size: 14,
                    weight: FontWeight.w500,
                    color: AppColors.hintText,
                  ),
                ),
                items: items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(
                          item,
                          style: AppFonts.beVietnam(
                            size: 14,
                            weight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    onChanged(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchField extends StatelessWidget {
  const _SwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppFonts.beVietnam(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.text,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
