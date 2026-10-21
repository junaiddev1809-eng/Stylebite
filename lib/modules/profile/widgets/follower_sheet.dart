import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../controllers/follower_sheet_controller.dart';
import '../models/follower_model.dart';
import '../utils/profile_open_helper.dart';

class FollowerSheet extends StatelessWidget {
  const FollowerSheet({
    super.key,
    required this.username,
    required this.isFollowers,
    required this.title,
  });

  final String username;
  final bool isFollowers;
  final String title;

  @override
  Widget build(BuildContext context) {
    final tag = '${username}_${isFollowers ? 'followers' : 'following'}';
    if (Get.isRegistered<FollowerSheetController>(tag: tag)) {
      Get.delete<FollowerSheetController>(tag: tag);
    }
    final controller = Get.put(
      FollowerSheetController(username: username, isFollowers: isFollowers),
      tag: tag,
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.hintText.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppFonts.plusJakarta(
              size: 18,
              weight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (controller.hasError.value) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      controller.errorMessage.value,
                      textAlign: TextAlign.center,
                      style: AppFonts.beVietnam(color: AppColors.hintText),
                    ),
                  ),
                );
              }

              if (controller.users.isEmpty) {
                return Center(
                  child: Text(
                    isFollowers ? 'No followers found' : 'No following found',
                    style: AppFonts.beVietnam(color: AppColors.hintText),
                  ),
                );
              }

              return ListView.separated(
                controller: controller.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: controller.users.length + (controller.isLoadingMore.value ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index == controller.users.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  }

                  final user = controller.users[index];
                  return _UserTile(
                    user: user,
                    onToggleFollow: () => controller.toggleFollow(user),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.onToggleFollow});

  final FollowerModel user;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    String buttonText = 'Follow';
    bool isFollowing = user.isFollowing;
    
    if (isFollowing) {
      buttonText = 'Following';
    } else if (user.followsYou) {
      buttonText = 'Follow Back';
    }

    return InkWell(
      onTap: () {
        Get.back();
        ProfileOpenHelper.open(
          username: user.username,
          initialIsFollowing: user.isFollowing,
          avatarUrl: user.avatarUrl,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            AppCachedImage(
              imageUrl: user.avatarUrl,
              width: 48,
              height: 48,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppVerifiedName(
                    name: user.displayName.isNotEmpty
                        ? user.displayName
                        : user.username,
                    username: user.username,
                    isVerified: user.isVerified,
                    badgeSize: 15,
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: FontWeight.w500,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ),
            if (!user.isSelf)
              GestureDetector(
                onTap: onToggleFollow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFollowing ? const Color(0xFFF3F0EF) : AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    buttonText,
                    style: AppFonts.beVietnam(
                      size: 12,
                      weight: FontWeight.w700,
                      color: isFollowing ? AppColors.text : Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
