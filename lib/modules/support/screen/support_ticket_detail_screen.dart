import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_helper.dart';
import '../../../core/utils/app_time_formatter.dart';
import '../controllers/support_ticket_detail_controller.dart';
import '../models/support_ticket_model.dart';
import '../utils/support_text_helpers.dart';
import '../widgets/support_status_badge.dart';
import 'new_support_ticket_screen.dart';

class SupportTicketDetailScreen extends StatefulWidget {
  const SupportTicketDetailScreen({super.key, this.ticketId});

  final int? ticketId;

  @override
  State<SupportTicketDetailScreen> createState() =>
      _SupportTicketDetailScreenState();
}

class _SupportTicketDetailScreenState
    extends State<SupportTicketDetailScreen> {
  late final int _ticketId;
  late final SupportTicketDetailController _controller;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final args = Get.arguments is Map<String, dynamic>
        ? Get.arguments as Map<String, dynamic>
        : const <String, dynamic>{};
    _ticketId = widget.ticketId ?? (args['ticketId'] as int?) ?? 0;

    final tag = 'support-ticket-$_ticketId';
    _controller = Get.isRegistered<SupportTicketDetailController>(tag: tag)
        ? Get.find<SupportTicketDetailController>(tag: tag)
        : Get.put(
            SupportTicketDetailController(ticketId: _ticketId),
            tag: tag,
          );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Obx(() {
              final ticket = _controller.ticket.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.background.withValues(alpha: 0.88),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: AppBackNavigation.handleBack,
                      borderRadius: BorderRadius.circular(999),
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: HeroIcon(
                          HeroIcons.arrowLeft,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        ticket?.subject.isNotEmpty == true
                            ? ticket!.subject
                            : 'Ticket',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AppFonts.plusJakarta(
                          size: 17,
                          weight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: ticket != null && !ticket.isClosed
                          ? InkWell(
                              onTap: _confirmClose,
                              borderRadius: BorderRadius.circular(999),
                              child: const Icon(
                                Icons.lock_outline_rounded,
                                color: AppColors.hintText,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              );
            }),
            Expanded(
              child: Obx(() {
                if (_controller.isLoading.value &&
                    _controller.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_controller.hasError.value &&
                    _controller.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _controller.errorMessage.value,
                            textAlign: TextAlign.center,
                            style: AppFonts.beVietnam(
                              size: 13,
                              weight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _controller.fetchDetail,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final ticket = _controller.ticket.value;
                return RefreshIndicator(
                  onRefresh: _controller.fetchDetail,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    children: [
                      if (ticket != null) ...[
                        _TicketSummaryCard(ticket: ticket),
                        const SizedBox(height: 14),
                        if (ticket.body.trim().isNotEmpty ||
                            ticket.attachmentUrls.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _MessageBubble(
                              message: SupportTicketMessageModel(
                                id: 0,
                                body: ticket.body,
                                isMine: true,
                                attachmentUrls: ticket.attachmentUrls,
                                createdAt: ticket.createdAt,
                              ),
                            ),
                          ),
                      ],
                      for (final message in _controller.messages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _MessageBubble(message: message),
                        ),
                    ],
                  ),
                );
              }),
            ),
            Obx(() {
              final ticket = _controller.ticket.value;
              if (ticket != null && ticket.isClosed) {
                return _ClosedTicketBanner(
                  onOpenNewTicket: () =>
                      Get.to<int>(() => const NewSupportTicketScreen()),
                );
              }
              return _ReplyComposer(
                controller: _controller,
                textController: _replyController,
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClose() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close this ticket?'),
        content: const Text(
          'You can still see this conversation, but replying will require a new ticket.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close Ticket'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _controller.closeTicket();
    }
  }
}

class _TicketSummaryCard extends StatelessWidget {
  const _TicketSummaryCard({required this.ticket});

  final SupportTicketModel ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(47, 47, 46, 0.06),
            blurRadius: 18,
            offset: Offset(0, 8),
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.reference.isEmpty
                      ? humanizeSupportValue(ticket.category)
                      : '${humanizeSupportValue(ticket.category)} • ${ticket.reference}',
                  style: AppFonts.beVietnam(
                    size: 12,
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SupportStatusBadge(status: ticket.status, label: ticket.statusLabel),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Opened ${AppTimeFormatter.formatCommentTime(ticket.createdAt)}',
            style: AppFonts.beVietnam(
              size: 11,
              weight: FontWeight.w600,
              color: AppColors.hintText,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportTicketMessageModel message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  'Support',
                  style: AppFonts.beVietnam(
                    size: 11,
                    weight: FontWeight.w700,
                    color: AppColors.hintText,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMine ? 18 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 18),
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
                        color: AppColors.hintText.withValues(alpha: 0.12),
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.body.trim().isNotEmpty)
                    Text(
                      message.body,
                      style: AppFonts.beVietnam(
                        size: 14,
                        weight: FontWeight.w500,
                        color: isMine ? Colors.white : AppColors.text,
                      ),
                    ),
                  if (message.attachmentUrls.isNotEmpty) ...[
                    if (message.body.trim().isNotEmpty)
                      const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final url in message.attachmentUrls)
                          InkWell(
                            onTap: () => _openAttachment(context, url),
                            borderRadius: BorderRadius.circular(10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                url,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              AppTimeFormatter.formatCommentTime(message.createdAt),
              style: AppFonts.beVietnam(
                size: 10,
                weight: FontWeight.w600,
                color: AppColors.hintText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAttachment(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }
}

class _ReplyComposer extends StatelessWidget {
  const _ReplyComposer({required this.controller, required this.textController});

  final SupportTicketDetailController controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() {
            if (controller.pendingAttachments.isEmpty) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final path in controller.pendingAttachments)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(path),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -6,
                              right: -6,
                              child: InkWell(
                                onTap: () => controller.removeAttachment(path),
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Colors.black87,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 12,
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
          }),
          Row(
            children: [
              InkWell(
                onTap: () => _pickAttachment(context),
                borderRadius: BorderRadius.circular(999),
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: HeroIcon(
                    HeroIcons.paperClip,
                    color: AppColors.hintText,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: textController,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Write a reply...',
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
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Obx(
                () => InkWell(
                  onTap: controller.isSendingReply.value ? null : _send,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                    ),
                    child: controller.isSendingReply.value
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachment(BuildContext context) async {
    final remaining = 5 - controller.pendingAttachments.length;
    if (remaining <= 0) {
      errorSnackBar(message: 'You can attach up to 5 images.');
      return;
    }
    final picked = await ImagePicker().pickMultiImage(limit: remaining);
    const maxBytes = 5 * 1024 * 1024;
    var skippedForType = false;
    var skippedForSize = false;
    for (final file in picked) {
      if (controller.pendingAttachments.length >= 5) {
        break;
      }
      if (!isSupportedSupportAttachment(file.path)) {
        skippedForType = true;
        continue;
      }
      final size = await File(file.path).length();
      if (size > maxBytes) {
        skippedForSize = true;
        continue;
      }
      controller.addAttachment(file.path);
    }

    if (skippedForType) {
      errorSnackBar(message: 'Only JPG, PNG, or WEBP images are supported.');
    }
    if (skippedForSize) {
      errorSnackBar(message: 'Some images were skipped for exceeding 5MB.');
    }
  }

  void _send() {
    final text = textController.text;
    controller.sendReply(text);
    textController.clear();
  }
}

class _ClosedTicketBanner extends StatelessWidget {
  const _ClosedTicketBanner({required this.onOpenNewTicket});

  final VoidCallback onOpenNewTicket;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
            child: Text(
              'This ticket is closed. Please create a new ticket if you need further help.',
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w600,
                color: AppColors.hintText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onOpenNewTicket,
            child: Text(
              'New Ticket',
              style: AppFonts.beVietnam(
                size: 12,
                weight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
