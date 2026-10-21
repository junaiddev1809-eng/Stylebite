import 'package:flutter/material.dart';
import 'package:stylebite/core/widgets/app_hero_icon.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../home/models/home_post_model.dart';
import '../../reports/widgets/report_reason_sheet.dart';
import '../controllers/post_detail_controller.dart';
import '../widgets/comments_caption_header.dart';
import '../widgets/post_comment_tile.dart';
import '../widgets/post_options_sheet.dart';

class CommentsScreen extends StatefulWidget {
  const CommentsScreen({super.key, required this.post, required this.tag});

  final HomePostModel post;
  final String tag;

  static Future<void> show(
    BuildContext context, {
    required HomePostModel post,
    required String tag,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: CommentsScreen(post: post, tag: tag),
        );
      },
    );
  }

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  late final PostDetailController _controller;
  _ReplyTarget? _replyTarget;

  void _dismissKeyboard() {
    if (!_inputFocusNode.hasFocus) {
      return;
    }
    _inputFocusNode.unfocus();
  }

  @override
  void initState() {
    super.initState();
    _controller = Get.find<PostDetailController>(tag: widget.tag);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.comments.isEmpty &&
          !_controller.isCommentsLoading.value) {
        _controller.fetchComments(reset: true);
      }
    });
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }

    _dismissKeyboard();

    if (_replyTarget == null) {
      await _controller.submitComment(text);
    } else {
      await _controller.submitReply(
        commentId: _replyTarget!.commentId,
        parentReplyId: _replyTarget!.parentReplyId,
        text: text,
      );
    }
    _inputController.clear();
    if (mounted) {
      setState(() {
        _replyTarget = null;
      });
    }
  }

  Future<void> _reportComment(String id, {required bool isReply}) async {
    final result = await showReportReasonSheet(
      context,
      title: isReply ? 'Report reply' : 'Report comment',
    );
    if (result == null) {
      return;
    }
    if (isReply) {
      await _controller.reportReply(id, result.reasonCode, result.details);
    } else {
      await _controller.reportComment(id, result.reasonCode, result.details);
    }
  }

  Future<void> _deleteComment(String id, {required bool isReply}) async {
    final confirmed = await showDeleteCommentConfirmationSheet(
      context,
      isReply: isReply,
    );
    if (confirmed != true) {
      return;
    }
    if (isReply) {
      await _controller.deleteReply(id);
    } else {
      await _controller.deleteComment(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissKeyboard,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7E2E0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Comments',
                        style: AppFonts.plusJakarta(
                          size: 20,
                          weight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: AppBackNavigation.handleBack,
                        icon: const AppHeroIconData(Icons.close_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
            Expanded(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) => _dismissKeyboard(),
                child: Obx(() {
                final comments = _controller.comments;
                final loadingComments =
                    _controller.isCommentsLoading.value && comments.isEmpty;
                final extra = _controller.hasMoreComments.value ? 1 : 0;
                return ListView.builder(
                  controller: _controller.commentsScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: 1 +
                      (loadingComments || comments.isEmpty
                          ? 1
                          : comments.length) +
                      extra,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return CommentsCaptionHeader(
                        handle: widget.post.username.startsWith('@')
                            ? widget.post.username
                            : '@${widget.post.username}',
                        caption: widget.post.caption,
                        avatarUrl: widget.post.avatarUrl,
                        username: widget.post.profileUsername,
                        isVerified: widget.post.isVerifiedBadge,
                      );
                    }
                    if (loadingComments) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (comments.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No comments yet',
                            style: AppFonts.beVietnam(
                              size: 14,
                              weight: FontWeight.w500,
                              color: AppColors.hintText,
                            ),
                          ),
                        ),
                      );
                    }
                    final commentIndex = index - 1;
                    if (commentIndex >= comments.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    _controller.maybeLoadMoreComments(commentIndex);
                    final comment = comments[commentIndex];
                    return PostCommentTile(
                      comment: comment,
                      isCommentLikeLoading: _controller.commentLikeLoadingIds
                          .contains(comment.id),
                      isReplyLikeLoading: (replyId) =>
                          _controller.replyLikeLoadingIds.contains(replyId),
                      onLikeComment: _controller.likeComment,
                      onLikeReply: _controller.likeReply,
                      onReportComment: (commentId) =>
                          _reportComment(commentId, isReply: false),
                      onReportReply: (replyId) =>
                          _reportComment(replyId, isReply: true),
                      onDeleteComment: (commentId) =>
                          _deleteComment(commentId, isReply: false),
                      onDeleteReply: (replyId) =>
                          _deleteComment(replyId, isReply: true),
                      onReply: (selectedComment, rootCommentId) {
                        _inputController.text = '@${selectedComment.user} ';
                        _inputController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _inputController.text.length),
                        );
                        setState(() {
                          _replyTarget = _ReplyTarget(
                            commentId: rootCommentId,
                            parentReplyId:
                                selectedComment.commentId == rootCommentId
                                ? null
                                : selectedComment.id,
                            username: selectedComment.user,
                            isVerified: selectedComment.isVerifiedBadge,
                          );
                        });
                        _inputFocusNode.requestFocus();
                      },
                    );
                  },
                );
              }),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                10 + MediaQuery.of(context).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_replyTarget != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6, left: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: AppVerifiedName(
                                    name: 'Replying to @${_replyTarget!.username}',
                                    username: _replyTarget!.username,
                                    isVerified: _replyTarget!.isVerified,
                                    badgeSize: 13,
                                    style: AppFonts.beVietnam(
                                      size: 12,
                                      weight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _replyTarget = null;
                                    });
                                    _inputController.clear();
                                  },
                                  child: Text(
                                    'Cancel',
                                    style: AppFonts.beVietnam(
                                      size: 11,
                                      weight: FontWeight.w700,
                                      color: AppColors.hintText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        TextField(
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.send,
                          onTap: () => _inputFocusNode.requestFocus(),
                          onSubmitted: (_) => _addComment(),
                          decoration: InputDecoration(
                            hintText: _replyTarget == null
                                ? 'Write a comment...'
                                : 'Write a reply...',
                            hintStyle: AppFonts.beVietnam(
                              size: 13,
                              weight: FontWeight.w500,
                              color: AppColors.hintText,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF3F0EF),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Obx(
                    () => InkWell(
                      onTap: _controller.isSubmittingComment.value
                          ? null
                          : _addComment,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [AppColors.primary, AppColors.secondary],
                          ),
                        ),
                        child: _controller.isSubmittingComment.value
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const AppHeroIconData(
                                Icons.send_rounded,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyTarget {
  const _ReplyTarget({
    required this.commentId,
    required this.parentReplyId,
    required this.username,
    this.isVerified = false,
  });

  final String commentId;
  final String? parentReplyId;
  final String username;
  final bool isVerified;
}
