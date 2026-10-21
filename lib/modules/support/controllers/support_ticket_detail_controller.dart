import 'package:get/get.dart';

import '../../../core/utils/app_helper.dart';
import '../api/support_api.dart';
import '../models/support_ticket_model.dart';

class SupportTicketDetailController extends GetxController {
  SupportTicketDetailController({required this.ticketId});

  final int ticketId;

  final Rxn<SupportTicketModel> ticket = Rxn<SupportTicketModel>();
  final RxList<SupportTicketMessageModel> messages =
      <SupportTicketMessageModel>[].obs;

  final RxBool isLoading = true.obs;
  final RxBool hasError = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isSendingReply = false.obs;
  final RxBool isClosing = false.obs;
  final RxList<String> pendingAttachments = <String>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    hasError.value = false;
    errorMessage.value = '';
    try {
      final detail = await SupportApi.fetchTicketDetail(ticketId);
      ticket.value = detail.ticket;
      messages.assignAll(detail.messages);
    } catch (error) {
      hasError.value = true;
      errorMessage.value = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading.value = false;
    }
  }

  void addAttachment(String path) {
    if (pendingAttachments.length >= 5 || pendingAttachments.contains(path)) {
      return;
    }
    pendingAttachments.add(path);
  }

  void removeAttachment(String path) {
    pendingAttachments.remove(path);
  }

  Future<void> sendReply(String body) async {
    final trimmed = body.trim();
    if ((trimmed.isEmpty && pendingAttachments.isEmpty) ||
        isSendingReply.value) {
      return;
    }

    isSendingReply.value = true;
    try {
      await SupportApi.replyToTicket(
        ticketId: ticketId,
        body: trimmed,
        attachmentPaths: pendingAttachments.toList(),
      );
      pendingAttachments.clear();
      await fetchDetail();
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isSendingReply.value = false;
    }
  }

  Future<void> closeTicket() async {
    if (isClosing.value) {
      return;
    }
    isClosing.value = true;
    try {
      await SupportApi.closeTicket(ticketId);
      successSnackBar(message: 'Ticket closed.');
      await fetchDetail();
    } catch (error) {
      errorSnackBar(message: error.toString().replaceFirst('Exception: ', ''));
    } finally {
      isClosing.value = false;
    }
  }
}
