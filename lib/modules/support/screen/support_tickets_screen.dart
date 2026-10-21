import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:heroicons/heroicons.dart';

import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../../core/utils/app_back_navigation.dart';
import '../../../core/utils/app_time_formatter.dart';
import '../../../core/widgets/states/app_shimmer_box.dart';
import '../controllers/support_tickets_controller.dart';
import '../models/support_ticket_model.dart';
import '../utils/support_text_helpers.dart';
import '../widgets/support_status_badge.dart';
import 'new_support_ticket_screen.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  late final SupportTicketsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<SupportTicketsController>()
        ? Get.find<SupportTicketsController>()
        : Get.put(SupportTicketsController());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    child: Center(
                      child: Text(
                        'Support Tickets',
                        style: AppFonts.plusJakarta(
                          size: 20,
                          weight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _openNewTicket,
                    borderRadius: BorderRadius.circular(999),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: HeroIcon(HeroIcons.plus, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_controller.isInitialLoading.value &&
                    _controller.tickets.isEmpty) {
                  return const _SupportTicketsShimmer();
                }

                if (_controller.hasError.value && _controller.tickets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyTicketsState(
                        title: 'Could not load your tickets',
                        subtitle: _controller.errorMessage.value,
                      ),
                    ),
                  );
                }

                if (_controller.tickets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EmptyTicketsState(
                        title: 'No support tickets yet',
                        subtitle:
                            'Ran into a bug or need help with something? Open a ticket and our team will follow up here.',
                        onTapAction: _openNewTicket,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _controller.refreshTickets,
                  child: ListView.builder(
                    controller: _controller.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    itemCount: _controller.tickets.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _controller.tickets.length) {
                        if (_controller.isLoadingMore.value) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        if (!_controller.hasMore.value) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                'No more data',
                                style: AppFonts.beVietnam(
                                  size: 12,
                                  weight: FontWeight.w600,
                                  color: AppColors.hintText,
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      final ticket = _controller.tickets[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == _controller.tickets.length - 1
                              ? 0
                              : 10,
                        ),
                        child: _TicketCard(
                          ticket: ticket,
                          onTap: () async {
                            await Get.toNamed(
                              AppRoutes.supportTicketDetail,
                              arguments: {'ticketId': ticket.id},
                            );
                            _controller.markTicketRead(ticket.id);
                          },
                        ),
                      );
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNewTicket() async {
    // support_tickets_controller.createTicket already inserts the new
    // ticket into the list on success — no refresh needed here.
    await Get.to<int>(() => const NewSupportTicketScreen());
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onTap});

  final SupportTicketModel ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
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
                      ticket.subject.isEmpty
                          ? humanizeSupportValue(ticket.category)
                          : ticket.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.plusJakarta(
                        size: 15,
                        weight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SupportStatusBadge(status: ticket.status, label: ticket.statusLabel),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                ticket.reference.isEmpty
                    ? humanizeSupportValue(ticket.category)
                    : '${humanizeSupportValue(ticket.category)} • ${ticket.reference}',
                style: AppFonts.beVietnam(
                  size: 12,
                  weight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    AppTimeFormatter.formatCommentTime(
                      ticket.lastReplyAt ?? ticket.updatedAt,
                    ),
                    style: AppFonts.beVietnam(
                      size: 11,
                      weight: FontWeight.w600,
                      color: AppColors.hintText,
                    ),
                  ),
                  if (ticket.lastReplyBy != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• Last reply: ${humanizeSupportValue(ticket.lastReplyBy!)}',
                      style: AppFonts.beVietnam(
                        size: 11,
                        weight: FontWeight.w600,
                        color: AppColors.hintText,
                      ),
                    ),
                  ],
                  if (ticket.messagesCount > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '• ${ticket.messagesCount} msgs',
                      style: AppFonts.beVietnam(
                        size: 11,
                        weight: FontWeight.w600,
                        color: AppColors.hintText,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (ticket.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${ticket.unreadCount} new',
                        style: AppFonts.beVietnam(
                          size: 10,
                          weight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTicketsState extends StatelessWidget {
  const _EmptyTicketsState({
    required this.title,
    required this.subtitle,
    this.onTapAction,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTapAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const HeroIcon(
              HeroIcons.lifebuoy,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppFonts.plusJakarta(
              size: 17,
              weight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppFonts.beVietnam(
              size: 13,
              weight: FontWeight.w500,
              color: AppColors.hintText,
            ),
          ),
          if (onTapAction != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTapAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  'Open a Ticket',
                  style: AppFonts.beVietnam(
                    size: 13,
                    weight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportTicketsShimmer extends StatelessWidget {
  const _SupportTicketsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppShimmerBox(
                width: 140,
                height: 15,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(height: 8),
              AppShimmerBox(
                width: 90,
                height: 12,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              SizedBox(height: 8),
              AppShimmerBox(
                height: 12,
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ],
          ),
        );
      },
    );
  }
}
