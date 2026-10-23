import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../home/models/home_post_model.dart';
import '../../post/screens/edit_post_screen.dart';
import '../../post/widgets/feed_post_card.dart';
import '../../reel/utils/reel_open_helper.dart';
import '../controllers/profile_posts_feed_controller.dart';
import '../models/profile_model.dart';

class ProfilePostsFeedScreen extends StatefulWidget {
  const ProfilePostsFeedScreen({
    super.key,
    required this.username,
    required this.tab,
    required this.isOwnProfile,
    required this.authorName,
    required this.avatarUrl,
    required this.initialPosts,
    required this.selectedPostId,
    required this.initialPage,
    required this.initialHasMore,
  });

  final String username;
  final ProfileContentTab tab;
  final bool isOwnProfile;
  final String authorName;
  final String avatarUrl;
  final List<HomePostModel> initialPosts;
  final String selectedPostId;
  final int initialPage;
  final bool initialHasMore;

  @override
  State<ProfilePostsFeedScreen> createState() => _ProfilePostsFeedScreenState();
}

class _ProfilePostsFeedScreenState extends State<ProfilePostsFeedScreen> {
  static const Key _centerKey = ValueKey<String>('profile-feed-center');

  late final String _tag;
  late final ProfilePostsFeedController _controller;

  @override
  void initState() {
    super.initState();
    _tag =
        'profile-posts-feed-${widget.username}-${widget.tab.name}-${widget.selectedPostId}';
    _controller = Get.isRegistered<ProfilePostsFeedController>(tag: _tag)
        ? Get.find<ProfilePostsFeedController>(tag: _tag)
        : Get.put(
            ProfilePostsFeedController(
              username: widget.username,
              tab: widget.tab,
              isOwnProfile: widget.isOwnProfile,
              authorName: widget.authorName,
              avatarUrl: widget.avatarUrl,
              initialPosts: widget.initialPosts,
              selectedPostId: widget.selectedPostId,
              initialPage: widget.initialPage,
              initialHasMore: widget.initialHasMore,
            ),
            tag: _tag,
          );
  }

  @override
  void dispose() {
    if (Get.isRegistered<ProfilePostsFeedController>(tag: _tag)) {
      Get.delete<ProfilePostsFeedController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          widget.authorName.trim().isEmpty ? 'Posts' : widget.authorName,
          style: AppFonts.plusJakarta(
            size: 20,
            weight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ),
      body: Obx(() {
        if (_controller.posts.isEmpty) {
          return const AppEmptyState(
            title: 'No posts',
            subtitle: 'There are no more posts to show.',
            icon: Icons.grid_view_rounded,
          );
        }

        final previousPosts = _controller.previousPosts;
        final remainingPosts = _controller.remainingPosts;
        // CustomScrollView lays out children before [center] in reverse, so
        // index 0 must be the item immediately above the selected post.
        final previousAbove = previousPosts.reversed.toList(growable: false);

        return CustomScrollView(
          controller: _controller.scrollController,
          center: _centerKey,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPostCard(previousAbove[index]),
                  childCount: previousAbove.length,
                ),
              ),
            ),
            SliverPadding(
              key: _centerKey,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index >= remainingPosts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      );
                    }
                    return _buildPostCard(remainingPosts[index]);
                  },
                  childCount:
                      remainingPosts.length +
                      (_controller.hasMore.value ? 1 : 0),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPostCard(HomePostModel post) {
    return Obx(() {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: FeedPostCard(
          post: post,
          selectedRating:
              _controller.selectedRatings[post.id] ?? post.defaultSelectedRate,
          isLikeLoading: _controller.likeLoadingIds.contains(post.id),
          isSaveLoading: _controller.saveLoadingIds.contains(post.id),
          isShareLoading: _controller.shareLoadingIds.contains(post.id),
          isVoteLoading: _controller.voteLoadingIds.contains(post.id),
          openPostDetailOnMediaTap: false,
          onOpenVideo: (video) async {
            ReelOpenHelper.openFromProfile(
              selected: video,
              authorPosts: _controller.posts.toList(growable: false),
              username: widget.username,
              tab: widget.tab,
              isOwnProfile: widget.isOwnProfile,
              authorName: widget.authorName,
              avatarUrl: widget.avatarUrl,
              currentPage: _controller.currentPage,
              hasMore: _controller.hasMore.value,
            );
          },
          onRatingSelected: (value) => _controller.votePost(post.id, value),
          onLike: () => _controller.toggleLike(post.id),
          onSave: () => _controller.toggleSave(post.id),
          onShare: (shareChannel) =>
              _controller.sharePost(post.id, shareChannel: shareChannel),
          onDelete: () => _controller.deletePost(post.id),
          onEdit: () async {
            final didSave = await Get.to<bool>(
              () => EditPostScreen(post: post),
            );
            if (didSave == true) {
              await _controller.refreshPost(post.id);
            }
          },
          onBlock: () => _controller.blockUser(
            post.profileUsername.trim().isNotEmpty
                ? post.profileUsername
                : post.username,
          ),
          onReport: (reasonCode, details) => _controller.reportPost(
            post.id,
            reason: reasonCode,
            details: details,
          ),
        ),
      );
    });
  }
}
