import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/tappable_profile_avatar.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/widgets/app_media_source_sheet.dart';
import '../../../core/widgets/states/app_empty_state.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../memories/screen/memories_screen.dart';
import '../../contest/controllers/contest_controller.dart';
import '../../contest/models/contest_model.dart';
import '../../settings/screen/settings_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_qr_scanner_screen.dart';
import '../controllers/profile_controller.dart';
import '../models/profile_model.dart';
import '../utils/profile_posts_feed_opener.dart';
import '../widgets/profile_food_cards.dart';
import '../widgets/profile_outfit_grid.dart';
import '../widgets/profile_tab_buttons.dart';
import '../widgets/follower_sheet.dart';
import '../widgets/style_rating_sheet.dart';
import '../../story/story_marker.dart';

class ProfileDetailScreen extends StatefulWidget {
  const ProfileDetailScreen({super.key});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late final ProfileController _controller;
  late final ContestController _contestController;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    _contestController = Get.isRegistered<ContestController>()
        ? Get.find<ContestController>()
        : Get.put(ContestController());

    // Initial fetch and refresh
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.refreshProfileOverview();
        _contestController.fetchProfileResults(reset: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1EFEF),
      body: Obx(() {
        if (_controller.isInitialLoading.value &&
            _controller.user.value == null) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_controller.hasError.value && _controller.user.value == null) {
          return AppErrorState(
            message: _controller.errorMessage.value.isEmpty
                ? 'Unable to load profile right now.'
                : _controller.errorMessage.value,
            onRetry: _controller.refreshProfileOverview,
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
                  _TopInlineBar(
                    controller: _controller,
                    onTapScanQr: _openQrScanner,
                  ),
                  const SizedBox(height: 18),
                  _HeaderSection(
                    controller: _controller,
                    onTapQr: _showProfileQrSheet,
                    onTapFollowers: () => _openFollowersSheet(true, 'Followers'),
                    onTapFollowing: () => _openFollowersSheet(false, 'Following'),
                    onTapStylePoints: _openStyleRatingSheet,
                  ),
                  const SizedBox(height: 18),
                  _AchievementSection(controller: _controller),
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
                              includeMoreTab: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildTabContent(),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTabContent() {
    switch (_controller.activeTab.value) {
      case ProfileContentTab.outfits:
        if (_controller.outfitPosts.isEmpty) {
          return const _ProfileTabEmptyState(
            title: 'No outfit posts yet',
            subtitle: 'Your outfit posts will appear here.',
            icon: Icons.photo_library_outlined,
          );
        }

        // Filter posts first, then derive images from that same list —
        // deriving images and filtering separately let the two lists drift
        // out of sync, so tapping tile N could open the wrong post once any
        // earlier post had no displayable image.
        final visibleOutfitPosts = _controller.outfitPosts
            .where((post) => post.primaryImageUrl.trim().isNotEmpty)
            .where(
              (post) =>
                  !StoryMarker.isStory(tags: post.tags, caption: post.caption),
            )
            .toList(growable: false);
        final images = visibleOutfitPosts
            .map((post) => post.primaryImageUrl)
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
            _PaginationFooter(
              isLoading: _controller.isLoadingMoreOutfits.value,
              hasMore: _controller.hasMoreOutfits,
            ),
          ],
        );
      case ProfileContentTab.food:
        if (_controller.foodPosts.isEmpty) {
          return const _ProfileTabEmptyState(
            title: 'No food posts yet',
            subtitle: 'Your food reviews and snapshots will show up here.',
            icon: Icons.restaurant_rounded,
          );
        }

        return Column(
          children: [
            ProfileFoodCards(
              items: _controller.foodPosts,
              onTapItem: _openProfilePost,
            ),
            _PaginationFooter(
              isLoading: _controller.isLoadingMoreFood.value,
              hasMore: _controller.hasMoreFood,
            ),
          ],
        );
      case ProfileContentTab.saved:
        if (_controller.savedPosts.isEmpty) {
          return const _ProfileTabEmptyState(
            title: 'No saved looks yet',
            subtitle:
                'Your saved inspiration appears here for quick styling reference.',
            icon: Icons.bookmark_border_rounded,
          );
        }

        final images = _controller.savedPosts
            .map((item) => item.imageUrl)
            .where((value) => value.trim().isNotEmpty)
            .toList(growable: false);

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F0EF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saved Looks',
                    style: AppFonts.plusJakarta(
                      size: 20,
                      weight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your saved inspiration appears here for quick styling reference.',
                    style: AppFonts.beVietnam(
                      size: 13,
                      weight: FontWeight.w500,
                      color: AppColors.hintText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
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
                      _openProfilePost(_controller.savedPosts[index].post),
                  borderRadius: BorderRadius.circular(14),
                  child: AppCachedImage(
                    imageUrl: images[index],
                    borderRadius: BorderRadius.circular(14),
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
            _PaginationFooter(
              isLoading: _controller.isLoadingMoreSaved.value,
              hasMore: _controller.hasMoreSaved,
            ),
          ],
        );
      case ProfileContentTab.more:
        return Obx(() {
          if (_contestController.isProfileResultsLoading.value &&
              _contestController.profileResults.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = _contestController.profileResults
              .expand(
                (contest) => contest.submissions
                    .where((submission) => submission.isMine)
                    .map(
                      (submission) => _ContestMediaEntry(
                        contest: contest,
                        submission: submission,
                      ),
                    ),
              )
              .toList(growable: false);

          final fallbackEntries = entries.isEmpty
              ? _contestController.profileResults
                    .expand(
                      (contest) => contest.submissions.map(
                        (submission) => _ContestMediaEntry(
                          contest: contest,
                          submission: submission,
                        ),
                      ),
                    )
                    .where(
                      (entry) => entry.submission.mediaUrl.trim().isNotEmpty,
                    )
                    .toList(growable: false)
              : entries;

          if (fallbackEntries.isEmpty) {
            return const _ProfileTabEmptyState(
              title: 'No contest media yet',
              subtitle: 'Contest submissions will appear here.',
              icon: Icons.emoji_events_outlined,
            );
          }

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fallbackEntries.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3 / 4,
            ),
            itemBuilder: (context, index) {
              final entry = fallbackEntries[index];
              return _ContestMediaTile(
                entry: entry,
                onTap: () => Get.toNamed(
                  AppRoutes.contestDetail,
                  arguments: {'contestId': entry.contest.id},
                ),
              );
            },
          );
        });
    }
  }

  void _openProfilePost(ProfilePostModel post) {
    final user = _controller.user.value;
    if (user == null) {
      return;
    }

    ProfilePostsFeedOpener.open(
      selected: post,
      tabPosts: _postsForActiveTab(),
      user: user,
      tab: _controller.activeTab.value,
      isOwnProfile: true,
      currentPage: _controller.activeTabCurrentPage,
      hasMore: _controller.activeTabHasMore,
    );
  }

  List<ProfilePostModel> _postsForActiveTab() {
    switch (_controller.activeTab.value) {
      case ProfileContentTab.outfits:
        return _controller.outfitPosts
            .where((item) => item.primaryImageUrl.trim().isNotEmpty)
            .toList(growable: false);
      case ProfileContentTab.food:
        return _controller.foodPosts.toList(growable: false);
      case ProfileContentTab.saved:
        return _controller.savedPosts
            .map((item) => item.post)
            .toList(growable: false);
      case ProfileContentTab.more:
        return const <ProfilePostModel>[];
    }
  }

  void _openFollowersSheet(bool isFollowers, String title) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FollowerSheet(
        username: _controller.username,
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
      builder: (context) => StyleRatingSheet(username: _controller.username),
    );
  }

  void _showProfileQrSheet() {
    final username = _controller.username.trim();
    if (username.isEmpty) {
      return;
    }

    // Changed to HTTPS for better camera compatibility and Deep Linking
    final payload = 'https://stylebiteapp.com/profile/${Uri.encodeComponent(username)}';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _ProfileQrSheet(username: username, payload: payload);
      },
    );
  }

  void _openQrScanner() {
    Get.to<void>(() => const ProfileQrScannerScreen());
  }
}

class _ProfileQrSheet extends StatefulWidget {
  const _ProfileQrSheet({
    required this.username,
    required this.payload,
  });

  final String username;
  final String payload;

  @override
  State<_ProfileQrSheet> createState() => _ProfileQrSheetState();
}

class _ProfileQrSheetState extends State<_ProfileQrSheet> {
  final GlobalKey _qrKey = GlobalKey();
  bool _sharing = false;

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.payload));
    successSnackBar(message: 'Profile link copied');
  }

  Future<void> _shareQrCode() async {
    if (_sharing) {
      return;
    }
    setState(() => _sharing = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Could not prepare QR code.');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) {
        throw Exception('Could not export QR code.');
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/stylebite_${widget.username}_qr.png',
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(
              file.path,
              mimeType: 'image/png',
              name: 'stylebite_${widget.username}_qr.png',
            ),
          ],
          text:
              'Scan this QR to open @${widget.username} on StyleBite\n${widget.payload}',
          subject: '@${widget.username} on StyleBite',
        ),
      );
    } catch (error) {
      errorSnackBar(
        message: error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9D4D3),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile QR',
                style: AppFonts.plusJakarta(
                  size: 22,
                  weight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Scan this in the app to open @${widget.username}',
                textAlign: TextAlign.center,
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w500,
                  color: AppColors.hintText,
                ),
              ),
              const SizedBox(height: 18),
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(47, 47, 46, 0.08),
                        blurRadius: 22,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth.clamp(240.0, 240.0);
                      return Center(
                        child: QrImageView(
                          data: widget.payload,
                          version: QrVersions.auto,
                          size: size,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: AppColors.text,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: AppColors.text,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _copyLink,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F0EF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.payload,
                    textAlign: TextAlign.center,
                    style: AppFonts.beVietnam(
                      size: 11,
                      weight: FontWeight.w600,
                      color: AppColors.hintText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '@${widget.username}',
                style: AppFonts.plusJakarta(
                  size: 18,
                  weight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _sharing ? null : _shareQrCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: _sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.share_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                    label: Text(
                      'Share QR Code',
                      style: AppFonts.beVietnam(
                        size: 14,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: const BorderSide(color: Color(0xFFE6E3E3)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: Text(
                    'Copy Link',
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w700,
                      color: AppColors.text,
                    ),
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

class _ContestMediaEntry {
  const _ContestMediaEntry({required this.contest, required this.submission});

  final ContestModel contest;
  final ContestSubmissionModel submission;
}

class _ContestMediaTile extends StatelessWidget {
  const _ContestMediaTile({required this.entry, required this.onTap});

  final _ContestMediaEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isVideo =
        entry.submission.mediaUrl.toLowerCase().contains('.mp4') ||
        entry.submission.mediaUrl.toLowerCase().contains('video');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0EF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppCachedImage(
              imageUrl: entry.submission.mediaUrl,
              borderRadius: BorderRadius.circular(16),
              fit: BoxFit.cover,
            ),
            if (isVideo)
              const Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(0, 0, 0, 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  entry.contest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w700,
                    color: Colors.white,
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

class _TopInlineBar extends StatelessWidget {
  const _TopInlineBar({required this.controller, required this.onTapScanQr});

  final ProfileController controller;
  final VoidCallback onTapScanQr;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: AppBackNavigation.handleBack,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.arrow_back_rounded,
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
          onTap: onTapScanQr,
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.qr_code_rounded,
              color: AppColors.hintText,
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () => Get.to<void>(() => const SettingsScreen()),
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.settings_outlined,
              color: AppColors.hintText,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderSection extends StatelessWidget {
  const _HeaderSection({
    required this.controller,
    required this.onTapQr,
    required this.onTapFollowers,
    required this.onTapFollowing,
    required this.onTapStylePoints,
  });

  final ProfileController controller;
  final VoidCallback onTapQr;
  final VoidCallback onTapFollowers;
  final VoidCallback onTapFollowing;
  final VoidCallback onTapStylePoints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          children: [
            Obx(
              () => TappableProfileAvatar(
                imageUrl: controller.avatarImageUrl.value,
                heroTag: 'profile-avatar-self',
              ),
            ),
            Positioned(
              right: 0,
              bottom: 4,
              child: GestureDetector(
                onTap: () async {
                  final source = await showMediaSourceSheet(context);
                  if (source == null) {
                    return;
                  }
                  await controller.pickAndUploadAvatar(
                    fromCamera: source == MediaSourceChoice.camera,
                  );
                },
                child: Obx(() => Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 1.8),
                  ),
                  child: controller.isUploadingAvatar.value
                      ? const Padding(
                          padding: EdgeInsets.all(5),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                )),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Obx(() => Row(
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
              username: controller.username,
              fallback: controller.user.value?.isVerifiedBadge == true,
              size: 18,
              spacing: 6,
            ),
          ],
        )),
        Obx(() {
          final location = controller.user.value?.locationLabel ?? '';
          if (location.trim().isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.hintText,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      location,
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
            ],
          );
        }),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => Get.to<void>(() => const EditProfileScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Edit Profile',
                  style: AppFonts.beVietnam(
                    size: 12,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onTapQr,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6E3E3),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(Icons.qr_code_rounded, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _QuickAction(
              icon: Icons.account_balance_wallet_rounded,
              label: 'My Earnings',
              onTap: () => Get.toNamed<void>(AppRoutes.myEarnings),
            ),
            _QuickAction(
              icon: Icons.photo_library_rounded,
              label: 'Memories',
              onTap: () => Get.to<void>(() => const MemoriesScreen()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatsRow(
          controller: controller,
          onTapFollowers: onTapFollowers,
          onTapFollowing: onTapFollowing,
          onTapStylePoints: onTapStylePoints,
        ),
        Obx(() {
          final summary = controller.profileSummary;
          if (summary.trim().isEmpty) return const SizedBox.shrink();
          return Column(
            children: [
              const SizedBox(height: 10),
              SizedBox(
                width: 320,
                child: Text(
                  summary,
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
          );
        }),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.controller,
    required this.onTapFollowers,
    required this.onTapFollowing,
    required this.onTapStylePoints,
  });

  final ProfileController controller;
  final VoidCallback onTapFollowers;
  final VoidCallback onTapFollowing;
  final VoidCallback onTapStylePoints;

  @override
  Widget build(BuildContext context) {
    return Obx(() => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatItem(
          value: controller.vibeCountLabel,
          label: 'Vibe Count',
          onTap: onTapFollowers,
        ),
        const SizedBox(width: 30),
        _StatItem(
          value: controller.vibeFlowLabel,
          label: 'Vibe Flow',
          onTap: onTapFollowing,
        ),
        const SizedBox(width: 30),
        _StatItem(
          value: controller.stylePointsLabel,
          label: 'Style Points',
          highlight: true,
          onTap: onTapStylePoints,
        ),
      ],
    ));
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
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
          crossAxisAlignment: CrossAxisAlignment.center,
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE7E4E4),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: AppColors.text),
              const SizedBox(width: 6),
              Text(
                label,
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
    );
  }
}

class _AchievementSection extends StatelessWidget {
  const _AchievementSection({required this.controller});

  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = controller.user.value;
      final streakDays = user?.currentStreakDays ?? 0;
      final streakValue = streakDays > 0 ? '$streakDays Days' : '0 Days';
      final streakSubtitle = (user?.currentStreakLabel ?? '').trim().isNotEmpty
          ? user!.currentStreakLabel
          : 'KEEP THE STREAK ALIVE';
      final contestWins = user?.contestWins ?? 0;
      final contestEntries = user?.contestEntries ?? 0;
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

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.isLoading, required this.hasMore});

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
    return const SizedBox(height: 8);
  }
}

class _ProfileTabEmptyState extends StatelessWidget {
  const _ProfileTabEmptyState({
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
