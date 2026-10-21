import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/local_storage.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../home/models/home_post_model.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../controllers/restaurant_review_store.dart';
import '../models/restaurant_review_model.dart';

class RestaurantReviewAction extends StatefulWidget {
  const RestaurantReviewAction({super.key, required this.post});

  final HomePostModel post;

  @override
  State<RestaurantReviewAction> createState() => _RestaurantReviewActionState();
}

class _RestaurantReviewActionState extends State<RestaurantReviewAction> {
  static const _previewLimit = 3;

  bool _showReviewers = false;

  @override
  Widget build(BuildContext context) {
    if (widget.post.restaurant.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final store = RestaurantReviewStore.instance;
    final username = LocalStorage.getUsername()?.trim() ?? '';

    return Obx(() {
      final reviews = store.reviewsFor(widget.post.restaurant);
      final mine = store.myReviewFor(widget.post.restaurant);
      final canReview = username.isNotEmpty;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reviews.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ReviewersSummary(
              reviews: reviews,
              expanded: _showReviewers,
              onToggle: () => setState(() => _showReviewers = !_showReviewers),
              onSeeAll: () => _RestaurantReviewersSheet.open(
                context,
                restaurant: widget.post.restaurant,
                reviews: reviews,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _showReviewers
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        children: [
                          ...reviews
                              .take(_previewLimit)
                              .map((review) => _ReviewRow(review: review)),
                          if (reviews.length > _previewLimit)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => _RestaurantReviewersSheet.open(
                                  context,
                                  restaurant: widget.post.restaurant,
                                  reviews: reviews,
                                ),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'See all ${reviews.length} reviewers',
                                  style: AppFonts.beVietnam(
                                    size: 12,
                                    weight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
          if (canReview) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    RestaurantReviewSheet.open(context, widget.post),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFFFE3C6),
                  foregroundColor: const Color(0xFF8E4B1C),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: AppHeroIconData(
                  mine == null ? Icons.rate_review_rounded : Icons.edit_rounded,
                  size: 18,
                  color: const Color(0xFF8E4B1C),
                ),
                label: Text(
                  mine == null ? 'Add your review' : 'Update your review',
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight: FontWeight.w800,
                    color: const Color(0xFF8E4B1C),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _ReviewersSummary extends StatelessWidget {
  const _ReviewersSummary({
    required this.reviews,
    required this.expanded,
    required this.onToggle,
    required this.onSeeAll,
  });

  final List<RestaurantReview> reviews;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F4F2),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _ReviewerAvatars(
              reviews: reviews,
              onTapReviewer: (review) => _openReviewerProfile(review.username),
              onTapOverflow: onSeeAll,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reviews.length == 1
                          ? '1 reviewer'
                          : '${reviews.length} reviewers',
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _summaryLine(reviews),
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
            ),
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      expanded ? 'Hide' : 'Show',
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    AppHeroIconData(
                      expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _summaryLine(List<RestaurantReview> reviews) {
    if (reviews.isEmpty) {
      return '';
    }
    final first = _handle(reviews.first.username);
    if (reviews.length == 1) {
      return first;
    }
    if (reviews.length == 2) {
      return '$first, ${_handle(reviews[1].username)}';
    }
    return '$first and ${reviews.length - 1} others';
  }
}

class _ReviewerAvatars extends StatelessWidget {
  const _ReviewerAvatars({
    required this.reviews,
    required this.onTapReviewer,
    required this.onTapOverflow,
  });

  final List<RestaurantReview> reviews;
  final ValueChanged<RestaurantReview> onTapReviewer;
  final VoidCallback onTapOverflow;

  @override
  Widget build(BuildContext context) {
    final shown = reviews.take(3).toList(growable: false);
    final extra = reviews.length - shown.length;
    final width = 28.0 + ((shown.length - 1) * 18) + (extra > 0 ? 18 : 0);

    return SizedBox(
      width: width,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 18,
              child: GestureDetector(
                onTap: () => onTapReviewer(shown[i]),
                child: _ReviewerAvatar(review: shown[i], size: 28),
              ),
            ),
          if (extra > 0)
            Positioned(
              left: shown.length * 18,
              child: GestureDetector(
                onTap: onTapOverflow,
                child: _InitialBubble(
                  label: extra > 9 ? '9+' : '+$extra',
                  color: const Color(0xFFD9D0CB),
                  textColor: AppColors.text,
                  size: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewerAvatar extends StatelessWidget {
  const _ReviewerAvatar({required this.review, this.size = 28});

  final RestaurantReview review;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (review.avatarUrl.trim().isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: ClipOval(
          child: AppCachedImage(
            imageUrl: review.avatarUrl,
            width: size,
            height: size,
            memCacheWidth: 84,
            memCacheHeight: 84,
          ),
        ),
      );
    }

    return _InitialBubble(
      label: _initial(review.username),
      color: _avatarColor(review.userKey.hashCode),
      size: size,
    );
  }
}

class _InitialBubble extends StatelessWidget {
  const _InitialBubble({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.size = 28,
  });

  final String label;
  final Color color;
  final Color textColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        label,
        style: AppFonts.beVietnam(
          size: label.length > 1 ? 8 : 11,
          weight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review, this.closeSheetFirst = false});

  final RestaurantReview review;
  final bool closeSheetFirst;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (closeSheetFirst) {
          Navigator.of(context).pop();
        }
        _openReviewerProfile(review.username);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _ReviewerAvatar(review: review, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _handle(review.username),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            const AppHeroIconData(
              Icons.star_rounded,
              size: 14,
              color: Color(0xFF7A2E00),
            ),
            const SizedBox(width: 3),
            Text(
              review.overall.toStringAsFixed(review.overall % 1 == 0 ? 0 : 1),
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w800,
                color: const Color(0xFF7A2E00),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantReviewersSheet {
  static Future<void> open(
    BuildContext context, {
    required String restaurant,
    required List<RestaurantReview> reviews,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final height = MediaQuery.sizeOf(context).height * 0.62;
        return SafeArea(
          top: false,
          child: SizedBox(
            height: height,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7E2E0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Reviewers',
                          style: AppFonts.plusJakarta(
                            size: 18,
                            weight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Text(
                        '${reviews.length}',
                        style: AppFonts.beVietnam(
                          size: 13,
                          weight: FontWeight.w700,
                          color: AppColors.hintText,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      restaurant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w500,
                        color: AppColors.hintText,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: reviews.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      return _ReviewRow(
                        review: reviews[index],
                        closeSheetFirst: true,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _openReviewerProfile(String username) {
  final cleaned = normalizeReviewUsername(username);
  if (cleaned.isEmpty) {
    return;
  }
  ProfileOpenHelper.open(username: cleaned);
}

String _handle(String username) {
  final trimmed = username.trim();
  if (trimmed.isEmpty) {
    return '@user';
  }
  return trimmed.startsWith('@') ? trimmed : '@$trimmed';
}

String _initial(String username) {
  final cleaned = username.trim().replaceFirst(RegExp(r'^@'), '');
  if (cleaned.isEmpty) {
    return '?';
  }
  return cleaned[0].toUpperCase();
}

Color _avatarColor(int seed) {
  const colors = <Color>[
    Color(0xFFB85B24),
    Color(0xFFFF7A59),
    Color(0xFF8B5CF6),
    Color(0xFFF59E0B),
    Color(0xFFFF4D6D),
  ];
  return colors[seed.abs() % colors.length];
}

class RestaurantReviewSheet {
  static Future<void> open(BuildContext context, HomePostModel post) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _RestaurantReviewSheetBody(post: post),
    );
  }
}

class _RestaurantReviewSheetBody extends StatefulWidget {
  const _RestaurantReviewSheetBody({required this.post});

  final HomePostModel post;

  @override
  State<_RestaurantReviewSheetBody> createState() =>
      _RestaurantReviewSheetBodyState();
}

class _RestaurantReviewSheetBodyState extends State<_RestaurantReviewSheetBody> {
  static const _items = <({String key, String label, Color color})>[
    (key: 'food', label: 'Food', color: Color(0xFFF59E0B)),
    (key: 'service', label: 'Service', color: Color(0xFFFF7A59)),
    (key: 'staff', label: 'Staff', color: Color(0xFFFF4D6D)),
    (key: 'ambience', label: 'Ambience', color: Color(0xFF8B5CF6)),
  ];

  late final Map<String, double> _values;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = RestaurantReviewStore.instance.myReviewFor(
      widget.post.restaurant,
    );
    _values = <String, double>{
      'food': _initial(existing?.food, widget.post.foodRating),
      'service': _initial(existing?.service, widget.post.serviceRating),
      'staff': _initial(existing?.staff, widget.post.staffRating),
      'ambience': _initial(existing?.ambience, widget.post.ambienceRating),
    };
  }

  double get _overall {
    final values = _values.values.toList(growable: false);
    return values.reduce((sum, item) => sum + item) / values.length;
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE7E2E0),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review ${widget.post.restaurant}',
                      style: AppFonts.plusJakarta(
                        size: 18,
                        weight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your ratings update the community average instantly.',
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w500,
                        color: AppColors.hintText,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE7A8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    const AppHeroIconData(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFF7A2E00),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _overall.toStringAsFixed(1),
                      style: AppFonts.beVietnam(
                        size: 12,
                        weight: FontWeight.w800,
                        color: const Color(0xFF7A2E00),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._items.map((item) {
            final value = _values[item.key] ?? 4;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 78,
                    child: Text(
                      item.label,
                      style: AppFonts.beVietnam(
                        size: 13,
                        weight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: value,
                      min: 1,
                      max: 5,
                      divisions: 8,
                      activeColor: item.color,
                      onChanged: _submitting
                          ? null
                          : (next) => setState(() => _values[item.key] = next),
                    ),
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
                      textAlign: TextAlign.right,
                      style: AppFonts.plusJakarta(
                        size: 13,
                        weight: FontWeight.w800,
                        color: item.color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Submit review',
                      style: AppFonts.beVietnam(
                        size: 14,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await RestaurantReviewStore.instance.submitReview(
        post: widget.post,
        food: _values['food'] ?? 4,
        service: _values['service'] ?? 4,
        staff: _values['staff'] ?? 4,
        ambience: _values['ambience'] ?? 4,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      successSnackBar(message: 'Community rating updated.');
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  double _initial(double? existing, double? fallback) {
    final value = existing ?? fallback ?? 4;
    return value.clamp(1, 5);
  }
}
