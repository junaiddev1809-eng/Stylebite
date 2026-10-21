import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../home/models/home_post_model.dart';
import '../../search/widgets/explore_media_grid.dart';
import '../controllers/hashtag_feed_controller.dart';
import '../utils/post_detail_open_helper.dart';

class HashtagFeedScreen extends StatefulWidget {
  const HashtagFeedScreen({super.key, required this.tag});

  final String tag;

  @override
  State<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends State<HashtagFeedScreen> {
  late final String _tag;
  late final HashtagFeedController _controller;

  @override
  void initState() {
    super.initState();
    _tag = normalizeHashtag(widget.tag);
    _controller = Get.isRegistered<HashtagFeedController>(tag: _tag)
        ? Get.find<HashtagFeedController>(tag: _tag)
        : Get.put(HashtagFeedController(tag: _tag), tag: _tag);
  }

  @override
  void dispose() {
    if (Get.isRegistered<HashtagFeedController>(tag: _tag)) {
      Get.delete<HashtagFeedController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () {
            if (Get.key.currentState?.canPop() ?? false) {
              Get.back<void>();
              return;
            }
            AppBackNavigation.handleBack();
          },
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.text,
          ),
        ),
        title: Text(
          _tag,
          style: AppFonts.plusJakarta(
            size: 20,
            weight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ),
      body: Obx(() {
        if (_controller.isInitialLoading.value && _controller.posts.isEmpty) {
          return ExploreMediaGrid.shimmer();
        }
        if (_controller.hasError.value && _controller.posts.isEmpty) {
          return AppErrorState(
            message: _controller.errorMessage.value.isEmpty
                ? 'Could not load this hashtag.'
                : _controller.errorMessage.value,
            onRetry: _controller.refreshFeed,
          );
        }
        if (_controller.posts.isEmpty) {
          return AppEmptyState(
            title: 'No posts yet',
            subtitle: 'Be the first to post with $_tag.',
            icon: Icons.tag_rounded,
            actionLabel: 'Refresh',
            onAction: _controller.refreshFeed,
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _controller.refreshFeed,
          child: CustomScrollView(
            controller: _controller.scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: ExploreMediaGrid(
                  items: _controller.posts.toList(growable: false),
                  showRestaurantName: _controller.posts.any(
                    (post) =>
                        post.feedType == HomeFeedType.bite || post.isFoodPost,
                  ),
                  onTap: (post) => PostDetailOpenHelper.openIfAccessible(post),
                ),
              ),
              if (_controller.hasMore.value || _controller.isLoadingMore.value)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator.adaptive()),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        );
      }),
    );
  }
}
