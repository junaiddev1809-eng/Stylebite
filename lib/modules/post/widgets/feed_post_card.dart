import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart';
import 'dart:async';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/reel_ready_service.dart';
import '../../../core/media/shared_video_mute.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/double_tap_zoom.dart';
import '../../../core/widgets/like_heart_burst.dart';
import '../../../core/widgets/app_cached_video_player.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../home/models/home_post_model.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../../profile/widgets/follow_user_button.dart';
import '../controllers/post_detail_controller.dart';
import '../controllers/restaurant_review_store.dart';
import '../screens/comments_screen.dart';
import '../screens/full_media_preview_screen.dart';
import '../utils/post_detail_open_helper.dart';
import '../utils/in_app_share.dart';
import '../widgets/in_app_share_sheet.dart';
import '../widgets/contest_post_badge.dart';
import '../widgets/winner_sparkle_overlay.dart';
import '../widgets/food_post_details.dart';
import '../widgets/post_action_bar.dart';
import '../widgets/post_media_carousel.dart';
import '../widgets/post_hashtag_chips.dart';
import '../widgets/restaurant_review_sheet.dart';
import 'post_options_sheet.dart';
import '../../reports/widgets/report_reason_sheet.dart';
import '../../messages/utils/chat_start_helper.dart';
import '../../SelectLocationScreen/restaurant_map_screen.dart';

class FeedPostCard extends StatefulWidget {
  const FeedPostCard({
    super.key,
    required this.post,
    required this.selectedRating,
    required this.onRatingSelected,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    this.isLikeLoading = false,
    this.isSaveLoading = false,
    this.isShareLoading = false,
    this.isVoteLoading = false,
    this.showCommentAction = true,
    this.showLikeAction = true,
    this.ratingInActionBar = false,
    this.onDelete,
    this.onEdit,
    this.onRepost,
    this.onBlock,
    this.onReport,
    this.openPostDetailOnMediaTap = true,
    this.onOpenVideo,
    this.pictureBadge,
    this.pictureBadgeAtTop = false,
    this.hideRatingBadge = false,
  });

  final HomePostModel post;
  final int selectedRating;
  final ValueChanged<int> onRatingSelected;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final Future<void> Function(String shareChannel) onShare;
  final bool isLikeLoading;
  final bool isSaveLoading;
  final bool isShareLoading;
  final bool isVoteLoading;
  final bool showCommentAction;
  final bool showLikeAction;

  /// Puts the 1–5 rating next to the action icons, before save.
  final bool ratingInActionBar;
  final Future<void> Function()? onDelete;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onRepost;
  final Future<void> Function()? onBlock;
  final Future<void> Function(String reasonCode, String? details)? onReport;
  final bool openPostDetailOnMediaTap;
  final Future<void> Function(HomePostModel post)? onOpenVideo;
  final Widget? pictureBadge;
  final bool pictureBadgeAtTop;
  final bool hideRatingBadge;

  @override
  State<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends State<FeedPostCard> {
  final GlobalKey _mediaKey = GlobalKey();
  ScrollPosition? _scrollPosition;
  bool _isVideoActive = false;
  double _videoProgress = 0;
  int _likeBurst = 0;
  bool _reviewsExpanded = false;
  bool _reviewsLoading = false;
  HomePostModel? _reviewDetail;

  @override
  void initState() {
    super.initState();
    if (_isVideoPost) {
      ReelReadyService.prefetch([widget.post.primaryMediaUrl], limit: 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _bindScrollListener();
        _updateVideoFocus();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isVideoPost) {
      _bindScrollListener();
    }
  }

  @override
  void didUpdateWidget(covariant FeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.primaryMediaUrl != widget.post.primaryMediaUrl) {
      _reviewsExpanded = false;
      _reviewsLoading = false;
      _reviewDetail = null;
      if (_isVideoPost) {
        ReelReadyService.prefetch([widget.post.primaryMediaUrl], limit: 1);
      }
      _updateVideoFocus();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F0EF),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
            child: Row(
              children: [
                // Optimized Avatar loading
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openAuthorProfile,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: ClipOval(
                      child: post.avatarUrl.trim().isEmpty
                          ? const ColoredBox(
                              color: Color(0xFFE7E3E1),
                              child: Center(
                                child: AppHeroIconData(
                                  Icons.person_rounded,
                                  color: AppColors.hintText,
                                  size: 22,
                                ),
                              ),
                            )
                          : AppCachedImage(
                              imageUrl: post.avatarUrl,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              memCacheWidth: 120,
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
                          mainAxisSize: MainAxisSize.min,
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
                      if (_isBiteCard) ...[
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
                                  size: 11,
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
                            size: 11,
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
                    compact: true,
                  ),
                if (!_isOwnPost(post)) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => ChatStartHelper.startChat(
                      post.profileUsername.trim().isNotEmpty
                          ? post.profileUsername
                          : post.username,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 36,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF2EFEE),
                    ),
                    icon: const AppHeroIconData(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: AppColors.text,
                    ),
                  ),
                ],
                IconButton(
                  onPressed: _openOptions,
                  icon: AppHeroIconData(HeroIcons.ellipsisVertical),
                  color: AppColors.hintText,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                key: _mediaKey,
                aspectRatio: 4 / 5,
                child: GestureDetector(
                  onTap: post.resolvedMediaType == AppMediaType.video
                      ? () => _openMedia(post)
                      : null,
                  onDoubleTap: post.resolvedMediaType == AppMediaType.video
                      ? _onDoubleTapLike
                      : null,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (post.resolvedMediaType == AppMediaType.video)
                        AppCachedVideoPlayer(
                          videoUrl: post.primaryMediaUrl,
                          thumbnailUrl: post.thumbnailUrl,
                          autoPlay: true,
                          isActive: _isVideoActive,
                          deferInitUntilActive: true,
                          showControls: true,
                          showPlayPauseButton: false,
                          showMuteButton: true,
                          controlsPosition: AppVideoControlsPosition.topLeft,
                          onProgressChanged: (value) => _videoProgress = value,
                          shareMute: true,
                          onMutedChanged: SharedVideoMute.setMuted,
                        )
                      else if (post.isCarousel)
                        PostMediaCarousel(
                          imageUrls: post.carouselImageUrls,
                          memCacheWidth: 800,
                          counterOnLeft: post.ratingEnabled || post.isInContest,
                          dotsBottom: _ratingOnPicture ? 78 : 12,
                          onImageTap: () => _openMedia(post),
                          onDoubleTapLike: _onDoubleTapLike,
                        )
                      else
                        DoubleTapZoom(
                          onTap: () => _openMedia(post),
                          onDoubleTapLike: _onDoubleTapLike,
                          child: AppCachedImage(
                          imageUrl: post.primaryMediaUrl,
                          // Only bounding width (not both dimensions) lets
                          // the decoder scale down while preserving the
                          // source aspect ratio — specifying both forces an
                          // exact, non-uniform resize that stretches any
                          // image whose native ratio isn't already 4:5
                          // (this card only enforces 4:5 via its outer
                          // AspectRatio + BoxFit.cover, at the layout
                          // level).
                            memCacheWidth: 800,
                          ),
                        ),
                      if (post.isContestWinner) const WinnerSparkleOverlay(),
                      if (widget.pictureBadge != null)
                        Positioned(
                          left: 12,
                          top: widget.pictureBadgeAtTop
                              ? (post.resolvedMediaType == AppMediaType.video
                                    ? 52
                                    : 14)
                              : null,
                          bottom: widget.pictureBadgeAtTop
                              ? null
                              : (_ratingOnPicture ? 86 : 14),
                          child: widget.pictureBadge!,
                        ),
                      // rating_enabled comes straight from the post payload
                      // — when it's false the backend rejects votes with a
                      // 403, so the rating badge/selector must not render
                      // at all rather than surface a vote that always fails.
                      if (!widget.hideRatingBadge &&
                          (post.ratingEnabled || post.isInContest))
                        Positioned(
                          top: 14,
                          right: 14,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (post.ratingEnabled)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
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
                                            post.displayRating.toStringAsFixed(
                                              1,
                                            ),
                                            style: AppFonts.beVietnam(
                                              size: 13,
                                              weight: FontWeight.w700,
                                              color: AppColors.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  // Trophy marks contest-enrolled posts.
                                  if (post.isInContest) ...[
                                    if (post.ratingEnabled)
                                      const SizedBox(width: 6),
                                    const ContestTrophyBadge(),
                                  ],
                                ],
                              ),
                              // Contest name tag — tapping it opens the
                              // contest page (only the tag, not the media).
                              if (post.isInContest) ...[
                                const SizedBox(height: 6),
                                ContestNameTag(
                                  contestId: post.contestId,
                                  contestTitle: post.contestTitle,
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (_ratingOnPicture)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 16,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {},
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  final value = index + 1;
                                  final isSelected =
                                      widget.selectedRating == value;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3,
                                    ),
                                    child: GestureDetector(
                                      onTap: () =>
                                          widget.onRatingSelected(value),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected
                                              ? AppColors.primary
                                              : Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: isSelected
                                                  ? const Color.fromRGBO(
                                                      255,
                                                      77,
                                                      109,
                                                      0.35,
                                                    )
                                                  : const Color.fromRGBO(
                                                      47,
                                                      47,
                                                      46,
                                                      0.12,
                                                    ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                              spreadRadius: -4,
                                            ),
                                          ],
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
                      LikeHeartBurst(burstTick: _likeBurst),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (post.caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ExpandableCaption(
                  text: post.caption,
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                  onOpenComments: widget.showCommentAction
                      ? () {
                          final tag = 'post-detail-${post.id}';
                          if (!Get.isRegistered<PostDetailController>(
                            tag: tag,
                          )) {
                            Get.put(
                              PostDetailController(
                                postId: post.id,
                                initialPost: post,
                              ),
                              tag: tag,
                            );
                          }
                          CommentsScreen.show(context, post: post, tag: tag);
                        }
                      : null,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 12),
            child: PostActionBar(
              likes: post.likes,
              comments: post.comments,
              isSaved: post.isSaved,
              isLiked: post.isLiked,
              isLikeLoading: widget.isLikeLoading,
              isSaveLoading: widget.isSaveLoading,
              isShareLoading: widget.isShareLoading,
              onLike: widget.onLike,
              onSave: widget.onSave,
              onComment: () {
                if (!widget.showCommentAction) {
                  return;
                }
                final tag = 'post-detail-${post.id}';
                if (!Get.isRegistered<PostDetailController>(tag: tag)) {
                  Get.put(
                    PostDetailController(postId: post.id, initialPost: post),
                    tag: tag,
                  );
                }
                CommentsScreen.show(context, post: post, tag: tag);
              },
              onShare: _showShareSheet,
              showCommentAction: widget.showCommentAction,
              showLikeAction: widget.showLikeAction,
              showRatingSelector: widget.ratingInActionBar && post.ratingEnabled,
              selectedRating: widget.selectedRating,
              onRatingSelected: widget.onRatingSelected,
              isVoteLoading: widget.isVoteLoading,
              showReviewsAction: _isBiteCard,
              reviewsExpanded: _reviewsExpanded,
              isReviewsLoading: _reviewsLoading,
              onReviews: _isBiteCard ? _toggleReviews : null,
            ),
          ),
          if (_isBiteCard) _buildReviewsPanel(),
        ],
      ),
    );
  }

  bool get _ratingOnPicture =>
      widget.post.ratingEnabled && !widget.ratingInActionBar;

  bool get _isBiteCard =>
      widget.post.feedType == HomeFeedType.bite || widget.post.isFoodPost;

  HomePostModel get _reviewPost => _reviewDetail ?? widget.post;

  bool get _hasCompleteFoodDetails {
    final post = _reviewPost;
    return post.hasFoodRatings &&
        (post.dishName.trim().isNotEmpty || post.restaurant.trim().isNotEmpty);
  }

  Future<void> _toggleReviews() async {
    if (_reviewsLoading) {
      return;
    }

    if (_reviewsExpanded) {
      setState(() => _reviewsExpanded = false);
      return;
    }

    if (_hasCompleteFoodDetails) {
      setState(() => _reviewsExpanded = true);
      unawaited(
        RestaurantReviewStore.instance.ensureRestaurantLoaded(_reviewPost),
      );
      return;
    }

    setState(() => _reviewsLoading = true);
    final detail = await PostDetailOpenHelper.fetchPost(widget.post.id);
    if (!mounted) {
      return;
    }

    if (detail == null) {
      setState(() => _reviewsLoading = false);
      errorSnackBar(message: 'Could not load food reviews.');
      return;
    }

    setState(() {
      _reviewDetail = detail;
      _reviewsLoading = false;
      _reviewsExpanded = true;
    });
    unawaited(RestaurantReviewStore.instance.ensureRestaurantLoaded(detail));
  }

  Widget _buildReviewsPanel() {
    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: _reviewsExpanded
            ? Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey<String>('reviews-${widget.post.id}'),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: 1),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      FoodShowcaseCard(post: _reviewPost),
                      const SizedBox(height: 10),
                      FoodRatingsCard(
                        post: _reviewPost,
                        backgroundColor: Colors.white,
                        showAllMetrics: true,
                      ),
                      RestaurantReviewAction(post: _reviewPost),
                    ],
                  ),
                ),
              )
            : const SizedBox(width: double.infinity),
      ),
    );
  }

  void _bindScrollListener() {
    if (!_isVideoPost) {
      return;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || identical(position, _scrollPosition)) {
      return;
    }
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollActivityChanged);
    _scrollPosition = position;
    _scrollPosition?.isScrollingNotifier.addListener(_onScrollActivityChanged);
  }

  void _onScrollActivityChanged() {
    final scrolling = _scrollPosition?.isScrollingNotifier.value ?? false;
    if (scrolling || !mounted) {
      return;
    }
    _updateVideoFocus();
  }

  void _updateVideoFocus() {
    if (!_isVideoPost || !TickerMode.of(context)) {
      if (_isVideoActive) {
        setState(() {
          _isVideoActive = false;
        });
      }
      return;
    }

    final renderObject = _mediaKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }

    final size = renderObject.size;
    if (size.height <= 0) {
      return;
    }

    final offset = renderObject.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final visibleTop = offset.dy.clamp(0.0, screenHeight);
    final visibleBottom = (offset.dy + size.height).clamp(0.0, screenHeight);
    final visibleHeight = visibleBottom - visibleTop;
    final visibleRatio = visibleHeight / size.height;
    final centerY = offset.dy + (size.height / 2);
    final viewportCenter = screenHeight / 2;
    final isCenteredEnough =
        (centerY - viewportCenter).abs() < size.height * 0.45;
    final shouldBeActive = visibleRatio >= 0.65 && isCenteredEnough;

    if (shouldBeActive != _isVideoActive) {
      setState(() {
        _isVideoActive = shouldBeActive;
      });
    }
  }

  bool get _isVideoPost => widget.post.resolvedMediaType == AppMediaType.video;

  void _onDoubleTapLike() {
    setState(() => _likeBurst++);
    if (!widget.post.isLiked) {
      widget.onLike();
    }
  }

  Future<void> _openMedia(HomePostModel post) {
    if (post.resolvedMediaType == AppMediaType.video) {
      if (widget.onOpenVideo != null) {
        return widget.onOpenVideo!(post);
      }
      return _openPostDetail(post);
    }
    if (widget.openPostDetailOnMediaTap && post.feedType == HomeFeedType.bite) {
      return _openPostDetail(post);
    }
    return _openFullMediaPreview(post);
  }

  Future<void> _openPostDetail(HomePostModel post) async {
    final isVideo = post.resolvedMediaType == AppMediaType.video;
    // Same reasoning as _openFullMediaPreview: pause the feed's own player
    // before pushing the detail screen so it doesn't keep playing
    // underneath it.
    if (isVideo && _isVideoActive) {
      setState(() => _isVideoActive = false);
    }

    await PostDetailOpenHelper.openIfAccessible(post);

    if (isVideo && mounted) {
      _updateVideoFocus();
    }
  }

  Future<void> _openFullMediaPreview(HomePostModel post) async {
    final isVideo = post.resolvedMediaType == AppMediaType.video;
    // Pause the feed's own player immediately so it isn't still playing
    // (and consuming audio/decoder resources) underneath the full-screen
    // view — _updateVideoFocus() below restores it once we're back, since
    // scrolling doesn't happen while that route is on top to trigger it.
    if (isVideo && _isVideoActive) {
      setState(() => _isVideoActive = false);
    }

    await Get.to<void>(
      () => FullMediaPreviewScreen(
        mediaUrl: post.primaryMediaUrl,
        imageUrls: post.isCarousel ? post.carouselImageUrls : const [],
        thumbnailUrl: post.thumbnailUrl,
        type: post.resolvedMediaType,
        initialProgress: isVideo ? _videoProgress : null,
        initialMuted: isVideo ? SharedVideoMute.muted.value : null,
      ),
    );

    if (isVideo && mounted) {
      _updateVideoFocus();
    }
  }

  Future<void> _openOptions() async {
    final action = await showPostOptionsSheet(
      context,
      showOwnerOptions: _isOwnPost(widget.post),
    );
    if (!mounted || action == null) {
      return;
    }

    if (action == PostOptionAction.delete) {
      final confirmed = await showDeletePostConfirmationSheet(context);
      if (confirmed == true) {
        await widget.onDelete?.call();
      }
      return;
    }

    if (action == PostOptionAction.edit) {
      await widget.onEdit?.call();
      return;
    }

    if (action == PostOptionAction.repost) {
      await widget.onRepost?.call();
      return;
    }

    if (action == PostOptionAction.block) {
      final blockUsername = widget.post.profileUsername.trim().isNotEmpty
          ? widget.post.profileUsername.trim().replaceFirst('@', '')
          : widget.post.username.trim().replaceFirst('@', '');
      final confirmed = await showBlockUserConfirmationSheet(
        context,
        username: blockUsername,
      );
      if (confirmed == true) {
        await widget.onBlock?.call();
      }
      return;
    }

    if (action == PostOptionAction.report) {
      final result = await showReportReasonSheet(context, title: 'Report post');
      if (result != null) {
        await widget.onReport?.call(result.reasonCode, result.details);
      }
      return;
    }
  }

  void _openAuthorProfile() {
    final username = widget.post.profileUsername.trim().isNotEmpty
        ? widget.post.profileUsername.trim().replaceFirst('@', '')
        : widget.post.username.trim().replaceFirst('@', '');
    if (username.isEmpty) {
      return;
    }

    ProfileOpenHelper.open(
      username: username,
      initialIsFollowing: widget.post.isFollowingAuthor,
      avatarUrl: widget.post.avatarUrl,
    );
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

  Future<void> _showShareSheet() async {
    final channel = await InAppShareSheet.open(
      context: context,
      payload: InAppSharePayload.fromPost(widget.post),
    );
    if (channel != null) {
      await widget.onShare(channel);
    }
  }
}

class _ExpandableCaption extends StatelessWidget {
  const _ExpandableCaption({
    required this.text,
    required this.style,
    this.onOpenComments,
  });

  final String text;
  final TextStyle style;
  final VoidCallback? onOpenComments;

  static const int _collapsedMaxLines = 2;

  @override
  Widget build(BuildContext context) {
    return HashtagCaptionText(
      text: text,
      style: style,
      maxLines: _collapsedMaxLines,
      overflow: TextOverflow.ellipsis,
      onTapText: onOpenComments,
    );
  }
}
