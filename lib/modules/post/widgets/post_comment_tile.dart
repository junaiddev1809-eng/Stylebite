import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/verified_flag.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../models/post_comment_model.dart';
import '../../profile/utils/profile_open_helper.dart';

class PostCommentTile extends StatelessWidget {
  const PostCommentTile({
    super.key,
    required this.comment,
    this.depth = 0,
    this.onReply,
    this.rootCommentId,
    this.onLikeComment,
    this.onLikeReply,
    this.onReportComment,
    this.onReportReply,
    this.onDeleteComment,
    this.onDeleteReply,
    this.isCommentLikeLoading = false,
    this.isReplyLikeLoading,
  });

  final PostCommentModel comment;
  final int depth;
  final String? rootCommentId;
  final void Function(PostCommentModel comment, String rootCommentId)? onReply;
  final ValueChanged<String>? onLikeComment;
  final ValueChanged<String>? onLikeReply;
  final ValueChanged<String>? onReportComment;
  final ValueChanged<String>? onReportReply;
  final ValueChanged<String>? onDeleteComment;
  final ValueChanged<String>? onDeleteReply;
  final bool isCommentLikeLoading;
  final bool Function(String replyId)? isReplyLikeLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 24.0, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _openCommentProfile,
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: comment.hasAvatar
                      ? NetworkImage(comment.avatar)
                      : null,
                  child: comment.hasAvatar
                      ? null
                      : const AppHeroIconData(Icons.person_rounded, size: 16),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onLongPress: _handleLongPress,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F0EF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Obx(() {
                      VerifiedBadgeCache.revision.value;
                      return RichText(
                        text: TextSpan(
                          children: AppVerifiedName.inlineSpans(
                            name: comment.displayName,
                            username: comment.user,
                            isVerified: comment.isVerifiedBadge,
                            style: AppFonts.beVietnam(
                              size: 13,
                              weight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                            suffix: ' ${comment.text}',
                            suffixStyle: AppFonts.beVietnam(
                              size: 13,
                              weight: FontWeight.w500,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 42, top: 4),
            child: Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  comment.time,
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.hintText,
                  ),
                ),
                Text(
                  '${comment.likes} likes',
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w600,
                    color: AppColors.hintText,
                  ),
                ),
                InkWell(
                  onTap: comment.isLocalPending
                      ? null
                      : _isReply
                      ? () => onLikeReply?.call(comment.id)
                      : () => onLikeComment?.call(comment.id),
                  child: isLoading
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          comment.isLiked ? 'Unlike' : 'Like',
                          style: AppFonts.beVietnam(
                            size: 11,
                            weight: FontWeight.w700,
                            color: comment.isLocalPending
                                ? AppColors.hintText.withValues(alpha: 0.7)
                                : AppColors.primary,
                          ),
                        ),
                ),
                InkWell(
                  onTap: comment.isLocalPending
                      ? null
                      : () => onReply?.call(comment, _resolvedRootCommentId),
                  child: Text(
                    'Reply',
                    style: AppFonts.beVietnam(
                      size: 11,
                      weight: FontWeight.w700,
                      color: comment.isLocalPending
                          ? AppColors.hintText.withValues(alpha: 0.7)
                          : AppColors.primary,
                    ),
                  ),
                ),
                if (comment.isOwnedByViewer)
                  InkWell(
                    onTap: _requestDelete,
                    child: Text(
                      'Delete',
                      style: AppFonts.beVietnam(
                        size: 11,
                        weight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: comment.replies
                    .map(
                      (reply) => PostCommentTile(
                        comment: reply,
                        depth: depth + 1,
                        rootCommentId: _resolvedRootCommentId,
                        onReply: onReply,
                        onLikeComment: onLikeComment,
                        onLikeReply: onLikeReply,
                        onReportComment: onReportComment,
                        onReportReply: onReportReply,
                        onDeleteComment: onDeleteComment,
                        onDeleteReply: onDeleteReply,
                        isCommentLikeLoading: isCommentLikeLoading,
                        isReplyLikeLoading: isReplyLikeLoading,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }

  void _openCommentProfile() {
    final username = comment.user.trim().replaceFirst(RegExp(r'^@'), '');
    if (username.isEmpty) {
      return;
    }
    ProfileOpenHelper.open(
      username: username,
      avatarUrl: comment.avatar,
    );
  }

  void _handleLongPress() {
    if (comment.isOwnedByViewer) {
      _requestDelete();
      return;
    }
    if (comment.isLocalPending) {
      return;
    }
    if (_isReply) {
      onReportReply?.call(comment.id);
    } else {
      onReportComment?.call(comment.id);
    }
  }

  void _requestDelete() {
    if (_isReply) {
      onDeleteReply?.call(comment.id);
    } else {
      onDeleteComment?.call(comment.id);
    }
  }

  bool get _isReply =>
      rootCommentId != null && comment.id != _resolvedRootCommentId;

  String get _resolvedRootCommentId => rootCommentId ?? comment.id;

  bool get isLoading => _isReply
      ? (isReplyLikeLoading?.call(comment.id) ?? false)
      : isCommentLikeLoading;
}
