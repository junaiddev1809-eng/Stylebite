import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_media_source_sheet.dart';
import '../../SelectLocationScreen/select_location_screen.dart';
import '../controllers/upload_controller.dart';
import '../models/upload_post_model.dart';
import '../widgets/upload_food_ratings.dart';
import '../widgets/upload_location_field.dart';
import '../widgets/upload_media_preview.dart';
import '../widgets/upload_post_type_selector.dart';
import '../widgets/upload_visibility_selector.dart';
import '../../post/utils/hashtag_caption_limit.dart';
import '../../profile/controllers/profile_controller.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late final UploadController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<UploadController>()
        ? Get.find<UploadController>()
        : Get.put(UploadController());
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(controller: _controller)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 130),
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
                      UploadMediaPreview(onPick: _pickMedia),
                      const SizedBox(height: 14),
                      _FieldLabel('Caption'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _controller.captionController,
                        maxLines: 5,
                        inputFormatters: const [MaxHashtagInputFormatter()],
                        scrollPhysics: const NeverScrollableScrollPhysics(),
                        style: AppFonts.beVietnam(),
                        decoration: _inputDecoration(
                          _controller.captionHint,
                          radius: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _FieldLabel('Location'),
                      const SizedBox(height: 8),
                      UploadLocationField(
                        controller: _controller,
                        inputDecoration: _inputDecoration,
                        onOpenMap: () {
                          final lat = _controller.latitude;
                          final lng = _controller.longitude;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SelectLocationScreen(
                                addressLocation:
                                    lat != null && lng != null
                                    ? LatLng(lat, lng)
                                    : null,
                                initialQuery: _controller
                                    .locationController
                                    .text
                                    .trim(),
                                onConfirmLocation: (value, location) {
                                  final label = value.trim();
                                  if (label.isEmpty ||
                                      label.toLowerCase() ==
                                          'unknown location') {
                                    return;
                                  }
                                  _controller.setLocation(
                                    label,
                                    location.latitude,
                                    location.longitude,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      _FieldLabel('Visibility'),
                      const SizedBox(height: 8),
                      Obx(
                        () => UploadVisibilitySelector(
                          selected: _controller.selectedVisibility.value,
                          onChanged: _controller.setVisibility,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_controller.selectedType.value == UploadPostType.food)
                        _foodFields(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [AppColors.primary, AppColors.secondary],
                            ),
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _controller.submitPost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            icon: Text(
                              _controller.shareButtonLabel,
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
                    onChanged: (_) => _controller.refreshFoodPreview(),
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                    style: AppFonts.beVietnam(weight: FontWeight.w600),
                    decoration: _inputDecoration(
                      'BBQ Tonight',
                      icon: Icons.local_dining_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Restaurant'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller.restaurantController,
                    onChanged: (_) => _controller.refreshFoodPreview(),
                    scrollPhysics: const NeverScrollableScrollPhysics(),
                    style: AppFonts.beVietnam(weight: FontWeight.w600),
                    decoration: _inputDecoration(
                      'karachi_eats',
                      icon: Icons.storefront_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        UploadFoodRatings(
          items: _controller.ratingItems,
          values: _controller.foodRatings,
          onChanged: _controller.setFoodRating,
          previewTitle: _controller.foodPreviewTitle,
          previewLocation: _controller.foodPreviewLocation,
          overall: _controller.overallFoodRating,
        ),
      ],
    );
  }

  Future<void> _pickMedia() async {
    final source = await showMediaSourceSheet(context);
    if (source == null) {
      return;
    }

    await _controller.pickMedia(fromCamera: source == MediaSourceChoice.camera);
  }

  InputDecoration _inputDecoration(
    String hint, {
    IconData? icon,
    double radius = 999,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppFonts.beVietnam(
        size: 13,
        weight: FontWeight.w500,
        color: const Color(0xFF9A8F8A),
      ),
      prefixIcon: icon == null
          ? null
          : AppHeroIconData(icon,
              color: const Color(0xFF9A8F8A),
              size: 18,
            ),
      suffixIcon: suffix,
      suffixIconConstraints: suffix == null
          ? null
          : const BoxConstraints(minWidth: 0, minHeight: 48),
      filled: true,
      fillColor: const Color(0xFFF3F0EF),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final UploadController controller;

  @override
  Widget build(BuildContext context) {
    final profileController = Get.isRegistered<ProfileController>()
        ? Get.find<ProfileController>()
        : Get.put(ProfileController());
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: AppColors.background.withValues(alpha: 0.7),
      child: Row(
        children: [
          Obx(
            () => CircleAvatar(
              radius: 20,
              backgroundImage:
                  profileController.avatarImageUrl.value.trim().isNotEmpty
                  ? NetworkImage(profileController.avatarImageUrl.value)
                  : null,
              child: profileController.avatarImageUrl.value.trim().isNotEmpty
                  ? null
                  : const AppHeroIconData(Icons.person_rounded),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Create Post',
            style: AppFonts.plusJakarta(
              size: 18,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const Spacer(),
          // const AppHeroIconData(Icons.photo_library_outlined,
          //   color: AppColors.hintText,
          // ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        label.toUpperCase(),
        style: AppFonts.beVietnam(
          size: 10,
          weight: FontWeight.w700,
          color: AppColors.hintText,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
