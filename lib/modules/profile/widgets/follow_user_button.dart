import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../controllers/follow_state_controller.dart';

class FollowUserButton extends StatefulWidget {
  const FollowUserButton({
    super.key,
    required this.username,
    required this.initialIsFollowing,
    this.compact = false,
    this.dark = false,
    this.expand = false,
    this.height,
  });

  final String username;
  final bool initialIsFollowing;
  final bool compact;
  final bool dark;
  final bool expand;
  final double? height;

  @override
  State<FollowUserButton> createState() => _FollowUserButtonState();
}

class _FollowUserButtonState extends State<FollowUserButton> {
  late final FollowStateController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<FollowStateController>()
        ? Get.find<FollowStateController>()
        : Get.put(FollowStateController(), permanent: true);
    _seed();
  }

  @override
  void didUpdateWidget(covariant FollowUserButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.username != widget.username ||
        oldWidget.initialIsFollowing != widget.initialIsFollowing) {
      _seed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedUsername = _normalize(widget.username);
    final currentUsername = LocalStorage.getUsername();

    if (normalizedUsername.isEmpty ||
        (currentUsername != null && normalizedUsername == currentUsername)) {
      return const SizedBox.shrink();
    }

    return Obx(() {
      final isFollowing = _controller.isFollowing(
        normalizedUsername,
        fallback: widget.initialIsFollowing,
      );
      final isLoading = _controller.isLoading(normalizedUsername);

      final background = widget.dark
          ? (isFollowing ? Colors.white.withValues(alpha: 0.12) : Colors.white)
          : (isFollowing ? const Color(0xFFE9E3E1) : AppColors.text);
      final foreground = widget.dark
          ? (isFollowing ? Colors.white : AppColors.text)
          : (isFollowing ? AppColors.text : Colors.white);

      return GestureDetector(
        onTap: isLoading
            ? null
            : () async {
                try {
                  await _controller.toggleFollow(
                    normalizedUsername,
                    currentlyFollowing: isFollowing,
                  );
                } catch (error) {
                  errorSnackBar(
                    message: error.toString().replaceFirst('Exception: ', ''),
                  );
                }
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: widget.expand ? double.infinity : null,
          height: widget.height,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 12 : 14,
            vertical: widget.compact ? 7 : 8,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.dark
                  ? Colors.white.withValues(alpha: isFollowing ? 0.18 : 0)
                  : (isFollowing ? const Color(0xFFD8CFCC) : AppColors.text),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  width: widget.compact ? 14 : 16,
                  height: widget.compact ? 14 : 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(foreground),
                  ),
                )
              : Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: AppFonts.beVietnam(
                    size: widget.compact ? 11 : 12,
                    weight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
        ),
      );
    });
  }

  void _seed() {
    final normalizedUsername = _normalize(widget.username);
    if (normalizedUsername.isEmpty) {
      return;
    }
    _controller.seed(normalizedUsername, widget.initialIsFollowing);
  }

  String _normalize(String username) => username.trim().replaceFirst('@', '');
}
