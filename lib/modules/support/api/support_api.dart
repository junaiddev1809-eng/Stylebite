import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/utils/api_helper.dart';
import '../../../core/utils/app_device_service.dart';
import '../models/support_meta_model.dart';
import '../models/support_ticket_model.dart';

class SupportApi {
  static Future<SupportMetaModel> fetchMeta() async {
    final response = await ApiHelper.fetchDataWithAuthorization('support/meta');
    if (response == null) {
      throw Exception('No response returned from support meta endpoint.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load support options.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return SupportMetaModel.fromJson(payload);
  }

  static Future<SupportTicketsListResponseModel> fetchTickets({
    int page = 1,
  }) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      'support/tickets?page=$page',
    );
    if (response == null) {
      throw Exception('No response returned from support tickets endpoint.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load your support tickets.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return SupportTicketsListResponseModel.fromJson(payload);
  }

  static Future<SupportTicketDetailModel> fetchTicketDetail(int ticketId) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      'support/tickets/$ticketId',
    );
    if (response == null) {
      throw Exception('No response returned from support ticket endpoint.');
    }
    if (response.statusCode == 404) {
      throw Exception('This ticket is no longer available.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load this ticket.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return SupportTicketDetailModel.fromJson(payload);
  }

  static Future<SupportTicketModel?> createTicket({
    required String category,
    required String subject,
    required String body,
    required List<String> attachmentPaths,
  }) async {
    final diagnostics = await AppDeviceService.getSupportDiagnostics();
    final fields = <String, String>{
      'category': category,
      'subject': subject,
      'body': body,
      'app_version': diagnostics.appVersion,
      'platform': diagnostics.platform,
      'device_model': diagnostics.deviceModel,
      'os_version': diagnostics.osVersion,
    };
    final files = attachmentPaths
        .map((path) => MapEntry('attachments[]', path))
        .toList(growable: false);

    final response = await ApiHelper.multipartRequestWithAuthorization(
      'support/tickets',
      fields: fields,
      files: files,
    );
    final materialized = await _materialize(response);
    if (materialized == null) {
      throw Exception('No response returned from support ticket endpoint.');
    }

    if (materialized.statusCode == 429) {
      final payload = _tryDecode(materialized.body);
      throw Exception(
        (payload?['message'] ??
                'You already have open tickets. Please continue the conversation on an existing ticket instead of opening a new one.')
            .toString(),
      );
    }
    if (materialized.statusCode == 422) {
      final payload = _tryDecode(materialized.body);
      throw Exception(
        (payload?['message'] ?? 'Please check your ticket details and try again.')
            .toString(),
      );
    }
    if (materialized.statusCode < 200 || materialized.statusCode >= 300) {
      final payload = _tryDecode(materialized.body);
      throw Exception(
        (payload?['message'] ?? 'Unable to submit your ticket right now.')
            .toString(),
      );
    }

    final payload = _tryDecode(materialized.body);
    return _extractTicket(payload);
  }

  static Future<void> replyToTicket({
    required int ticketId,
    required String body,
    required List<String> attachmentPaths,
  }) async {
    final fields = <String, String>{'body': body};
    final files = attachmentPaths
        .map((path) => MapEntry('attachments[]', path))
        .toList(growable: false);

    final response = await ApiHelper.multipartRequestWithAuthorization(
      'support/tickets/$ticketId/messages',
      fields: fields,
      files: files,
    );
    final materialized = await _materialize(response);
    if (materialized == null) {
      throw Exception('No response returned from support ticket endpoint.');
    }

    if (materialized.statusCode == 422) {
      final payload = _tryDecode(materialized.body);
      throw Exception(
        (payload?['message'] ??
                'This ticket is closed. Please create a new ticket.')
            .toString(),
      );
    }
    if (materialized.statusCode == 404) {
      throw Exception('This ticket is no longer available.');
    }
    if (materialized.statusCode < 200 || materialized.statusCode >= 300) {
      final payload = _tryDecode(materialized.body);
      throw Exception(
        (payload?['message'] ?? 'Unable to send your reply right now.').toString(),
      );
    }
  }

  static Future<void> closeTicket(int ticketId) async {
    final response = await ApiHelper.patchRequestWithAuthorization(
      'support/tickets/$ticketId/close',
    );
    if (response == null) {
      throw Exception('No response returned from support ticket endpoint.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = _tryDecode(response.body);
      throw Exception(
        (payload?['message'] ?? 'Unable to close this ticket right now.')
            .toString(),
      );
    }
  }

  static Future<http.Response?> _materialize(
    http.StreamedResponse? response,
  ) async {
    if (response == null) {
      return null;
    }
    return http.Response.fromStream(response);
  }

  static Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static SupportTicketModel? _extractTicket(Map<String, dynamic>? payload) {
    if (payload == null) {
      return null;
    }
    final ticket = payload['ticket'];
    if (ticket is Map<String, dynamic>) {
      return SupportTicketModel.fromJson(ticket);
    }
    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return SupportTicketModel.fromJson(data);
    }
    if (payload['id'] != null) {
      return SupportTicketModel.fromJson(payload);
    }
    return null;
  }
}
