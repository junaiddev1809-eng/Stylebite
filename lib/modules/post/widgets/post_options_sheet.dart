import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

enum PostOptionAction { edit, delete, repost, block, report }

Future<PostOptionAction?> showPostOptionsSheet(
  BuildContext context, {
  required bool showOwnerOptions,
}) {
  return showModalBottomSheet<PostOptionAction>(
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
              if (showOwnerOptions) ...[
                _item(
                  icon: HeroIcons.pencilSquare,
                  label: 'Edit Post',
                  onTap: () => Navigator.of(context).pop(PostOptionAction.edit),
                ),
                const SizedBox(height: 8),
                _item(
                  icon: HeroIcons.arrowPathRoundedSquare,
                  label: 'Repost Post',
                  onTap: () =>
                      Navigator.of(context).pop(PostOptionAction.repost),
                ),
                const SizedBox(height: 8),
                _item(
                  icon: HeroIcons.trash,
                  label: 'Delete Post',
                  color: Colors.redAccent,
                  onTap: () =>
                      Navigator.of(context).pop(PostOptionAction.delete),
                ),
              ] else ...[
                _item(
                  icon: HeroIcons.flag,
                  label: 'Report Post',
                  color: AppColors.hintText,
                  onTap: () =>
                      Navigator.of(context).pop(PostOptionAction.report),
                ),
                const SizedBox(height: 8),
                _item(
                  icon: HeroIcons.noSymbol,
                  label: 'Block User',
                  color: Colors.redAccent,
                  onTap: () =>
                      Navigator.of(context).pop(PostOptionAction.block),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<bool?> showBlockUserConfirmationSheet(
  BuildContext context, {
  required String username,
}) {
  return showModalBottomSheet<bool>(
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
              const SizedBox(height: 18),
              Text(
                'Block $username?',
                style: AppFonts.plusJakarta(
                  size: 20,
                  weight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'They will no longer be able to interact with you normally.',
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.hintText,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: AppColors.hintText.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Block',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool?> showUnblockUserConfirmationSheet(
  BuildContext context, {
  required String username,
}) {
  return showModalBottomSheet<bool>(
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
              const SizedBox(height: 18),
              Text(
                'Unblock $username?',
                style: AppFonts.plusJakarta(
                  size: 20,
                  weight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'They will be able to message and interact with you again.',
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.hintText,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: AppColors.hintText.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Unblock',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool?> showDeletePostConfirmationSheet(BuildContext context) {
  return _showDeleteConfirmationSheet(
    context,
    title: 'Delete post?',
    subtitle: 'This action cannot be undone.',
  );
}

Future<bool?> showDeleteCommentConfirmationSheet(
  BuildContext context, {
  bool isReply = false,
}) {
  return _showDeleteConfirmationSheet(
    context,
    title: isReply ? 'Delete reply?' : 'Delete comment?',
    subtitle: 'This action cannot be undone.',
    useRootNavigator: true,
  );
}

Future<bool?> _showDeleteConfirmationSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  bool useRootNavigator = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    useRootNavigator: useRootNavigator,
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
              const SizedBox(height: 18),
              Text(
                title,
                style: AppFonts.plusJakarta(
                  size: 20,
                  weight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.hintText,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: AppColors.hintText.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'Delete',
                        style: AppFonts.beVietnam(
                          size: 14,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
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
