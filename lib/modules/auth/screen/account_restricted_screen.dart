import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_primary_button.dart';

class AccountRestrictedScreen extends StatelessWidget {
  const AccountRestrictedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>? ?? const {};
    final code = (args['code'] as String?) ?? 'account_banned';
    final message = (args['message'] as String?)?.trim();
    final reason = (args['reason'] as String?)?.trim();
    final suspendedUntil = args['suspendedUntil'] as DateTime?;

    final isSuspended = code == 'account_suspended';
    final title = switch (code) {
      'account_suspended' => 'Account Suspended',
      'account_inactive' => 'Account Inactive',
      _ => 'Account Banned',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.block_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppFonts.plusJakarta(
                  size: 24,
                  weight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                (message?.isNotEmpty ?? false)
                    ? message!
                    : 'Your account access has been restricted.',
                textAlign: TextAlign.center,
                style: AppFonts.beVietnam(
                  size: 15,
                  weight: FontWeight.w500,
                  height: 1.45,
                  color: AppColors.hintText,
                ),
              ),
              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: AppFonts.beVietnam(
                      size: 13.5,
                      weight: FontWeight.w500,
                      color: AppColors.text,
                    ),
                  ),
                ),
              ],
              if (isSuspended && suspendedUntil != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Suspended until ${_formatDate(suspendedUntil)}',
                  textAlign: TextAlign.center,
                  style: AppFonts.beVietnam(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ],
              const SizedBox(height: 32),
              AppPrimaryButton(
                label: 'Back to Login',
                onPressed: () => Get.offAllNamed(AppRoutes.login),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} at $hour:$minute';
  }
}
