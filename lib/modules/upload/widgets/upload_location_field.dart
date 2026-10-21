import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../controllers/upload_controller.dart';

class UploadLocationField extends StatelessWidget {
  const UploadLocationField({
    super.key,
    required this.controller,
    required this.inputDecoration,
    this.onOpenMap,
  });

  final UploadController controller;
  final InputDecoration Function(
    String hint, {
    IconData? icon,
    double radius,
    Widget? suffix,
  })
  inputDecoration;
  final VoidCallback? onOpenMap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final query = controller.locationQuery.value.trim();
      final suggestions = controller.locationSuggestions;
      final fetching = controller.isFetchingLocation.value;
      final searching = controller.isSearchingLocations.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller.locationController,
            onTap: () {
              if (controller.locationController.text.trim().isEmpty) {
                controller.onLocationQueryChanged('');
              }
            },
            onChanged: controller.onLocationQueryChanged,
            textInputAction: TextInputAction.search,
            scrollPhysics: const NeverScrollableScrollPhysics(),
            style: AppFonts.beVietnam(weight: FontWeight.w600),
            decoration: inputDecoration(
              'Search a restaurant or a place',
              icon: Icons.location_on_rounded,
              radius: 16,
              suffix: SizedBox(
                width: query.isNotEmpty ? 144 : 96,
                child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (query.isNotEmpty)
                    IconButton(
                      tooltip: 'Clear location',
                      onPressed: controller.clearLocation,
                      icon: const AppHeroIconData(
                        Icons.close_rounded,
                        color: AppColors.hintText,
                        size: 18,
                      ),
                    ),
                  IconButton(
                    tooltip: 'Use current location',
                    onPressed: fetching
                        ? null
                        : controller.fetchCurrentLocation,
                    icon: fetching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const AppHeroIconData(
                            Icons.my_location_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                  ),
                  if (onOpenMap != null)
                    IconButton(
                      tooltip: 'Pick on map',
                      onPressed: onOpenMap,
                      icon: const AppHeroIconData(
                        Icons.map_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                ],
              ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              searching && suggestions.isEmpty
                  ? 'Looking up nearby restaurants and places...'
                  : 'Type a restaurant name for nearby matches, or any place.',
              style: AppFonts.beVietnam(
                size: 11,
                weight: FontWeight.w500,
                color: AppColors.hintText,
              ),
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: SizedBox(
                height: (suggestions.length * 68.0).clamp(68, 320),
                child: ListView.separated(
                physics: const ClampingScrollPhysics(),
                itemCount: suggestions.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                ),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  final title = suggestion.title.trim().isNotEmpty
                      ? suggestion.title.trim()
                      : suggestion.label;
                  final subtitle = suggestion.subtitle.trim();
                  return ListTile(
                    dense: true,
                    leading: AppHeroIconData(
                      suggestion.isRestaurant
                          ? Icons.storefront_rounded
                          : Icons.place_outlined,
                      size: 18,
                      color: AppColors.hintText,
                    ),
                    title: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    subtitle: subtitle.isEmpty
                        ? null
                        : Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppFonts.beVietnam(
                              size: 11,
                              weight: FontWeight.w500,
                              color: AppColors.hintText,
                            ),
                          ),
                    onTap: () => controller.selectLocationSuggestion(suggestion),
                  );
                },
              ),
              ),
            ),
          ],
        ],
      );
    });
  }
}
