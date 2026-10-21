import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../home/models/home_post_model.dart';
import '../../SelectLocationScreen/restaurant_map_screen.dart';
import '../controllers/restaurant_review_store.dart';
import '../models/restaurant_review_model.dart';

class FoodShowcaseCard extends StatelessWidget {
  const FoodShowcaseCard({super.key, required this.post});

  final HomePostModel post;

  @override
  Widget build(BuildContext context) {
    final title = post.dishName.trim().isNotEmpty
        ? post.dishName.trim()
        : 'Food Post';
    final subtitle = post.restaurant.trim().isNotEmpty
        ? post.restaurant.trim()
        : 'Dining experience';
    final location = post.displayLocation;
    final store = RestaurantReviewStore.instance;

    return Obx(() {
      final summary = store.summaryFor(post.restaurant);
      final overall = _communityOverall(post, summary);
      final reviewCount = summary?.count ?? 0;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF4EA), Color(0xFFF7EFEA)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE0C8)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE3C6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const AppHeroIconData(
                Icons.restaurant_rounded,
                color: Color(0xFFB85B24),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.plusJakarta(
                      size: 17,
                      weight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  InkWell(
                    onTap: post.restaurant.trim().isEmpty
                        ? null
                        : () => RestaurantMapScreen.openForPost(post),
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w700,
                        color: const Color(0xFF8E4B1C),
                      ).copyWith(
                        decoration: post.restaurant.trim().isEmpty
                            ? TextDecoration.none
                            : TextDecoration.underline,
                        decorationColor: const Color(0xFF8E4B1C),
                      ),
                    ),
                  ),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => RestaurantMapScreen.openForPost(post),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          const AppHeroIconData(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.beVietnam(
                                size: 12,
                                weight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const AppHeroIconData(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ] else if (post.restaurant.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => RestaurantMapScreen.openForPost(post),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          const AppHeroIconData(
                            Icons.map_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'View on map',
                            style: AppFonts.beVietnam(
                              size: 12,
                              weight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE7A8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const AppHeroIconData(
                        Icons.star_rounded,
                        size: 16,
                        color: Color(0xFF7A2E00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatRating(overall),
                        style: AppFonts.beVietnam(
                          size: 12,
                          weight: FontWeight.w800,
                          color: const Color(0xFF7A2E00),
                        ),
                      ),
                    ],
                  ),
                  if (reviewCount > 1) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$reviewCount reviews',
                      style: AppFonts.beVietnam(
                        size: 9,
                        weight: FontWeight.w700,
                        color: const Color(0xFF7A2E00),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class FoodRatingsCard extends StatelessWidget {
  const FoodRatingsCard({
    super.key,
    required this.post,
    this.backgroundColor = const Color(0xFFF3F0EF),
    this.showAllMetrics = false,
  });

  final HomePostModel post;
  final Color backgroundColor;
  final bool showAllMetrics;

  @override
  Widget build(BuildContext context) {
    final store = RestaurantReviewStore.instance;

    return Obx(() {
      final summary = store.summaryFor(post.restaurant);
      final source = <({String label, double? raw, Color color})>[
        (
          label: 'Food',
          raw: _metricValue(summary?.food, post.foodRating),
          color: const Color(0xFFF59E0B),
        ),
        (
          label: 'Service',
          raw: _metricValue(summary?.service, post.serviceRating),
          color: const Color(0xFFFF7A59),
        ),
        (
          label: 'Staff',
          raw: _metricValue(summary?.staff, post.staffRating),
          color: const Color(0xFFFF4D6D),
        ),
        (
          label: 'Ambience',
          raw: _metricValue(summary?.ambience, post.ambienceRating),
          color: const Color(0xFF8B5CF6),
        ),
      ];
      final ratings = source
          .where((item) => showAllMetrics || item.raw != null)
          .map(
            (item) => (
              label: item.label,
              value: item.raw ?? 0,
              color: item.color,
            ),
          )
          .toList(growable: false);

      if (ratings.isEmpty) {
        return const SizedBox.shrink();
      }

      final reviewCount = summary?.count ?? 0;

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reviewCount > 1 ? 'Community ratings' : 'Taste Breakdown',
                    style: AppFonts.plusJakarta(
                      size: 16,
                      weight: FontWeight.w800,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  reviewCount > 1
                      ? '$reviewCount reviews'
                      : '${ratings.length} metrics',
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.hintText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...ratings.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.label,
                            style: AppFonts.beVietnam(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        Text(
                          _formatRating(item.value),
                          style: AppFonts.plusJakarta(
                            size: 13,
                            weight: FontWeight.w800,
                            color: item.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 9,
                        value: (item.value.clamp(0, 5)) / 5,
                        backgroundColor: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(item.color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

double _communityOverall(HomePostModel post, RestaurantRatingSummary? summary) {
  if (summary != null && summary.hasRatings) {
    return summary.overall;
  }
  final average = <double>[
    if (post.foodRating != null) post.foodRating!,
    if (post.serviceRating != null) post.serviceRating!,
    if (post.staffRating != null) post.staffRating!,
    if (post.ambienceRating != null) post.ambienceRating!,
  ];
  if (average.isEmpty) {
    return post.displayRating;
  }
  return average.reduce((sum, item) => sum + item) / average.length;
}

double? _metricValue(double? community, double? original) {
  if (community != null && community > 0) {
    return community;
  }
  return original;
}

String _formatRating(double value) {
  return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
}
