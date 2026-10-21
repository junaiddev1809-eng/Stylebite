import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_time_formatter.dart';
import '../../../core/widgets/app_cached_image.dart';
import '../../../core/widgets/app_hero_icon.dart';
import '../../../core/widgets/app_verified_badge.dart';
import '../../../core/widgets/states/app_error_state.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../../post/widgets/post_options_sheet.dart';
import '../../post/utils/in_app_share.dart';
import '../../post/utils/post_detail_open_helper.dart';
import '../../profile/utils/profile_open_helper.dart';
import '../../reports/widgets/report_reason_sheet.dart';
import '../controllers/chat_detail_controller.dart';
import '../models/chat_models.dart';
import '../widgets/chat_conversation_options_sheet.dart';
import '../widgets/chat_message_options_sheet.dart';

class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.username,
    required this.conversationId,
    this.initialIsMessagingStopped = false,
    this.initialIsBlockedByMe = false,
    this.initialIsBlockedByOther = false,
  });

  final String username;
  final int conversationId;
  final bool initialIsMessagingStopped;
  final bool initialIsBlockedByMe;
  final bool initialIsBlockedByOther;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  late final String _tag;
  late final ChatDetailController _controller;

  @override
  void initState() {
    super.initState();
    _tag = '${ChatDetailScreen}_${widget.username}_${widget.conversationId}';
    _controller = Get.put(
      ChatDetailController(
        username: widget.username,
        conversationId: widget.conversationId,
        initialIsMessagingStopped: widget.initialIsMessagingStopped,
        initialIsBlockedByMe: widget.initialIsBlockedByMe,
        initialIsBlockedByOther: widget.initialIsBlockedByOther,
      ),
      tag: _tag,
    );
  }

  @override
  void dispose() {
    if (Get.isRegistered<ChatDetailController>(tag: _tag)) {
      Get.delete<ChatDetailController>(tag: _tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _ChatBackdrop()),
          Obx(
            () => RefreshIndicator(
              onRefresh: _controller.refreshMessages,
              child: ListView(
                controller: _controller.scrollController,
                reverse: true,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  safeTop + 108,
                  16,
                  safeBottom +
                      (70 +
                          (_controller.isIncomingChatRequest.value
                              ? 88
                              : _controller.isWaitingForReply.value
                              ? 80
                              : 0)),
                ),
                children: [
                  if (_controller.isInitialLoading.value)
                    const _ChatDetailShimmer()
                  else if (_controller.hasError.value &&
                      _controller.messages.isEmpty)
                    AppErrorState(
                      message: _controller.errorMessage.value,
                      onRetry: () => _controller.fetchMessages(reset: true),
                    )
                  else ...[
                    if (_controller.isLoadingMore.value)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    if (_controller.otherUserTyping.value)
                      const _TypingBubble(),
                    ..._buildMessageList(),
                    if (_controller.stoppedBannerText.value.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: _StoppedBanner(
                          message: _controller.stoppedBannerText.value,
                          actionLabel:
                              _controller.isMessagingStopped.value &&
                                  !_controller.isBlocked.value
                              ? 'Resume Chat'
                              : null,
                          onAction:
                              _controller.isMessagingStopped.value &&
                                  !_controller.isBlocked.value
                              ? _controller.toggleChatMessaging
                              : null,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ChatHeader(controller: _controller),
          ),

          Obx(
            () => Visibility(
              visible: _controller.isWaitingForReply.value,
              child: Positioned(
                bottom: 120,
                left: 16,
                right: 16,
                child: const _PrivacyBanner(),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.only(bottom: keyboard > 0 ? 6 : 0),
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, safeBottom + 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    child: Obx(
                      () => _controller.isIncomingChatRequest.value
                          ? _ChatRequestActions(controller: _controller)
                          : Row(
                              children: [
                                Expanded(
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F0EE),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: AppColors.cardBorder,
                                        width: 1,
                                      ),
                                    ),
                                    child: TextField(
                                      controller:
                                          _controller.messageController,
                                      minLines: 1,
                                      maxLines: 4,
                                      enabled:
                                          !_controller.isComposerDisabled,
                                      textInputAction: TextInputAction.send,
                                      onSubmitted: (_) {
                                        _controller.sendCurrentMessage();
                                        FocusScope.of(context).unfocus();
                                      },
                                      style: AppFonts.beVietnam(
                                        size: 15,
                                        weight: FontWeight.w500,
                                        color: AppColors.text,
                                      ),
                                      decoration: InputDecoration(
                                        border: InputBorder.none,
                                        hintText: _controller.isBlocked.value
                                            ? 'You can\'t message this user'
                                            : _controller
                                                  .isMessagingStopped
                                                  .value
                                            ? 'Messaging stopped'
                                            : _controller
                                                  .isWaitingForReply
                                                  .value
                                            ? 'Wait for them to accept'
                                            : 'Type a message...',
                                        hintStyle: AppFonts.beVietnam(
                                          size: 14,
                                          weight: FontWeight.w500,
                                          color: AppColors.hintText.withValues(
                                            alpha: 0.9,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _controller.canSend
                                      ? _controller.sendCurrentMessage
                                      : null,
                                  borderRadius: BorderRadius.circular(18),
                                  child: AnimatedContainer(
                                    duration: const Duration(
                                      milliseconds: 180,
                                    ),
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(18),
                                      gradient: _controller.canSend
                                          ? const LinearGradient(
                                              colors: [
                                                AppColors.primary,
                                                Color(0xFFFF8A5B),
                                              ],
                                            )
                                          : null,
                                      color: _controller.canSend
                                          ? null
                                          : const Color(0xFFE7DDD8),
                                      boxShadow: _controller.canSend
                                          ? const [
                                              BoxShadow(
                                                color: Color.fromRGBO(
                                                  255,
                                                  77,
                                                  109,
                                                  0.22,
                                                ),
                                                blurRadius: 18,
                                                offset: Offset(0, 8),
                                                spreadRadius: -8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: _controller.isSending.value
                                        ? const Padding(
                                            padding: EdgeInsets.all(13),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const AppHeroIconData(
                                            Icons.send_rounded,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMessageList() {
    final List<Widget> widgets = [];
    for (int i = 0; i < _controller.messages.length; i++) {
      final message = _controller.messages[i];
      // In a reversed list, messages[i+1] is older than messages[i]
      final olderMessage = i + 1 < _controller.messages.length
          ? _controller.messages[i + 1]
          : null;

      widgets.add(
        _ChatMessageBubble(
          message: message,
          onReport: () => _reportMessage(message),
        ),
      );

      if (olderMessage == null ||
          !AppTimeFormatter.isSameDay(
            message.createdAt,
            olderMessage.createdAt,
          )) {
        widgets.add(_DateBanner(date: message.createdAt));
      }
    }
    return widgets;
  }

  Future<void> _reportMessage(ChatMessageModel message) async {
    final action = await showChatMessageOptionsSheet(context);
    if (!mounted || action != ChatMessageOptionAction.report) {
      return;
    }
    final result = await showReportReasonSheet(
      context,
      title: 'Report message',
    );
    if (result == null) {
      return;
    }
    await _controller.reportMessage(
      message.id,
      result.reasonCode,
      result.details,
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.controller});

  final ChatDetailController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: SafeArea(
          bottom: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.96),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
              ),
            ),
            child: Obx(() {
              final user = controller.user.value;
              final isStopped = controller.isMessagingStopped.value;
              return Row(
                children: [
                  IconButton(
                    onPressed: AppBackNavigation.handleBack,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.72),
                      shape: const CircleBorder(),
                    ),
                    icon: const AppHeroIconData(
                      Icons.arrow_back_rounded,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                    ),
                    child: ClipOval(
                      child: user?.imageUrl.trim().isNotEmpty == true
                          ? AppCachedImage(
                              imageUrl: user!.imageUrl,
                              width: 42,
                              height: 42,
                            )
                          : Container(
                              color: const Color(0xFFF1EBE8),
                              alignment: Alignment.center,
                              child: const AppHeroIconData(
                                Icons.person_rounded,
                                color: AppColors.hintText,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            ProfileOpenHelper.open(
                              username: controller.username,
                            );
                          },
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.displayName ??
                                      widgetTitleFallback(controller),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppFonts.plusJakarta(
                                    size: 15,
                                    weight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                              ),
                              VerifiedBadgeSlot(
                                username: controller.username,
                                fallback: user?.isVerifiedBadge == true,
                                size: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _StatusChip(
                              label: user?.isOnline == true
                                  ? 'Active now'
                                  : 'Offline',
                              color: user?.isOnline == true
                                  ? const Color(0xFF16A34A)
                                  : AppColors.hintText,
                              background: user?.isOnline == true
                                  ? const Color(0xFFEAF8EF)
                                  : const Color(0xFFF1EBE8),
                            ),
                            if (_headerStatusLabel(controller, isStopped) !=
                                null)
                              _StatusChip(
                                label: _headerStatusLabel(
                                  controller,
                                  isStopped,
                                )!,
                                color: isStopped
                                    ? const Color(0xFFB42318)
                                    : AppColors.hintText,
                                background: isStopped
                                    ? const Color(0xFFFDECEC)
                                    : const Color(0xFFF4EEEC),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final displayName =
                          user?.displayName ?? widgetTitleFallback(controller);
                      final action = await showChatConversationOptionsSheet(
                        context,
                        isMessagingStopped: isStopped,
                        isBlocked: controller.isBlocked.value,
                        isBlockedByMe: controller.isBlockedByMe.value,
                      );
                      if (!context.mounted || action == null) {
                        return;
                      }

                      switch (action) {
                        case ChatConversationOptionAction.toggleMessaging:
                          controller.toggleChatMessaging();
                          break;
                        case ChatConversationOptionAction.toggleBlock:
                          if (controller.isBlockedByMe.value) {
                            final confirmed =
                                await showUnblockUserConfirmationSheet(
                                  context,
                                  username: displayName,
                                );
                            if (confirmed == true) {
                              await controller.unblockUser();
                            }
                          } else {
                            final confirmed =
                                await showBlockUserConfirmationSheet(
                                  context,
                                  username: displayName,
                                );
                            if (confirmed == true) {
                              await controller.blockUser();
                            }
                          }
                          break;
                      }
                    },
                    icon: const AppHeroIconData(
                      Icons.more_vert_rounded,
                      color: AppColors.text,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  String widgetTitleFallback(ChatDetailController controller) {
    final username = controller.username.trim();
    if (username.isEmpty) {
      return 'Chat';
    }
    return '@$username';
  }

  String? _headerStatusLabel(ChatDetailController controller, bool isStopped) {
    if (controller.isBlocked.value) {
      return controller.isBlockedByMe.value ? 'Blocked' : 'Blocked you';
    }
    if (isStopped) {
      return 'Messaging stopped';
    }
    if (controller.isIncomingChatRequest.value) {
      return 'Chat request';
    }
    return null;
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppFonts.beVietnam(
          size: 10,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StoppedBanner extends StatelessWidget {
  const _StoppedBanner({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF5C2C7)),
      ),
      child: Row(
        children: [
          const AppHeroIconData(
            Icons.info_outline_rounded,
            color: Color(0xFFB42318),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppFonts.beVietnam(
                size: 13,
                weight: FontWeight.w600,
                color: const Color(0xFFB42318),
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.76),
                foregroundColor: const Color(0xFFB42318),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                actionLabel!,
                style: AppFonts.beVietnam(
                  size: 11,
                  weight: FontWeight.w800,
                  color: const Color(0xFFB42318),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChatRequestActions extends StatelessWidget {
  const _ChatRequestActions({required this.controller});

  final ChatDetailController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final busy = controller.isRespondingToRequest.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Accept this chat request to reply.',
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w600,
              color: AppColors.hintText,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : controller.rejectChatRequest,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                    side: const BorderSide(color: Color(0xFFF2C6C2)),
                    backgroundColor: const Color(0xFFFDECEC),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Reject',
                    style: AppFonts.beVietnam(
                      size: 14,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: busy
                        ? null
                        : const LinearGradient(
                            colors: [AppColors.primary, Color(0xFFFF8A5B)],
                          ),
                    color: busy ? const Color(0xFFE7DDD8) : null,
                  ),
                  child: TextButton(
                    onPressed: busy ? null : controller.acceptChatRequest,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Accept',
                            style: AppFonts.beVietnam(
                              size: 14,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const AppHeroIconData(
            Icons.info_outline_rounded,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You can send up to 3 messages until your chat request is accepted.',
              style: AppFonts.beVietnam(
                size: 13,
                weight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBanner extends StatelessWidget {
  const _DateBanner({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final label = AppTimeFormatter.formatBannerDate(date);
    if (label.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EBE8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF8E6F71).withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: AppFonts.beVietnam(
            size: 11,
            weight: FontWeight.w700,
            color: AppColors.hintText,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({required this.message, this.onReport});

  final ChatMessageModel message;
  final VoidCallback? onReport;

  Widget _messageBody(BuildContext context, bool isMine) {
    final share = InAppSharePayload.tryParse(message.body);
    if (share == null) {
      return Text(
        message.body,
        style: AppFonts.beVietnam(
          size: 15,
          height: 1.35,
          weight: FontWeight.w500,
          color: isMine ? Colors.white : AppColors.text,
        ),
      );
    }
    return _SharedPostCard(share: share, isMine: isMine);
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 330),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: isMine ? null : onReport,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(24),
                      topRight: const Radius.circular(24),
                      bottomLeft: Radius.circular(isMine ? 24 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 24),
                    ),
                    gradient: isMine
                        ? const LinearGradient(
                            colors: [AppColors.primary, Color(0xFFFF8A5B)],
                          )
                        : null,
                    color: isMine ? null : Colors.white,
                    border: isMine
                        ? null
                        : Border.all(
                            color: const Color(
                              0xFF8E6F71,
                            ).withValues(alpha: 0.12),
                            width: 0.6,
                          ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(26, 26, 26, 0.06),
                        blurRadius: 20,
                        offset: Offset(0, 4),
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: _messageBody(context, isMine),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.timeLabel,
                      style: AppFonts.beVietnam(
                        size: 10,
                        weight: FontWeight.w700,
                        color: AppColors.hintText,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isMine && message.isSeen) ...[
                      const SizedBox(width: 4),
                      const AppHeroIconData(
                        Icons.done_all_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedPostCard extends StatelessWidget {
  const _SharedPostCard({required this.share, required this.isMine});

  final InAppSharePayload share;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final color = isMine ? Colors.white : AppColors.text;
    final muted = isMine ? Colors.white.withValues(alpha: 0.82) : AppColors.hintText;
    return GestureDetector(
      onTap: () => PostDetailOpenHelper.openById(share.id),
      child: SizedBox(
        width: 210,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: share.isReel ? 0.78 : 1,
                child: share.previewUrl.trim().isEmpty
                    ? const ColoredBox(color: Color(0xFFF1EBE8))
                    : AppCachedImage(imageUrl: share.previewUrl),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              share.isReel ? 'Reel' : 'Post',
              style: AppFonts.beVietnam(
                size: 11,
                weight: FontWeight.w800,
                color: muted,
              ),
            ),
            if (share.caption.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                share.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.beVietnam(
                  size: 13,
                  weight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
            if (share.authorName.isNotEmpty || share.username.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                share.authorName.isNotEmpty
                    ? share.authorName
                    : '@${share.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w500,
                  color: muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(24),
            ),
            border: Border.all(
              color: const Color(0xFF8E6F71).withValues(alpha: 0.12),
              width: 0.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(26, 26, 26, 0.06),
                blurRadius: 20,
                offset: Offset(0, 4),
                spreadRadius: -8,
              ),
            ],
          ),
          child: const _TypingDots(),
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 10,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (index) {
              final t = (_controller.value - (index * 0.2)) % 1.0;
              final bounce = t < 0.5 ? (t / 0.5) : (1 - t) / 0.5;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Transform.translate(
                  offset: Offset(0, -4 * bounce),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.hintText,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _ChatDetailShimmer extends StatelessWidget {
  const _ChatDetailShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        Align(
          alignment: Alignment.centerLeft,
          child: AppShimmerBox(
            width: 180,
            height: 54,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: AppShimmerBox(
            width: 220,
            height: 70,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
        SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: AppShimmerBox(
            width: 260,
            height: 82,
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
        ),
      ],
    );
  }
}

class _ChatBackdrop extends StatelessWidget {
  const _ChatBackdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8F6), AppColors.background, Color(0xFFF9F3F0)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -35,
            child: _ChatGlowBlob(size: 160, color: Color(0xFFFFD1C3)),
          ),
          Positioned(
            top: 100,
            left: -50,
            child: _ChatGlowBlob(size: 130, color: Color(0xFFFFE7A8)),
          ),
          Positioned(
            bottom: 160,
            right: -35,
            child: _ChatGlowBlob(size: 120, color: Color(0xFFFFC0CB)),
          ),
        ],
      ),
    );
  }
}

class _ChatGlowBlob extends StatelessWidget {
  const _ChatGlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        shape: BoxShape.circle,
      ),
    );
  }
}
