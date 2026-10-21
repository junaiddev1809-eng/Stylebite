import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

enum ChatConversationOptionAction { toggleMessaging, toggleBlock }

Future<ChatConversationOptionAction?> showChatConversationOptionsSheet(
  BuildContext context, {
  required bool isMessagingStopped,
  required bool isBlocked,
  required bool isBlockedByMe,
}) {
  return showModalBottomSheet<ChatConversationOptionAction>(
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
              // Stop/resume chat is a distinct feature from blocking —
              // meaningless once the conversation is actually blocked,
              // so it's hidden rather than offering a "Resume Chat" that
              // doesn't undo a block.
              if (!isBlocked) ...[
                _item(
                  icon: isMessagingStopped
                      ? HeroIcons.playCircle
                      : HeroIcons.pauseCircle,
                  label: isMessagingStopped ? 'Resume Chat' : 'Stop Chat',
                  color: isMessagingStopped
                      ? const Color(0xFF16A34A)
                      : AppColors.text,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(ChatConversationOptionAction.toggleMessaging),
                ),
                const SizedBox(height: 8),
              ],
              _item(
                icon: HeroIcons.noSymbol,
                label: isBlockedByMe ? 'Unblock User' : 'Block User',
                color: Colors.redAccent,
                onTap: () => Navigator.of(
                  context,
                ).pop(ChatConversationOptionAction.toggleBlock),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _item({
  required HeroIcons icon,
  required String label,
  Color color = AppColors.text,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1F0),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          HeroIcon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}
