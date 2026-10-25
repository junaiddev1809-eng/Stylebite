import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import 'chat_reaction_picker_sheet.dart';

enum ChatMessageOptionAction { report, react, moreEmojis }

class ChatMessageOptionsResult {
  const ChatMessageOptionsResult({
    required this.action,
    this.emoji = '',
  });

  final ChatMessageOptionAction action;
  final String emoji;
}

Future<ChatMessageOptionsResult?> showChatMessageOptionsSheet(
  BuildContext context, {
  bool canReport = true,
  String currentReaction = '',
}) {
  return showModalBottomSheet<ChatMessageOptionsResult>(
    context: context,
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
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'React',
                  style: AppFonts.plusJakarta(
                    size: 15,
                    weight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kChatQuickReactions.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == kChatQuickReactions.length) {
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(
                          const ChatMessageOptionsResult(
                            action: ChatMessageOptionAction.moreEmojis,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F1F0),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.add_reaction_outlined,
                            color: AppColors.hintText,
                          ),
                        ),
                      );
                    }
                    final emoji = kChatQuickReactions[index];
                    final selected = currentReaction == emoji;
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(
                        ChatMessageOptionsResult(
                          action: ChatMessageOptionAction.react,
                          emoji: emoji,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.14)
                              : const Color(0xFFF4F1F0),
                          borderRadius: BorderRadius.circular(14),
                          border: selected
                              ? Border.all(color: AppColors.primary)
                              : null,
                        ),
                        child: Text(emoji, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  },
                ),
              ),
              if (canReport) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => Navigator.of(context).pop(
                    const ChatMessageOptionsResult(
                      action: ChatMessageOptionAction.report,
                    ),
                  ),
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
            ],
          ),
        ),
      );
    },
  );
}
