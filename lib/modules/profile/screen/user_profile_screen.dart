import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/tappable_profile_avatar.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../reports/widgets/report_reason_sheet.dart';
import '../controllers/user_profile_controller.dart';
import '../models/profile_model.dart';
import '../utils/profile_posts_feed_opener.dart';
import '../widgets/follow_user_button.dart';
import '../widgets/profile_food_cards.dart';
import '../widgets/profile_outfit_grid.dart';
import '../widgets/profile_tab_buttons.dart';
import '../widgets/follower_sheet.dart';
import '../widgets/style_rating_sheet.dart';
import '../../story/story_marker.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.username,
    this.initialIsFollowing = false,
  });

  final String username;
  final bool initialIsFollowing;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late final UserProfileController _controller;
  late final String _tag;

  @override
  void initState() {
    super.initState();
    _tag =
        'user-profile-${widget.username}-${DateTime.now().microsecondsSinceEpoch}';
    _controller = Get.put(
      UserProfileController(
        username: widget.username,
        initialIsFollowing: widget.initialIsFollowing,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<UserProfileController>(tag: _tag)) {
      Get.delete<UserProfileController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EFEF),
      body: Obx(() {
        if (_controller.isInitialLoading.value &&
            _controller.user.value == null) {
          return const _UserProfileShimmer();
        }

        if (_controller.hasError.value && _controller.user.value == null) {
          return AppErrorState(
            message: _controller.errorMessage.value.isEmpty
                ? 'Unable to load profile right now.'
                : _controller.errorMessage.value,
            onRetry: _controller.refreshProfileOverview,
          );
        }

        final user = _controller.user.value;
        if (user == null) {
          return const AppEmptyState(
            title: 'Profile unavailable',
            subtitle: 'We could not find this profile right now.',
            icon: Icons.person_search_rounded,
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _controller.refreshProfileOverview,
          child: SafeArea(
            child: SingleChildScrollView(
              controller: _controller.detailScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _PublicTopBar(controller: _controller),
                  const SizedBox(height: 18),
                  _PublicHeaderSection(
                    controller: _controller,
                    onTapFollowers: () => _openFollowersSheet(true, 'Followers'),
                    onTapFollowing: () => _openFollowersSheet(false, 'Following'),
                    onTapStylePoints: _openStyleRatingSheet,
                  ),
                  const SizedBox(height: 18),
                  _PublicAchievementSection(controller: _controller),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.hintText.withValues(alpha: 0.16),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: ProfileTabButtons(
                              activeTab: _controller.activeTab.value,
                              onTabChanged: _controller.setTab,
                              showSavedTab: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PublicTabContent(controller: _controller),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  void _openFollowersSheet(bool isFollowers, String title) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FollowerSheet(
        username: widget.username,
        isFollowers: isFollowers,
        title: title,
      ),
    );
  }

  void _openStyleRatingSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StyleRatingSheet(username: widget.username),
    );
  }
}

class _PublicTopBar extends StatelessWidget {
  const _PublicTopBar({required this.controller});

  final UserProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: AppBackNavigation.handleBack,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: AppHeroIconData(Icons.arrow_back_rounded,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            controller.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppFonts.plusJakarta(
              size: 22,
              weight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        InkWell(
          onTap: () => _shareProfile(controller.username),
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: AppHeroIconData(Icons.share_outlined,
              color: AppColors.hintText,
            ),
          ),
        ),
        if (!(controller.user.value?.isSelf ?? true)) ...[
          const SizedBox(width: 12),
          InkWell(
            onTap: () => _reportUser(context, controller),
            borderRadius: BorderRadius.circular(999),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: AppHeroIconData(Icons.flag_outlined,
                color: AppColors.hintText,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> _reportUser(
  BuildContext context,
  UserProfileController controller,
) async {
  final result = await showReportReasonSheet(context, title: 'Report user');
  if (result != null) {
    await controller.reportUser(result.reasonCode, result.details);
  }
}

class _PublicHeaderSection extends StatelessWidget {
  const _PublicHeaderSection({
    required this.controller,
    required this.onTapFollowers,
    required this.onTapFollowing,
    required this.onTapStylePoints,
  });

  final UserProfileController controller;
  final VoidCallback onTapFollowers;
  final VoidCallback onTapFollowing;
  final VoidCallback onTapStylePoints;

  @override
  Widget build(BuildContext context) {
    final user = controller.user.value!;
    return Column(
      children: [
        TappableProfileAvatar(
          imageUrl: user.avatarUrl,
          heroTag: 'profile-avatar-${user.username}',
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                controller.displayName,
                textAlign: TextAlign.center,
                style: AppFonts.plusJakarta(
                  size: 37 / 1.4,
                  weight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
            ),
            VerifiedBadgeSlot(
              username: user.username,
              fallback: user.isVerifiedBadge,
              size: 18,
              spacing: 6,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (user.locationLabel.trim().isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppHeroIconData(Icons.location_on_outlined,
                size: 14,
                color: AppColors.hintText,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  user.locationLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.beVietnam(
                    size: 12,
                    weight: FontWeight.w600,
                    color: AppColors.hintText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        if (!user.isSelf)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330),
            child: Row(
              children: [
                Expanded(
                  child: FollowUserButton(
                    username: user.username,
                    initialIsFollowing: user.isFollowing,
                    expand: true,
                    height: 44,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(
                    () => SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: controller.isOpeningChat.value
                            ? null
                            : controller.openChat,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: const Color(0xFFECE7E5),
                          foregroundColor: AppColors.text,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        icon: controller.isOpeningChat.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const AppHeroIconData(Icons.chat_bubble_outline_rounded,
                                size: 18,
                                color: AppColors.text,
                              ),
                        label: Text(
                          _chatButtonLabel(controller),
                          style: AppFonts.beVietnam(
                            size: 13,
                            weight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        _PublicStatsRow(
          controller: controller,
          onTapFollowers: onTapFollowers,
          onTapFollowing: onTapFollowing,
          onTapStylePoints: onTapStylePoints,
        ),
        if (controller.profileSummary.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: 320,
            child: Text(
              controller.profileSummary,
              textAlign: TextAlign.center,
              style: AppFonts.beVietnam(
                size: 14,
                weight: FontWeight.w500,
                color: AppColors.text,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _chatButtonLabel(UserProfileController controller) {
    if (controller.isChatStatusLoading.value) {
      return 'Chat';
    }

    final isOnline = controller.isUserOnline.value;
    if (isOnline == true) {
      return 'Chat • Online';
    }
    if (isOnline == false) {
      return 'Chat • Offline';
    }
    return 'Chat';
  }
}

Future<void> _shareProfile(String username) async {
  final normalized = username.trim().replaceFirst('@', '');
  if (normalized.isEmpty) {
    return;
  }

  final profileLink = 'https://stylebiteapp.com/profile/${Uri.encodeComponent(normalized)}';
  await SharePlus.instance.share(
    ShareParams(text: 'Check out @$normalized on StyleBite\n$profileLink'),
  );
}

class _PublicStatsRow extends StatelessWidget {
  const _PublicStatsRow({
    required this.controller,
    required this.onTapFollowers,
    required this.onTapFollowing,
    required this.onTapStylePoints,
  });

  final UserProfileController controller;
  final VoidCallback onTapFollowers;
  final VoidCallback onTapFollowing;
  final VoidCallback onTapStylePoints;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PublicStatItem(
          value: controller.vibeCountLabel,
          label: 'Vibe Count',
          onTap: onTapFollowers,
        ),
        const SizedBox(width: 30),
        _PublicStatItem(
          value: controller.vibeFlowLabel,
          label: 'Vibe Flow',
          onTap: onTapFollowing,
        ),
        const SizedBox(width: 30),
        _PublicStatItem(
          value: controller.stylePointsLabel,
          label: 'Style Points',
          highlight: true,
          onTap: onTapStylePoints,
        ),
      ],
    );
  }
}

class _PublicStatItem extends StatelessWidget {
  const _PublicStatItem({
    required this.value,
    required this.label,
    this.highlight = false,
    this.onTap,
  });

  final String value;
  final String label;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          children: [
            Text(
              value,
              style: AppFonts.plusJakarta(
                size: 22,
                weight: FontWeight.w700,
                color: highlight ? AppColors.primary : AppColors.text,
              ),
            ),
            Text(
              label,
              style: AppFonts.beVietnam(
                size: 11,
                weight: FontWeight.w600,
                color: AppColors.hintText,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PublicAchievementSection extends StatelessWidget {
  const _PublicAchievementSection({required this.controller});

  final UserProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = controller.user.value;
      if (user == null) return const SizedBox.shrink();

      final streakDays = user.currentStreakDays;
      final streakValue = streakDays > 0 ? '$streakDays Days' : '0 Days';
      final streakSubtitle = (user.currentStreakLabel).trim().isNotEmpty
          ? user.currentStreakLabel
          : 'KEEP THE STREAK ALIVE';
      final contestWins = user.contestWins;
      final contestEntries = user.contestEntries;
      final contestValue = contestEntries > 0
          ? '$contestWins / $contestEntries'
          : '$contestWins';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E6E7),
          borderRadius: BorderRadius.circular(22),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT STREAK',
                      style: AppFonts.beVietnam(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppColors.hintText,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      streakValue,
                      style: AppFonts.plusJakarta(
                        size: 20,
                        weight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: AppColors.primary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            streakSubtitle.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.beVietnam(
                              size: 9,
                              weight: FontWeight.w700,
                              color: AppColors.hintText,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              VerticalDivider(
                width: 32,
                thickness: 1,
                color: AppColors.hintText.withValues(alpha: 0.16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTEST WINS',
                      style: AppFonts.beVietnam(
                        size: 11,
                        weight: FontWeight.w700,
                        color: AppColors.hintText,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "$contestValue Wins",
                      style: AppFonts.plusJakarta(
                        size: 20,
                        weight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const AppHeroIconData(
                          HeroIcons.bolt,
                          color: AppColors.text,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'KEEP WINNING',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.beVietnam(
                              size: 9,
                              weight: FontWeight.w700,
                              color: AppColors.hintText,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _PublicTabContent extends StatelessWidget {
  const _PublicTabContent({required this.controller});

  final UserProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return _buildTab();
    });
  }

  Widget _buildTab() {
    switch (controller.activeTab.value) {
      case ProfileContentTab.outfits:
        if (controller.outfitPosts.isEmpty) {
          if (controller.isLoadingMoreOutfits.value) {
            return const _PublicTabLoading();
          }
          return const _PublicEmptyState(
            title: 'No outfit posts yet',
            subtitle: 'This user has not posted any outfit content yet.',
            icon: Icons.photo_library_outlined,
          );
        }
        // Filter posts first, then derive images from that same list —
        // deriving images and filtering separately let the two lists drift
        // out of sync, so tapping tile N could open the wrong post once any
        // earlier post had no displayable image.
        final visibleOutfitPosts = controller.outfitPosts
            .where((post) => post.gridImageUrl.trim().isNotEmpty)
            .where(
              (post) =>
                  !StoryMarker.isStory(tags: post.tags, caption: post.caption),
            )
            .toList(growable: false);
        final images = visibleOutfitPosts
            .map((post) => post.gridImageUrl)
            .toList(growable: false);
        final carousel = visibleOutfitPosts
            .map((post) => post.isCarousel)
            .toList(growable: false);
        return Column(
          children: [
            ProfileOutfitGrid(
              images: images,
              carousel: carousel,
              onTapImage: (index) =>
                  _openProfilePost(visibleOutfitPosts[index]),
            ),
            _PublicPaginationFooter(
              isLoading: controller.isLoadingMoreOutfits.value,
              hasMore: controller.hasMoreOutfits,
            ),
          ],
        );
      case ProfileContentTab.saved:
        if (controller.savedPosts.isEmpty) {
          if (controller.isLoadingMoreSaved.value) {
            return const _PublicTabLoading();
          }
          return const _PublicEmptyState(
            title: 'No saved looks visible',
            subtitle: 'There are no saved looks available on this profile.',
            icon: Icons.bookmark_border_rounded,
          );
        }
        final images = controller.savedPosts
            .map((item) => item.imageUrl)
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false);
        return Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: images.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 4,
              ),
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () =>
                      _openProfilePost(controller.savedPosts[index].post),
                  borderRadius: BorderRadius.circular(14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(images[index], fit: BoxFit.cover),
                  ),
                );
              },
            ),
            _PublicPaginationFooter(
              isLoading: controller.isLoadingMoreSaved.value,
              hasMore: controller.hasMoreSaved,
            ),
          ],
        );
      case ProfileContentTab.food:
        if (controller.foodPosts.isEmpty) {
          if (controller.isLoadingMoreFood.value) {
            return const _PublicTabLoading();
          }
          return const _PublicEmptyState(
            title: 'No food posts yet',
            subtitle: 'This user has not shared any food reviews yet.',
            icon: Icons.restaurant_rounded,
          );
        }
        return Column(
          children: [
            ProfileFoodCards(
              items: controller.foodPosts,
              onTapItem: _openProfilePost,
            ),
            _PublicPaginationFooter(
              isLoading: controller.isLoadingMoreFood.value,
              hasMore: controller.hasMoreFood,
            ),
          ],
        );
      case ProfileContentTab.more:
        return const _PublicEmptyState(
          title: 'No contest media visible',
          subtitle: 'Contest submissions are not available for this profile.',
          icon: Icons.emoji_events_outlined,
        );
    }
  }

  void _openProfilePost(ProfilePostModel post) {
    final user = controller.user.value;
    if (user == null) {
      return;
    }

    ProfilePostsFeedOpener.open(
      selected: post,
      tabPosts: _postsForActiveTab(),
      user: user,
      tab: controller.activeTab.value,
      isOwnProfile: user.isSelf,
      currentPage: controller.activeTabCurrentPage,
      hasMore: controller.activeTabHasMore,
    );
  }

  List<ProfilePostModel> _postsForActiveTab() {
    switch (controller.activeTab.value) {
      case ProfileContentTab.outfits:
        return controller.outfitPosts
            .where((item) => item.gridImageUrl.trim().isNotEmpty)
            .toList(growable: false);
      case ProfileContentTab.food:
        return controller.foodPosts.toList(growable: false);
      case ProfileContentTab.saved:
        return controller.savedPosts
            .map((item) => item.post)
            .toList(growable: false);
      case ProfileContentTab.more:
        return const <ProfilePostModel>[];
    }
  }
}

class _PublicPaginationFooter extends StatelessWidget {
  const _PublicPaginationFooter({
    required this.isLoading,
    required this.hasMore,
  });

  final bool isLoading;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'No more data',
          style: AppFonts.beVietnam(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.hintText,
          ),
        ),
      );
    }
    return const SizedBox(height: 8);
  }
}

class _PublicTabLoading extends StatelessWidget {
  const _PublicTabLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PublicEmptyState extends StatelessWidget {
  const _PublicEmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: AppEmptyState(title: title, subtitle: subtitle, icon: icon),
    );
  }
}

class _UserProfileShimmer extends StatelessWidget {
  const _UserProfileShimmer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: const [
                AppShimmerBox(
                  width: 26,
                  height: 26,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                SizedBox(width: 10),
                AppShimmerBox(
                  width: 140,
                  height: 24,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const AppShimmerBox(
              width: 96,
              height: 96,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            const SizedBox(height: 16),
            const AppShimmerBox(
              width: 180,
              height: 24,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            const SizedBox(height: 12),
            const AppShimmerBox(
              width: 120,
              height: 38,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppShimmerBox(width: 64, height: 36),
                SizedBox(width: 18),
                AppShimmerBox(width: 64, height: 36),
                SizedBox(width: 18),
                AppShimmerBox(width: 64, height: 36),
              ],
            ),
            const SizedBox(height: 14),
            const AppShimmerBox(
              width: double.infinity,
              height: 18,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            const SizedBox(height: 8),
            const AppShimmerBox(
              width: 260,
              height: 18,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            const SizedBox(height: 20),
            const AppShimmerBox(
              width: double.infinity,
              height: 144,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            const SizedBox(height: 12),
            const AppShimmerBox(
              width: double.infinity,
              height: 92,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            const SizedBox(height: 10),
            const AppShimmerBox(
              width: double.infinity,
              height: 92,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            const SizedBox(height: 18),
            Row(
              children: const [
                Expanded(child: AppShimmerBox(height: 34)),
                SizedBox(width: 10),
                AppShimmerBox(
                  width: 72,
                  height: 34,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 4,
              ),
              itemBuilder: (context, index) => const AppShimmerBox(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
