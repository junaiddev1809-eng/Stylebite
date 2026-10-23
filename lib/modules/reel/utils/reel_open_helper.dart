import 'package:get/get.dart';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/media/reel_ready_service.dart';
import '../../home/models/home_post_model.dart';
import '../../profile/models/profile_model.dart';
import '../controllers/reel_controller.dart';
import '../models/reel_item_model.dart';
import '../screen/reel_screen.dart';

class ReelAuthorScope {
  const ReelAuthorScope({
    required this.username,
    required this.tab,
    required this.isOwnProfile,
    required this.authorName,
    required this.avatarUrl,
    required this.currentPage,
    required this.hasMore,
    this.seeds = const [],
  });

  final String username;
  final ProfileContentTab tab;
  final bool isOwnProfile;
  final String authorName;
  final String avatarUrl;
  final int currentPage;
  final bool hasMore;
  final List<ReelItemModel> seeds;
}

class ReelOpenHelper {
  const ReelOpenHelper._();

  static bool isReel(HomePostModel post) {
    return post.mediaType == HomeMediaType.video ||
        post.resolvedMediaType == AppMediaType.video;
  }

  static void openFromPost(HomePostModel post) {
    openViewer(
      seed: fromPost(post),
      type: post.feedType == HomeFeedType.bite || post.isFoodPost
          ? ReelFeedType.bite
          : ReelFeedType.style,
    );
  }

  static void openFromProfile({
    required HomePostModel selected,
    required List<HomePostModel> authorPosts,
    required String username,
    required ProfileContentTab tab,
    required bool isOwnProfile,
    required String authorName,
    required String avatarUrl,
    required int currentPage,
    required bool hasMore,
  }) {
    final seed = fromPost(selected);
    // Keep profile grid order, including the tapped reel, so scroll up/down
    // walks neighboring reels instead of forcing the selected item to index 0.
    final seeds = <ReelItemModel>[];
    final seen = <String>{};
    for (final post in authorPosts) {
      if (!isReel(post) || !seen.add(post.id)) {
        continue;
      }
      seeds.add(fromPost(post));
    }
    if (!seen.contains(seed.id)) {
      seeds.insert(0, seed);
    }
    openViewer(
      seed: seed,
      type: seed.feedType,
      authorScope: ReelAuthorScope(
        username: username,
        tab: tab,
        isOwnProfile: isOwnProfile,
        authorName: authorName,
        avatarUrl: avatarUrl,
        currentPage: currentPage,
        hasMore: hasMore,
        seeds: seeds,
      ),
    );
  }

  static void openViewer({
    required ReelItemModel seed,
    required ReelFeedType type,
    ReelAuthorScope? authorScope,
  }) {
    _prefetchViewerWindow(seed: seed, authorScope: authorScope, type: type);
    final tag = 'reel-viewer-${DateTime.now().microsecondsSinceEpoch}';
    Get.put(
      ReelController(
        viewerSeed: seed,
        viewerType: type,
        authorScope: authorScope,
      ),
      tag: tag,
    );
    Get.to<void>(
      () => ReelScreen(
        controllerTag: tag,
        viewerMode: true,
        // Profile-originated viewers should not show the landing bottom bar.
        showBottomNav: authorScope == null,
      ),
    );
  }

  static void _prefetchViewerWindow({
    required ReelItemModel seed,
    required ReelFeedType type,
    ReelAuthorScope? authorScope,
  }) {
    final urls = <String>[seed.mediaUrl];
    if (authorScope != null) {
      for (final reel in authorScope.seeds) {
        urls.add(reel.mediaUrl);
      }
    } else if (Get.isRegistered<ReelController>()) {
      for (final reel in Get.find<ReelController>().cachedReelsFor(type)) {
        if (reel.id == seed.id) {
          continue;
        }
        urls.add(reel.mediaUrl);
      }
    }
    ReelReadyService.prefetch(urls, limit: 5);
  }

  static ReelItemModel fromPost(HomePostModel post) {
    final isBite = post.feedType == HomeFeedType.bite || post.isFoodPost;
    final username = post.profileUsername.trim().isNotEmpty
        ? post.profileUsername.trim()
        : post.username.trim();
    final handle = username.startsWith('@') ? username : '@$username';
    final cover = (post.thumbnailUrl ?? '').trim().isNotEmpty
        ? post.thumbnailUrl!.trim()
        : post.imageUrl;
    final video = post.mediaUrl.trim().isNotEmpty
        ? post.mediaUrl.trim()
        : post.primaryMediaUrl;
    return ReelItemModel(
      id: post.id,
      feedType: isBite ? ReelFeedType.bite : ReelFeedType.style,
      mediaType: ReelMediaType.video,
      handle: handle,
      caption: post.caption,
      tags: post.tags,
      rating: post.displayRating <= 0
          ? '0.0'
          : post.displayRating.toStringAsFixed(1),
      likes: post.likes,
      comments: post.comments,
      imageUrl: cover,
      imageAlt: post.caption,
      avatarUrl: post.avatarUrl,
      authorName: post.authorName,
      locationName: post.location,
      restaurant: post.restaurant,
      dishName: post.dishName,
      foodRating: post.foodRating,
      serviceRating: post.serviceRating,
      staffRating: post.staffRating,
      ambienceRating: post.ambienceRating,
      city: post.authorCity,
      latitude: post.latitude,
      longitude: post.longitude,
      videoUrl: video,
      likeCount: _parseCount(post.likes),
      commentCount: _parseCount(post.comments),
      shareCount: post.shareCount,
      saveCount: post.saveCount,
      viewCount: post.viewCount,
      isLiked: post.isLiked,
      isSaved: post.isSaved,
      profileUsername: username.replaceFirst(RegExp(r'^@+'), ''),
      isFollowingAuthor: post.isFollowingAuthor,
      isVerifiedBadge: post.isVerifiedBadge,
      ratingEnabled: post.ratingEnabled,
      publishedAt: post.publishedAt,
    );
  }

  static int _parseCount(String raw) {
    final value = raw.trim().toLowerCase().replaceAll(',', '');
    if (value.isEmpty) {
      return 0;
    }
    if (value.endsWith('k')) {
      return ((double.tryParse(value.substring(0, value.length - 1)) ?? 0) *
              1000)
          .round();
    }
    if (value.endsWith('m')) {
      return ((double.tryParse(value.substring(0, value.length - 1)) ?? 0) *
              1000000)
          .round();
    }
    return int.tryParse(value) ?? 0;
  }
}
