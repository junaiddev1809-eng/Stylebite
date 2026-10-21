import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../controllers/blocked_users_controller.dart';
import '../models/blocked_user_model.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final BlockedUsersController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<BlockedUsersController>()
        ? Get.find<BlockedUsersController>()
        : Get.put(BlockedUsersController());
  }

  @override
  Widget build(BuildContext context) {
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
                      child: HeroIcon(
                        HeroIcons.arrowLeft,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Blocked Accounts',
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
              child: Obx(() {
                if (_controller.isInitialLoading.value &&
                    _controller.users.isEmpty) {
                  return const _BlockedUsersShimmer();
                }

                if (_controller.hasError.value && _controller.users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyBlockedState(
                        title: 'Could not load blocked users',
                        subtitle: _controller.errorMessage.value,
                      ),
                    ),
                  );
                }

                if (_controller.users.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyBlockedState(
                        title: 'No blocked accounts',
                        subtitle:
                            'People you block will appear here for quick review.',
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _controller.refreshBlockedUsers,
                  child: ListView.builder(
                    controller: _controller.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: _controller.users.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _controller.users.length) {
                        if (_controller.isLoadingMore.value) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (!_controller.hasMore.value) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                'No more data',
                                style: AppFonts.beVietnam(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: AppColors.hintText,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _controller.users.length - 1
                              ? 0
                              : 10,
                        ),
                        child: _BlockedUserCard(
                          user: _controller.users[index],
                          onTap: () {
                            final username = _controller.users[index].username
                                .trim()
                                .replaceFirst('@', '');
                            if (username.isEmpty) {
                              errorSnackBar(
                                message:
                                    'This profile username is unavailable.',
                              );
                              return;
                            }
                            ProfileOpenHelper.open(username: username);
                          },
                          onToggleBlock: () => _controller.toggleBlockedUser(
                            _controller.users[index],
                          ),
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockedUserCard extends StatelessWidget {
  const _BlockedUserCard({
    required this.user,
    required this.onTap,
    required this.onToggleBlock,
  });

  final BlockedUserModel user;
  final VoidCallback onTap;
  final VoidCallback onToggleBlock;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(47, 47, 46, 0.06),
                blurRadius: 18,
                offset: Offset(0, 8),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: user.avatarUrl.trim().isEmpty
                      ? Container(
                          color: const Color(0xFFF3F0EF),
                          alignment: Alignment.center,
                          child: const HeroIcon(
                            HeroIcons.user,
                            color: AppColors.hintText,
                          ),
                        )
                      : AppCachedImage(imageUrl: user.avatarUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppVerifiedName(
                      name: user.title,
                      username: user.username,
                      isVerified: user.isVerifiedBadge,
                      badgeSize: 15,
                      style: AppFonts.plusJakarta(
                        size: 15,
                        weight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    if (user.bio.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.beVietnam(
                          size: 12,
                          weight: FontWeight.w500,
                          color: AppColors.hintText,
                        ),
                      ),
                    ] else if (user.locationLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        user.locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.beVietnam(
                          size: 12,
                          weight: FontWeight.w500,
                          color: AppColors.hintText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: onToggleBlock,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Unblock',
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w700,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBlockedState extends StatelessWidget {
  const _EmptyBlockedState({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const HeroIcon(HeroIcons.noSymbol, color: Colors.redAccent),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.plusJakarta(
              size: 17,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w500,
              color: AppColors.hintText,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockedUsersShimmer extends StatelessWidget {
  const _BlockedUsersShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              AppShimmerBox(
                width: 56,
                height: 56,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmerBox(
                      width: 120,
                      height: 15,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    SizedBox(height: 6),
                    AppShimmerBox(
                      width: 92,
                      height: 12,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    SizedBox(height: 8),
                    AppShimmerBox(
                      height: 12,
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              AppShimmerBox(
                width: 68,
                height: 28,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ],
          ),
        );
      },
    );
  }
}
