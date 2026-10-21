import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/local_storage.dart';
import '../../../core/widgets/like_heart_burst.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/double_tap_zoom.dart';
import '../../../core/widgets/app_cached_video_player.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/utils/verified_flag.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../home/models/home_post_model.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../../profile/widgets/follow_user_button.dart';
import '../controllers/post_detail_controller.dart';
import '../screens/edit_post_screen.dart';
import '../utils/in_app_share.dart';
import '../widgets/in_app_share_sheet.dart';
import '../widgets/food_post_details.dart';
import '../widgets/post_action_bar.dart';
import '../widgets/post_hashtag_chips.dart';
import '../widgets/post_media_carousel.dart';
import '../widgets/restaurant_review_sheet.dart';
import '../widgets/post_options_sheet.dart';
import '../../SelectLocationScreen/restaurant_map_screen.dart';
import 'comments_screen.dart';
import 'full_media_preview_screen.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final HomePostModel post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final PostDetailController _controller;
  late final String _tag = 'post-detail-${widget.post.id}';
  int _likeBurst = 0;

  void _onDoubleTapLike() {
    setState(() => _likeBurst++);
    if (!_controller.post.value.isLiked) {
      _controller.toggleLike();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<PostDetailController>(tag: _tag)
        ? Get.find<PostDetailController>(tag: _tag)
        : Get.put(
            PostDetailController(
              postId: widget.post.id,
              initialPost: widget.post,
            ),
            tag: _tag,
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Post',
          style: AppFonts.plusJakarta(
            size: 20,
            weight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _openPostOptions,
            icon: AppHeroIconData(HeroIcons.ellipsisVertical),
            color: AppColors.text,
          ),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return _loading();
        }

        if (_controller.hasError.value) {
          return AppErrorState(
            message: 'Could not load post detail. Check your connection.',
            onRetry: _controller.fetchDetail,
          );
        }

        final post = _controller.post.value;
        final comments = _controller.comments;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openAuthorProfile,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipOval(
                      child: post.hasAvatar
                          ? AppCachedImage(
                              imageUrl: post.avatarUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
                            )
                          : const ColoredBox(
                              color: Color(0xFFE9E3E1),
                              child: Center(
                                child: AppHeroIconData(Icons.person_rounded),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _openAuthorProfile,
                        borderRadius: BorderRadius.circular(8),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.beVietnam(
                                  size: 14,
                                  weight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            VerifiedBadgeSlot(
                              username: post.profileUsername.isNotEmpty
                                  ? post.profileUsername
                                  : post.username,
                              fallback: post.isVerifiedBadge,
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                      if (post.isFoodPost) ...[
                        if (post.biteHeaderSubtitle.trim().isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => RestaurantMapScreen.openForPost(post),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 1),
                              child: Text(
                                post.biteHeaderSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.beVietnam(
                                  size: 12,
                                  weight: FontWeight.w500,
                                  color: AppColors.hintText,
                                ),
                              ),
                            ),
                          ),
                        if (post.bitePinLocation.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => RestaurantMapScreen.openForPost(post),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  const AppHeroIconData(
                                    Icons.location_on_rounded,
                                    size: 12,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      post.bitePinLocation,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppFonts.beVietnam(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ] else
                        Text(
                          post.headerSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.beVietnam(
                            size: 12,
                            weight: FontWeight.w500,
                            color: AppColors.hintText,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!_isOwnPost(post))
                  FollowUserButton(
                    username: post.profileUsername,
                    initialIsFollowing: post.isFollowingAuthor,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (post.caption.isNotEmpty)
              HashtagCaptionText(
                text: post.caption,
                style: AppFonts.beVietnam(
                  size: 14,
                  weight: FontWeight.w500,
                  color: AppColors.text,
                ),
              ),
            if (post.isFoodPost &&
                (post.dishName.isNotEmpty || post.restaurant.isNotEmpty)) ...[
              const SizedBox(height: 12),
              FoodShowcaseCard(post: post),
            ],
            if (post.isFoodPost &&
                (post.hasFoodRatings || post.restaurant.trim().isNotEmpty)) ...[
              const SizedBox(height: 12),
              FoodRatingsCard(post: post),
              RestaurantReviewAction(post: post),
            ],
            const SizedBox(height: 12),
            GestureDetector(
              onTap: post.resolvedMediaType == AppMediaType.video
                  ? () {
                      Get.to<void>(
                        () => FullMediaPreviewScreen(
                          mediaUrl: post.primaryMediaUrl,
                          thumbnailUrl: post.thumbnailUrl,
                          type: post.resolvedMediaType,
                        ),
                      );
                    }
                  : null,
              onDoubleTap: post.resolvedMediaType == AppMediaType.video
                  ? _onDoubleTapLike
                  : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 4 / 5,
                      child: post.resolvedMediaType == AppMediaType.video
                          ? AppCachedVideoPlayer(
                              videoUrl: post.primaryMediaUrl,
                              thumbnailUrl: post.thumbnailUrl,
                              autoPlay: true,
                              isActive: true,
                              shareMute: true,
                            )
                          : post.isCarousel
                          ? PostMediaCarousel(
                              imageUrls: post.carouselImageUrls,
                              memCacheWidth: 900,
                              counterOnLeft:
                                  post.ratingEnabled &&
                                  _controller.canVote.value,
                              dotsBottom:
                                  post.ratingEnabled &&
                                      _controller.canVote.value
                                  ? 78
                                  : 12,
                              onImageTap: () {
                                Get.to<void>(
                                  () => FullMediaPreviewScreen(
                                    mediaUrl: post.primaryMediaUrl,
                                    imageUrls: post.carouselImageUrls,
                                    thumbnailUrl: post.thumbnailUrl,
                                    type: post.resolvedMediaType,
                                  ),
                                );
                              },
                              onDoubleTapLike: _onDoubleTapLike,
                            )
                          : DoubleTapZoom(
                              onTap: () {
                                Get.to<void>(
                                  () => FullMediaPreviewScreen(
                                    mediaUrl: post.primaryMediaUrl,
                                    thumbnailUrl: post.thumbnailUrl,
                                    type: post.resolvedMediaType,
                                  ),
                                );
                              },
                              onDoubleTapLike: _onDoubleTapLike,
                              child: AppCachedImage(
                                imageUrl: post.primaryMediaUrl,
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                    if (post.ratingEnabled && _controller.canVote.value) ...[
                      Positioned(
                        right: 14,
                        top: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              const AppHeroIconData(
                                Icons.star_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                post.displayRating.toStringAsFixed(1),
                                style: AppFonts.beVietnam(
                                  size: 13,
                                  weight: FontWeight.w700,
                                  color: AppColors.text,
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  final value = index + 1;
                                  final isSelected =
                                      post.defaultSelectedRate == value;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: GestureDetector(
                                      onTap: _controller.isVoteLoading.value
                                          ? null
                                          : () => _controller.votePost(value),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.white,
                                        ),
                                        child: Text(
                                          '$value',
                                          style: AppFonts.beVietnam(
                                            size: 13,
                                            weight: FontWeight.w700,
                                            color: isSelected
                                                ? Colors.white
                                                : AppColors.text,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_controller.isVoteLoading.value)
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: LikeHeartBurst(burstTick: _likeBurst),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            PostActionBar(
              likes: post.likes,
              comments: post.comments,
              isSaved: post.isSaved,
              isLiked: post.isLiked,
              isLikeLoading: _controller.isLikeLoading.value,
              isSaveLoading: _controller.isSaveLoading.value,
              isShareLoading: _controller.isShareLoading.value,
              onLike: _controller.toggleLike,
              onSave: _controller.toggleSave,
              onShare: _showShareSheet,
              onComment: _openComments,
            ),
            const SizedBox(height: 14),
            Text(
              'Top comments',
              style: AppFonts.plusJakarta(
                size: 16,
                weight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            if (comments.isEmpty)
              Text(
                'No comments yet',
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.hintText,
                ),
              )
            else
              ...comments
                  .take(2)
                  .map(
                    (comment) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final username = comment.user
                                  .trim()
                                  .replaceFirst(RegExp(r'^@'), '');
                              if (username.isEmpty) {
                                return;
                              }
                              ProfileOpenHelper.open(
                                username: username,
                                avatarUrl: comment.avatar,
                              );
                            },
                            child: CircleAvatar(
                              radius: 15,
                              backgroundImage: comment.hasAvatar
                                  ? NetworkImage(comment.avatar)
                                  : null,
                              child: comment.hasAvatar
                                  ? null
                                  : const AppHeroIconData(
                                      Icons.person_rounded,
                                      size: 15,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Obx(() {
                              VerifiedBadgeCache.revision.value;
                              return RichText(
                                text: TextSpan(
                                  children: AppVerifiedName.inlineSpans(
                                    name: comment.displayName,
                                    username: comment.user,
                                    isVerified: comment.isVerifiedBadge,
                                    style: AppFonts.beVietnam(
                                      size: 13,
                                      weight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                    suffix: ': ${comment.text}',
                                    suffixStyle: AppFonts.beVietnam(
                                      size: 13,
                                      weight: FontWeight.w500,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
            TextButton(
              onPressed: _openComments,
              child: const Text('View all comments'),
            ),
          ],
        );
      }),
    );
  }

  Widget _loading() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: const [
        AppShimmerBox(
          height: 54,
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        SizedBox(height: 12),
        AppShimmerBox(
          height: 22,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        SizedBox(height: 12),
        AppShimmerBox(
          height: 420,
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ],
    );
  }

  void _openComments() {
    CommentsScreen.show(context, post: _controller.post.value, tag: _tag);
  }

  Future<void> _showShareSheet() async {
    final channel = await InAppShareSheet.open(
      context: context,
      payload: InAppSharePayload.fromPost(_controller.post.value),
    );
    if (channel != null) {
      await _controller.sharePost(shareChannel: channel);
    }
  }

  bool _isOwnPost(HomePostModel post) {
    final currentUsername = LocalStorage.getUsername()?.trim().toLowerCase();
    if (currentUsername == null || currentUsername.isEmpty) {
      return false;
    }
    final candidates = <String>[
      post.profileUsername,
      post.username,
    ].map((value) => value.trim().replaceFirst('@', '').toLowerCase());
    return candidates.contains(currentUsername);
  }

  void _openAuthorProfile() {
    final post = _controller.post.value;
    final username = post.profileUsername.trim().isNotEmpty
        ? post.profileUsername.trim().replaceFirst('@', '')
        : post.username.trim().replaceFirst('@', '');
    if (username.isEmpty) {
      return;
    }

    ProfileOpenHelper.open(
      username: username,
      initialIsFollowing: post.isFollowingAuthor,
      avatarUrl: post.avatarUrl,
    );
  }

  Future<void> _openPostOptions() async {
    final post = _controller.post.value;
    final action = await showPostOptionsSheet(
      context,
      showOwnerOptions: _isOwnPost(post),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == PostOptionAction.edit) {
      final didSave = await Get.to<bool>(
        () => EditPostScreen(post: _controller.post.value),
      );
      if (didSave == true) {
        await _controller.fetchDetail(showLoader: false);
      }
      return;
    }
    if (action == PostOptionAction.repost) {
      await _controller.repostOwnerPost();
      return;
    }
    if (action == PostOptionAction.block) {
      final username = post.profileUsername.trim().isNotEmpty
          ? post.profileUsername.trim().replaceFirst('@', '')
          : post.username.trim().replaceFirst('@', '');
      final confirmed = await showBlockUserConfirmationSheet(
        context,
        username: username,
      );
      if (confirmed == true) {
        final blocked = await _controller.blockPostAuthor();
        if (blocked && mounted) {
          Navigator.of(context).pop();
        }
      }
      return;
    }
    final confirmed = await showDeletePostConfirmationSheet(context);
    if (confirmed == true) {
      final deleted = await _controller.deletePost();
      if (deleted && mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
