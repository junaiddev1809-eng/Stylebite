import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_sliding_toggle.dart';
import '../../profile/controllers/profile_controller.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../../core/utils/local_storage.dart';
import '../../profile/screen/profile_detail_screen.dart';
import '../../messages/controllers/chat_unread_controller.dart';
import '../../messages/screen/messages_screen.dart';
import '../../notifications/controllers/notifications_controller.dart';
import '../../notifications/screen/notifications_screen.dart';
import '../../post/screens/edit_post_screen.dart';
import '../../post/widgets/feed_post_card.dart';
import '../../search/screen/search_screen.dart';
import '../../story/controllers/story_controller.dart';
import '../../story/models/story_model.dart';
import '../../story/widgets/style_story_tray.dart';
import '../controllers/home_controller.dart';
import '../models/home_post_model.dart';
import 'suggested_reels_strip.dart';

class HomeFeedContent extends StatefulWidget {
  const HomeFeedContent({super.key});

  @override
  State<HomeFeedContent> createState() => _HomeFeedContentState();
}

class _HomeFeedContentState extends State<HomeFeedContent>
    with AutomaticKeepAliveClientMixin<HomeFeedContent> {
  late final HomeController _controller;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = HomeController.ensureController();
    StoryController.ensure();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Column(
        children: [
          _HomeTopBar(controller: _controller),
          Expanded(
            child: Obx(() {
              final _ = _controller.feedRevision.value;
              if (_controller.isInitialLoading.value) {
                return _loading();
              }

              final postCount = _controller.publishedCount;
              final rows = _controller.feedRows.toList(growable: false);

              return RefreshIndicator(
                onRefresh: _controller.refreshFeed,
                child: CustomScrollView(
                  controller: _controller.scrollController,
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: ClampingScrollPhysics(),
                  ),
                  key: const PageStorageKey<String>('home-feed-scroll'),
                  // Keep the card above and the card below built so scrolling
                  // back up does not recreate images and jump the layout.
                  // Video players still wait until a card is actually centered.
                  scrollCacheExtent: const ScrollCacheExtent.pixels(1400),
                  slivers: [
                    // Tabs - Always Visible with original UI
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 12),
                        child: _DiscoverToggle(controller: _controller),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: StyleStoryTray(
                          kind: _controller.selectedFeedType.value ==
                                  HomeFeedType.bite
                              ? StoryKind.food
                              : StoryKind.outfit,
                        ),
                      ),
                    ),

                    // Conditional Content
                    if (_controller.hasError.value)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppErrorState(
                          message:
                              'Could not load feed. Check your connection.',
                          onRetry: _controller.refreshFeed,
                        ),
                      )
                    else if (_controller.isLocationDenied.value)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          title: 'Location Required',
                          subtitle:
                              'Please enable location permission to discover nearby posts.',
                          icon: Icons.location_off_rounded,
                          actionLabel: 'Grant Permission',
                          onAction: _controller.retryLocationPermission,
                        ),
                      )
                    else if (postCount == 0)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          title:
                              'No posts in ${_controller.selectedDiscoverType.value.name.toLowerCase()}',
                          subtitle: 'Try switching to the other tab.',
                          icon: Icons.grid_view_rounded,
                          actionLabel: 'Refresh',
                          onAction: _controller.refreshFeed,
                        ),
                      )
                    else ...[
                      // Main Feed List
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final row = rows[index];
                              switch (row.kind) {
                                case HomeFeedRowKind.spinner:
                                  return const _LoadMoreSpinner();
                                case HomeFeedRowKind.suggestions:
                                  return SuggestedReelsStrip(
                                    reels: row.reels,
                                    feedType:
                                        _controller.selectedFeedType.value,
                                  );
                                case HomeFeedRowKind.post:
                                  final post = row.post!;
                                  return _HomeFeedItem(
                                    key: ValueKey('post-${post.id}'),
                                    controller: _controller,
                                    post: post,
                                  );
                              }
                            },
                            childCount: rows.length,
                            addAutomaticKeepAlives: false,
                          ),
                        ),
                      ),
                    ],

                    // Bottom Spacing
                    const SliverToBoxAdapter(child: SizedBox(height: 120)),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
      children: [
        const _DiscoverToggleShimmer(),
        const SizedBox(height: 8),
        StyleStoryTray(
          kind: _controller.selectedFeedType.value == HomeFeedType.bite
              ? StoryKind.food
              : StoryKind.outfit,
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 16),
        _FeedPostCardShimmer(
          isBiteFeed: _controller.selectedFeedType.value == HomeFeedType.bite,
        ),
        const SizedBox(height: 18),
        _FeedPostCardShimmer(
          isBiteFeed: _controller.selectedFeedType.value == HomeFeedType.bite,
          compactMedia: true,
        ),
      ],
    );
  }
}

class _HomeFeedItem extends StatelessWidget {
  const _HomeFeedItem({
    super.key,
    required this.controller,
    required this.post,
  });

  final HomeController controller;
  final HomePostModel post;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: RepaintBoundary(
        child: Obx(() {
          final latest = controller.watchPost(post).value;
          final selected =
              controller.selectedRatings[post.id] ?? latest.defaultSelectedRate;
          return FeedPostCard(
            post: latest,
            selectedRating: selected,
            isLikeLoading: controller.likeLoadingIds.contains(post.id),
            isSaveLoading: controller.saveLoadingIds.contains(post.id),
            isShareLoading: controller.shareLoadingIds.contains(post.id),
            isVoteLoading: controller.voteLoadingIds.contains(post.id),
            onRatingSelected: (value) => controller.votePost(post.id, value),
            onLike: () => controller.toggleLike(post.id),
            onSave: () => controller.toggleSave(post.id),
            onShare: (shareChannel) =>
                controller.sharePost(post.id, shareChannel: shareChannel),
            onDelete: () async {
              await controller.deletePost(post.id);
            },
            onEdit: () async {
              final didSave = await Get.to<bool>(
                () => EditPostScreen(post: post),
              );
              if (didSave == true) {
                await controller.refreshSinglePost(post.id);
              }
            },
            onRepost: () async {
              await controller.repostPost(post.id);
            },
            onBlock: () async {
              final username = post.profileUsername.trim().isNotEmpty
                  ? post.profileUsername
                  : post.username;
              await controller.blockUser(username);
            },
            onReport: (reasonCode, details) async {
              await controller.reportPost(post.id, reason: reasonCode, details: details);
            },
          );
        }),
      ),
    );
  }
}

class _LoadMoreSpinner extends StatelessWidget {
  const _LoadMoreSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(child: CircularProgressIndicator.adaptive()),
    );
  }
}

class _DiscoverToggleShimmer extends StatelessWidget {
  const _DiscoverToggleShimmer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.74),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppShimmerBox(
              width: 92,
              height: 36,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
            SizedBox(width: 6),
            AppShimmerBox(
              width: 92,
              height: 36,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedPostCardShimmer extends StatelessWidget {
  const _FeedPostCardShimmer({
    required this.isBiteFeed,
    this.compactMedia = false,
  });

  final bool isBiteFeed;
  final bool compactMedia;

  @override
  Widget build(BuildContext context) {
    final mediaHeight = compactMedia ? 300.0 : 360.0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(
              children: [
                const AppShimmerBox(
                  width: 40,
                  height: 40,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmerBox(
                        width: 112,
                        height: 14,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                      SizedBox(height: 8),
                      AppShimmerBox(
                        width: 160,
                        height: 11,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const AppShimmerBox(
                  width: 76,
                  height: 30,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                const SizedBox(width: 8),
                const AppShimmerBox(
                  width: 28,
                  height: 28,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: mediaHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const AppShimmerBox(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppShimmerBox(
                              width: 16,
                              height: 16,
                              borderRadius: BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                            SizedBox(width: 4),
                            AppShimmerBox(
                              width: 28,
                              height: 12,
                              borderRadius: BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (index) => const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 3),
                              child: AppShimmerBox(
                                width: 34,
                                height: 34,
                                borderRadius: BorderRadius.all(
                                  Radius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: AppShimmerBox(
                        height: 13,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ),
                    if (isBiteFeed) ...[
                      const SizedBox(width: 12),
                      const AppShimmerBox(
                        width: 84,
                        height: 13,
                        borderRadius: BorderRadius.all(Radius.circular(999)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                const AppShimmerBox(
                  width: 210,
                  height: 12,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    AppShimmerBox(
                      width: 72,
                      height: 28,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    SizedBox(width: 8),
                    AppShimmerBox(
                      width: 72,
                      height: 28,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                    SizedBox(width: 8),
                    AppShimmerBox(
                      width: 72,
                      height: 28,
                      borderRadius: BorderRadius.all(Radius.circular(999)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    final notificationsController = Get.isRegistered<NotificationsController>()
        ? Get.find<NotificationsController>()
        : Get.put(NotificationsController(), permanent: true);
    final chatUnreadController = Get.isRegistered<ChatUnreadController>()
        ? Get.find<ChatUnreadController>()
        : Get.put(ChatUnreadController());

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.94),
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Get.to<void>(() => const ProfileDetailScreen());
              },
              child: Obx(() {
                final avatarUrl = profileController.avatarImageUrl.value
                    .trim()
                    .isNotEmpty
                    ? profileController.avatarImageUrl.value.trim()
                    : (LocalStorage.getAvatarUrl() ?? '');
                return ClipOval(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: avatarUrl.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFE7E3E1),
                            child: Center(
                              child: AppHeroIconData(
                                Icons.person_rounded,
                                color: AppColors.hintText,
                              ),
                            ),
                          )
                        : AppCachedImage(
                            imageUrl: avatarUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            memCacheWidth: 120,
                          ),
                  ),
                );
              }),
            ),
            const SizedBox(width: 10),
            _FeedTypeToggle(controller: controller),
            const Spacer(),
            ...controller.model.quickActions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(left: 2),
                child: action.icon == HeroIcons.bell
                    ? Obx(
                        () => _TopActionIcon(
                          icon: action.icon,
                          showDot:
                              notificationsController.unreadCount.value > 0,
                          onPressed: () {
                            Get.to<void>(() => const NotificationsScreen());
                          },
                        ),
                      )
                    : action.icon == HeroIcons.chatBubbleOvalLeft
                    ? Obx(
                        () => _TopActionIcon(
                          icon: action.icon,
                          showDot: chatUnreadController.unreadCount.value > 0,
                          onPressed: () {
                            Get.to<void>(() => const MessagesScreen());
                          },
                        ),
                      )
                    : _TopActionIcon(
                        icon: action.icon,
                        showDot: action.showDot,
                        onPressed: () {
                          if (action.icon == HeroIcons.magnifyingGlass) {
                            final isBite =
                                controller.selectedFeedType.value ==
                                HomeFeedType.bite;
                            Get.to<void>(
                              () => SearchScreen(
                                mode: isBite
                                    ? SearchMode.restaurants
                                    : SearchMode.people,
                              ),
                            );
                          }
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedTypeToggle extends StatelessWidget {
  const _FeedTypeToggle({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AppSlidingToggle(
        labels: const ['Style', 'Bite'],
        selectedIndex:
            controller.selectedFeedType.value == HomeFeedType.bite ? 1 : 0,
        minSegmentWidth: 72,
        onChanged: (index) => controller.setFeedType(
          index == 1 ? HomeFeedType.bite : HomeFeedType.style,
        ),
      ),
    );
  }
}

class _DiscoverToggle extends StatelessWidget {
  const _DiscoverToggle({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Center(
        child: AppSlidingToggle(
          labels: const ['For You', 'Nearby'],
          selectedIndex:
              controller.selectedDiscoverType.value == HomeDiscoverType.nearby
              ? 1
              : 0,
          trackColor: Colors.white.withValues(alpha: 0.74),
          padding: const EdgeInsets.all(5),
          segmentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 10,
          ),
          minSegmentWidth: 104,
          fontSize: 12,
          letterSpacing: 0.25,
          onChanged: (index) => controller.setDiscoverType(
            index == 1 ? HomeDiscoverType.nearby : HomeDiscoverType.forYou,
          ),
        ),
      ),
    );
  }
}

class _TopActionIcon extends StatelessWidget {
  const _TopActionIcon({
    required this.icon,
    required this.showDot,
    required this.onPressed,
  });

  final Object icon;
  final bool showDot;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.86),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: AppHeroIconData(
                    icon,
                    size: 20,
                    color: AppColors.text,
                  ),
                ),
              ),
            ),
          ),
          if (showDot)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

