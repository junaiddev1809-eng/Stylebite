import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../controllers/style_rating_controller.dart';

class StyleRatingSheet extends StatelessWidget {
  const StyleRatingSheet({super.key, required this.username});

  final String username;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      StyleRatingController(username: username),
      tag: '${username}_style_rating',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E0DF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Style Rating Overview',
            style: AppFonts.plusJakarta(
              size: 22,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your performance based on community vibes',
            style: AppFonts.beVietnam(
              size: 14,
              weight: FontWeight.w500,
              color: AppColors.hintText,
            ),
          ),
          const SizedBox(height: 32),
          Obx(() {
            if (controller.isLoading.value) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (controller.hasError.value) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.hintText, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      controller.errorMessage.value,
                      textAlign: TextAlign.center,
                      style: AppFonts.beVietnam(
                        size: 14,
                        weight: FontWeight.w500,
                        color: AppColors.hintText,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: controller.fetchRatingDistribution,
                      child: const Text('Try Again', style: TextStyle(color: AppColors.primary)),
                    ),
                  ],
                ),
              );
            }

            final data = controller.ratingData.value;
            if (data == null || data.totalRatings == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Text(
                  'No ratings yet.',
                  style: AppFonts.beVietnam(
                    size: 16,
                    weight: FontWeight.w600,
                    color: AppColors.hintText,
                  ),
                ),
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  data.averageRating.toStringAsFixed(1),
                                  style: AppFonts.plusJakarta(
                                    size: 64,
                                    weight: FontWeight.w800,
                                    color: AppColors.text,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 10),
                                  child: Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFD166),
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Average Style Rating',
                            style: AppFonts.beVietnam(
                              size: 14,
                              weight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            'From ${_formatTotal(data.totalRatings)} reviewers',
                            style: AppFonts.beVietnam(
                              size: 12,
                              weight: FontWeight.w500,
                              color: AppColors.hintText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: List.generate(5, (index) {
                          final starCount = 5 - index;
                          final percentage = controller.getPercentage(starCount);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _SmallDistributionRow(
                              starCount: starCount,
                              percentage: percentage,
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _QuickStat(
                        label: 'Total Reviews',
                        value: _formatTotal(data.totalRatings),
                      ),
                      Container(width: 1, height: 30, color: const Color(0xFFE5E0DF)),
                      _QuickStat(
                        label: 'Positive Feedback',
                        value: '${(controller.getPercentage(5) * 100 + controller.getPercentage(4) * 100).toInt()}%',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _formatTotal(int value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}

class _SmallDistributionRow extends StatelessWidget {
  const _SmallDistributionRow({required this.starCount, required this.percentage});

  final int starCount;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          starCount.toString(),
          style: AppFonts.beVietnam(
            size: 11,
            weight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F0EF),
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppFonts.plusJakarta(
            size: 18,
            weight: FontWeight.w800,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppFonts.beVietnam(
            size: 12,
            weight: FontWeight.w600,
            color: AppColors.hintText,
          ),
        ),
      ],
    );
  }
}
