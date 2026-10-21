import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';

class PostActionBar extends StatelessWidget {
  const PostActionBar({
    super.key,
    required this.likes,
    required this.comments,
    required this.isSaved,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    this.isLikeLoading = false,
    this.isCommentLoading = false,
    this.isShareLoading = false,
    this.isSaveLoading = false,
    this.showCommentAction = true,
    this.showLikeAction = true,
    this.showReviewsAction = false,
    this.reviewsExpanded = false,
    this.isReviewsLoading = false,
    this.onReviews,
    this.showRatingSelector = false,
    this.selectedRating = 0,
    this.onRatingSelected,
    this.isVoteLoading = false,
  });

  final String likes;
  final String comments;
  final bool isSaved;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final Future<void> Function() onShare;
  final VoidCallback onSave;
  final bool isLikeLoading;
  final bool isCommentLoading;
  final bool isShareLoading;
  final bool isSaveLoading;
  final bool showCommentAction;
  final bool showLikeAction;
  final bool showReviewsAction;
  final bool reviewsExpanded;
  final bool isReviewsLoading;
  final VoidCallback? onReviews;
  final bool showRatingSelector;
  final int selectedRating;
  final ValueChanged<int>? onRatingSelected;
  final bool isVoteLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showLikeAction) ...[
          _action(
            heroIcon: HeroIcons.heart,
            style: isLiked ? HeroIconStyle.solid : HeroIconStyle.outline,
            label: likes,
            color: isLiked ? AppColors.primary : AppColors.text,
            onTap: onLike,
            isLoading: isLikeLoading,
          ),
          const SizedBox(width: 14),
        ],
        if (showCommentAction) ...[
          _action(
            heroIcon: HeroIcons.chatBubbleOvalLeftEllipsis,
            style: HeroIconStyle.outline,
            label: comments,
            onTap: onComment,
            isLoading: isCommentLoading,
          ),
          const SizedBox(width: 14),
        ],
        InkWell(
          onTap: isShareLoading ? null : () async => onShare(),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: isShareLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const HeroIcon(
                    HeroIcons.share,
                    style: HeroIconStyle.outline,
                    size: 20,
                    color: AppColors.text,
                  ),
          ),
        ),
        if (showRatingSelector && onRatingSelected != null)
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: _ratingSelector(),
              ),
            ),
          )
        else
          const Spacer(),
        if (showReviewsAction && onReviews != null) ...[
          _reviewsButton(),
          const SizedBox(width: 6),
        ],
        isSaveLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: Padding(
                  padding: EdgeInsets.all(2),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                onPressed: onSave,
                icon: HeroIcon(
                  HeroIcons.bookmark,
                  style: isSaved ? HeroIconStyle.solid : HeroIconStyle.outline,
                  color: AppColors.text,
                ),
              ),
      ],
    );
  }

  Widget _action({
    required HeroIcons heroIcon,
    required HeroIconStyle style,
    String? label,
    Color color = AppColors.text,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  HeroIcon(
                    heroIcon,
                    style: style,
                    size: 20,
                    color: isLoading ? color.withValues(alpha: 0.75) : color,
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    ),
                ],
              ),
            ),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ratingSelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final value = index + 1;
        final isSelected = selectedRating == value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: GestureDetector(
            onTap: () => onRatingSelected!(value),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : const Color(0xFFF6F1EF),
              ),
              child: Text(
                '$value',
                style: AppFonts.beVietnam(
                  size: 11,
                  weight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.text,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _reviewsButton() {
    return InkWell(
      onTap: isReviewsLoading ? null : onReviews,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: reviewsExpanded
              ? AppColors.primary
              : const Color(0xFFE9E3E1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: isReviewsLoading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: reviewsExpanded ? Colors.white : AppColors.text,
                ),
              )
            : Text(
                'Reviews',
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w700,
                  color: reviewsExpanded ? Colors.white : AppColors.text,
                ),
              ),
      ),
    );
  }
}
