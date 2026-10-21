import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

enum ChatMessageOptionAction { report }

Future<ChatMessageOptionAction?> showChatMessageOptionsSheet(
  BuildContext context,
) {
  return showModalBottomSheet<ChatMessageOptionAction>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7E2E0),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: () => Navigator.of(
                  context,
                ).pop(ChatMessageOptionAction.report),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F1F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const HeroIcon(
                        HeroIcons.flag,
                        color: AppColors.hintText,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Report Message',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.hintText,
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
    },
  );
}
