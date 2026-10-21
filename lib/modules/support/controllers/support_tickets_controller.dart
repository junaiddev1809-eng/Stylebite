import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/utils/app_helper.dart';
import '../api/support_api.dart';
import '../models/support_ticket_model.dart';

class SupportTicketsController extends GetxController {
  final RxList<SupportTicketModel> tickets = <SupportTicketModel>[].obs;
  final RxBool isInitialLoading = true.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool hasMore = true.obs;
  final RxBool isCreatingTicket = false.obs;

  final ScrollController scrollController = ScrollController();

  int _currentPage = 0;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_onScroll);
    fetchTickets(reset: true);
  }

  @override
  void onClose() {
    scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.onClose();
  }

  Future<void> fetchTickets({required bool reset}) async {
    if (reset) {
      isInitialLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';
      _currentPage = 0;
      hasMore.value = true;
    } else {
      if (isLoadingMore.value || !hasMore.value) {
        return;
      }
      isLoadingMore.value = true;
    }

    try {
      final page = reset ? 1 : _currentPage + 1;
      final response = await SupportApi.fetchTickets(page: page);
      if (reset) {
        tickets.assignAll(response.tickets);
      } else {
        tickets.addAll(response.tickets);
      }
      _currentPage = response.pagination.currentPage;
      hasMore.value = response.pagination.hasMorePages;
    } catch (error) {
      hasError.value = true;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
      if (!reset) {
        errorSnackBar(message: errorMessage.value);
      }
    } finally {
      if (reset) {
        isInitialLoading.value = false;
      } else {
        isLoadingMore.value = false;
      }
    }
  }

  Future<void> refreshTickets() => fetchTickets(reset: true);

  // Opening a ticket thread marks its messages read server-side (no
  // separate API call) — reflect that locally so the list badge doesn't
  // stay stale until the next pull-to-refresh.
  void markTicketRead(int ticketId) {
    final index = tickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index == -1 || tickets[index].unreadCount == 0) {
      return;
    }
    tickets[index] = tickets[index].copyWith(unreadCount: 0);
  }

  Future<SupportTicketModel?> createTicket({
    required String category,
    required String subject,
    required String body,
    required List<String> attachmentPaths,
  }) async {
    if (isCreatingTicket.value) {
      return null;
    }
    isCreatingTicket.value = true;
    try {
      final ticket = await SupportApi.createTicket(
        category: category,
        subject: subject,
        body: body,
        attachmentPaths: attachmentPaths,
      );
      successSnackBar(message: 'Ticket submitted. Our team will get back to you.');
      if (ticket != null) {
        tickets.insert(0, ticket);
      } else {
        await refreshTickets();
      }
      return ticket;
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
      return null;
    } finally {
      isCreatingTicket.value = false;
    }
  }

  void _onScroll() {
    if (!scrollController.hasClients) {
      return;
    }
    final position = scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 180) {
      fetchTickets(reset: false);
    }
  }
}
