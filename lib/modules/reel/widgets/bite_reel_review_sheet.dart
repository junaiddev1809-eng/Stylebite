import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_helper.dart';
import '../../home/models/home_post_model.dart';
import '../../post/controllers/restaurant_review_store.dart';
import '../../post/utils/post_detail_open_helper.dart';
import '../../post/widgets/food_post_details.dart';
import '../../post/widgets/restaurant_review_sheet.dart';
import '../controllers/reel_controller.dart';
import '../models/reel_item_model.dart';

class BiteReelReviewSheet {
  const BiteReelReviewSheet._();

  static Future<void> open({
    required BuildContext context,
    required ReelController controller,
    required ReelItemModel reel,
  }) async {
    controller.setCurrentVideoPaused(reel.id, true);
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (context) {
          return _BiteReelReviewSheetBody(
            controller: controller,
            reel: reel,
          );
        },
      );
    } finally {
      controller.setCurrentVideoPaused(reel.id, false);
    }
  }
}

class _BiteReelReviewSheetBody extends StatefulWidget {
  const _BiteReelReviewSheetBody({
    required this.controller,
    required this.reel,
  });

  final ReelController controller;
  final ReelItemModel reel;

  @override
  State<_BiteReelReviewSheetBody> createState() =>
      _BiteReelReviewSheetBodyState();
}

class _BiteReelReviewSheetBodyState extends State<_BiteReelReviewSheetBody> {
  late HomePostModel _post;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    _post = widget.reel.toHomePost();
    _prepare();
  }

  bool get _hasCompleteFoodDetails {
    return _post.hasFoodRatings &&
        (_post.dishName.trim().isNotEmpty ||
            _post.restaurant.trim().isNotEmpty);
  }

  Future<void> _prepare() async {
    if (!_hasCompleteFoodDetails) {
      setState(() => _loading = true);
      final detail = await PostDetailOpenHelper.fetchPost(widget.reel.id);
      if (!mounted) {
        return;
      }
      if (detail == null) {
        setState(() => _loading = false);
        errorSnackBar(message: 'Could not load food reviews.');
        return;
      }
      setState(() {
        _post = detail;
        _loading = false;
      });
    }

    await RestaurantReviewStore.instance.ensureRestaurantLoaded(_post);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(top: height * 0.5),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE4DDDA),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _post.restaurant.trim().isNotEmpty
                          ? _post.restaurant.trim()
                          : 'Restaurant reviews',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.plusJakarta(
                        size: 17,
                        weight: FontWeight.w800,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      children: [
                        FoodShowcaseCard(post: _post),
                        const SizedBox(height: 10),
                        FoodRatingsCard(
                          post: _post,
                          backgroundColor: const Color(0xFFF7F3F1),
                          showAllMetrics: true,
                        ),
                        RestaurantReviewAction(post: _post),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
