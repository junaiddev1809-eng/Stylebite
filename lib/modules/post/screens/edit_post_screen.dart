import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/media/media_type_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_cached_video_player.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_media_source_sheet.dart';
import '../../home/models/home_post_model.dart';
import '../../upload/models/upload_post_model.dart';
import '../../upload/widgets/upload_food_ratings.dart';
import '../../upload/widgets/upload_post_type_selector.dart';
import '../../upload/widgets/upload_visibility_selector.dart';
import '../utils/hashtag_caption_limit.dart';
import '../controllers/edit_post_controller.dart';

class EditPostScreen extends StatefulWidget {
  const EditPostScreen({super.key, required this.post});

  final HomePostModel post;

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late final EditPostController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(
      EditPostController(initialPost: widget.post),
      tag: 'edit-post-${widget.post.id}',
    );
  }

  @override
  void dispose() {
    Get.delete<EditPostController>(tag: 'edit-post-${widget.post.id}');
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final source = await showMediaSourceSheet(context);
    if (source == null) {
      return;
    }
    await _controller.pickMedia(fromCamera: source == MediaSourceChoice.camera);
  }

  Future<void> _save() async {
    final didSave = await _controller.savePost();
    if (!mounted || !didSave) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Edit Post',
          style: AppFonts.plusJakarta(
            size: 20,
            weight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              sliver: SliverToBoxAdapter(
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UploadPostTypeSelector(
                        selectedType: _controller.selectedType.value,
                        onChanged: _controller.setPostType,
                      ),
                      const SizedBox(height: 18),
                      _EditMediaPreview(
                        controller: _controller,
                        post: widget.post,
                        onPick: _pickMedia,
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Caption'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _controller.captionController,
                        maxLines: 5,
                        inputFormatters: const [MaxHashtagInputFormatter()],
                        style: AppFonts.beVietnam(),
                        decoration: _inputDecoration(
                          'Write a caption. Add up to 5 tags with #, like #ootd',
                          radius: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel('Location'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _controller.locationController,
                        style: AppFonts.beVietnam(weight: FontWeight.w600),
                        decoration: _inputDecoration(
                          'Type a location (optional)',
                          icon: Icons.location_on_rounded,
                          radius: 16,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_controller.selectedType.value == UploadPostType.food) ...[
                        _foodFields(),
                        const SizedBox(height: 14),
                      ],
                      _FieldLabel('Visibility'),
                      const SizedBox(height: 8),
                      UploadVisibilitySelector(
                        selected: _controller.selectedVisibility.value,
                        onChanged: _controller.setVisibility,
                      ),
                      if (_controller.isVisibilityLoading.value) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Loading current visibility...',
                          style: AppFonts.beVietnam(
                            size: 11,
                            color: AppColors.hintText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _controller.isSaving.value
                                ? null
                                : _save,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: Text(
                              _controller.isSaving.value
                                  ? 'Saving...'
                                  : 'Update Post',
                              style: AppFonts.beVietnam(
                                size: 16,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            label: const AppHeroIconData(Icons.send_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _foodFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Dish Name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller.dishNameController,
                    style: AppFonts.beVietnam(weight: FontWeight.w600),
                    decoration: _inputDecoration(
                      'Dish name',
                      icon: Icons.local_dining_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Restaurant'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller.restaurantController,
                    style: AppFonts.beVietnam(weight: FontWeight.w600),
                    decoration: _inputDecoration(
                      'Restaurant',
                      icon: Icons.storefront_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        UploadFoodRatings(
          items: _controller.ratingItems,
          values: _controller.foodRatings,
          onChanged: _controller.setFoodRating,
          overall:
              _controller.foodRatings.values.fold<double>(
                0,
                (sum, value) => sum + value,
              ) /
              _controller.foodRatings.length,
          previewTitle: _controller.dishNameController.text.trim().isEmpty
              ? 'Food Ratings'
              : _controller.dishNameController.text.trim(),
          previewLocation: _controller.restaurantController.text.trim().isEmpty
              ? 'Update your dining review'
              : _controller.restaurantController.text.trim(),
        ),
      ],
    );
  }
}

class _EditMediaPreview extends StatelessWidget {
  const _EditMediaPreview({
    required this.controller,
    required this.post,
    required this.onPick,
  });

  final EditPostController controller;
  final HomePostModel post;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final replacement = controller.selectedMedia.value;
      final mediaError = controller.mediaError.value;
      final currentMediaType = replacement?.type ?? post.resolvedMediaType;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (replacement != null)
                    if (currentMediaType == AppMediaType.video)
                      AppCachedVideoPlayer(
                        videoUrl: replacement.path,
                        autoPlay: false,
                        isActive: true,
                      )
                    else
                      Image.file(replacement.file, fit: BoxFit.cover)
                  else if (currentMediaType == AppMediaType.video)
                    AppCachedVideoPlayer(
                      videoUrl: post.primaryMediaUrl,
                      thumbnailUrl: post.thumbnailUrl,
                      autoPlay: false,
                      isActive: true,
                    )
                  else
                    AppCachedImage(imageUrl: post.primaryMediaUrl),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: onPick),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      children: [
                        _ActionCircle(
                          icon: Icons.photo_camera_back_rounded,
                          onTap: onPick,
                        ),
                        const SizedBox(width: 8),
                        _ActionCircle(
                          icon: Icons.delete_rounded,
                          color: Colors.redAccent,
                          onTap: controller.clearMedia,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (mediaError.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              mediaError,
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w600,
                color: Colors.redAccent,
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.icon, this.color, required this.onTap});

  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.9),
        ),
        child: AppHeroIconData(icon,
          size: 20,
          color: color ?? AppColors.text,
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppFonts.beVietnam(
        size: 13,
        weight: FontWeight.w700,
        color: AppColors.text,
      ),
    );
  }
}

InputDecoration _inputDecoration(
  String hint, {
  IconData? icon,
  double radius = 14,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: AppFonts.beVietnam(color: AppColors.hintText),
    prefixIcon: icon == null
        ? null
        : AppHeroIconData(icon, color: AppColors.hintText),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderSide: BorderSide.none,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}
