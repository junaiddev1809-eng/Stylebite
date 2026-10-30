import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_media_source_sheet.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../controllers/profile_controller.dart';
import '../utils/profile_page_transition.dart';
import 'profile_detail_screen.dart';

class ProfileSwipeScreen extends StatefulWidget {
  const ProfileSwipeScreen({super.key});

  @override
  State<ProfileSwipeScreen> createState() => _ProfileSwipeScreenState();
}

class _ProfileSwipeScreenState extends State<ProfileSwipeScreen> {
  late final ProfileController _controller;
  double? _startY;
  bool _opened = false;
  double _swipeProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    // Cover gate can mount before overview finishes (or after a failed first
    // fetch). Refresh silently so wallpaper URL is present on this screen.
    if (_controller.wallpaperImageUrl.value.trim().isEmpty) {
      _controller.fetchMyImages(silent: true);
    }
  }

  void _openDetails() {
    if (_opened) return;
    _opened = true;
    // Use the root navigator so ProfileDetail covers Landing (including the
    // bottom bar). A nested push would leave LandingBottomNav visible.
    Navigator.of(context, rootNavigator: true)
        .push<void>(ProfilePageTransition.to(const ProfileDetailScreen()))
        .whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
      if (mounted) {
        setState(() {
          _opened = false;
          _swipeProgress = 0;
        });
      } else {
        _opened = false;
      }
    });
  }

  Future<void> _onTapUploadCover() async {
    if (_controller.isUploadingCover.value) return;
    
    final source = await showMediaSourceSheet(context);
    if (source == null) return;
    
    await _controller.pickAndUploadCover(
      fromCamera: source == MediaSourceChoice.camera,
    );
  }

  Widget _buildCoverPlaceholder({Widget? child}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            const Color(0xFF0D0D0D),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ?child,
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      shape: const CircleBorder(),
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.30),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: _onTapUploadCover,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Obx(
            () => SizedBox(
              width: 26,
              height: 26,
              child: _controller.isUploadingCover.value
                  ? const CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.primary,
                    )
                  : const AppHeroIconData(
                      HeroIcons.camera,
                      color: AppColors.primary,
                      size: 26,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && event.scrollDelta.dy > 40) {
          _openDetails();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (details) => _startY = details.globalPosition.dy,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < -450) {
            _openDetails();
          }
          if (mounted) {
            setState(() => _swipeProgress = 0);
          }
          _startY = null;
        },
        onVerticalDragUpdate: (details) {
          if (_startY == null) return;
          final deltaY = _startY! - details.globalPosition.dy;
          if (mounted) {
            setState(() => _swipeProgress = (deltaY / 100).clamp(0, 1));
          }
          if (deltaY > 65) {
            _startY = null;
            _openDetails();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Layer
            AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              child: Transform.translate(
                offset: Offset(0, -22 * _swipeProgress),
                child: Transform.scale(
                  scale: 1 + (0.03 * _swipeProgress),
                  child: Obx(() {
                    final coverUrl = _controller.wallpaperImageUrl.value.trim();
                    final waitingForCover =
                        coverUrl.isEmpty &&
                        (_controller.isInitialLoading.value ||
                            _controller.isUploadingCover.value);
                    if (waitingForCover) {
                      return _buildCoverPlaceholder(
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      );
                    }
                    if (coverUrl.isEmpty) {
                      return _buildCoverPlaceholder(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildUploadButton(),
                            const SizedBox(height: 12),
                            Text(
                              _controller.isUploadingCover.value
                                  ? 'Uploading Cover Photo'
                                  : 'Upload Cover Photo',
                              style: AppFonts.beVietnam(
                                size: 14,
                                weight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return KeyedSubtree(
                      key: ValueKey<String>(coverUrl),
                      child: AppCachedImage(
                        imageUrl: coverUrl,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    );
                  }),
                ),
              ),
            ),

            // Gradient Overlay - wrapped in IgnorePointer to allow clicks to pass through
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color.fromRGBO(0, 0, 0, 0.62),
                      Color.fromRGBO(0, 0, 0, 0.12),
                      Color.fromRGBO(0, 0, 0, 0.2),
                    ],
                  ),
                ),
              ),
            ),

            // Top Camera Button (Only if cover image exists)
            Obx(() {
              final coverUrl = _controller.wallpaperImageUrl.value.trim();
              if (coverUrl.isEmpty) return const SizedBox.shrink();

              return Positioned(
                right: 16,
                top: topInset + 10,
                child: _buildUploadButton(),
              );
            }),

            // Bottom Navigation Arrow
            Positioned(
              left: 0,
              right: 0,
              bottom: 150,
              child: Center(
                child: _buildSwipeIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.96, end: 1.04),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value + (_swipeProgress * 0.08),
          child: Opacity(
            opacity: 0.72 + (_swipeProgress * 0.28),
            child: child,
          ),
        );
      },
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: Colors.white.withValues(alpha: 0.15),
          shape: const CircleBorder(
            side: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.4)),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _openDetails,
            child: const AppHeroIconData(
              HeroIcons.arrowUp,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
