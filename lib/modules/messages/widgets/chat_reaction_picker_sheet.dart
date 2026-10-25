import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

const List<String> kChatQuickReactions = [
  '❤️',
  '😂',
  '😮',
  '😢',
  '😡',
  '👍',
  '🔥',
  '😍',
  '👏',
  '🎉',
];

const List<String> kChatMoreReactions = [
  '❤️',
  '🧡',
  '💛',
  '💚',
  '💙',
  '💜',
  '🖤',
  '🤍',
  '💔',
  '❣️',
  '💕',
  '💞',
  '😁',
  '😂',
  '🤣',
  '😊',
  '😍',
  '😘',
  '😜',
  '🤔',
  '😮',
  '😢',
  '😭',
  '😡',
  '🤯',
  '😴',
  '👍',
  '👎',
  '👏',
  '🙌',
  '🤝',
  '🙏',
  '🔥',
  '✨',
  '⭐',
  '💯',
  '🎉',
  '🥳',
  '😎',
  '🤩',
  '😇',
  '🤗',
  '🫡',
  '💪',
  '👀',
  '🥰',
  '😏',
  '🫠',
];

Future<String?> showChatReactionPickerSheet(
  BuildContext context, {
  String currentReaction = '',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E2E0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'React',
                style: AppFonts.plusJakarta(
                  size: 16,
                  weight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final emoji in kChatMoreReactions)
                    InkWell(
                      onTap: () => Navigator.of(context).pop(emoji),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: currentReaction == emoji
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : const Color(0xFFF4F1F0),
                          borderRadius: BorderRadius.circular(12),
                          border: currentReaction == emoji
                              ? Border.all(color: AppColors.primary)
                              : null,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                ],
              ),
              if (currentReaction.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(currentReaction),
                  child: Text(
                    'Remove $currentReaction',
                    style: AppFonts.beVietnam(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
