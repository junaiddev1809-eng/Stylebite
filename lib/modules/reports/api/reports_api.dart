import 'dart:convert';

import '../../../core/utils/api_helper.dart';
import '../models/report_model.dart';

class ReportReasonOption {
  const ReportReasonOption({required this.value, required this.label});

  final String value;
  final String label;

  factory ReportReasonOption.fromJson(Map<String, dynamic> json) {
    return ReportReasonOption(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

class ReportsMeta {
  const ReportsMeta({required this.reasons, required this.descriptionMaxLength});

  final List<ReportReasonOption> reasons;
  final int descriptionMaxLength;
}

class ReportSubmitResult {
  const ReportSubmitResult({required this.alreadyReported});

  final bool alreadyReported;
}

class ReportsApi {
  static Future<ReportsListResponseModel> fetchMine({int page = 1}) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      'reports/mine?page=$page',
    );
    if (response == null) {
      throw Exception('No response returned from reports history endpoint.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load your reports.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return ReportsListResponseModel.fromJson(payload);
  }

  static Future<ReportsMeta> fetchMeta() async {
    final response = await ApiHelper.fetchDataWithAuthorization('reports/meta');
    if (response == null) {
      throw Exception('No response returned from reports meta endpoint.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load report reasons.');
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final reasons = (payload['reasons'] as List<dynamic>? ?? <dynamic>[])
        .map((e) => ReportReasonOption.fromJson(e as Map<String, dynamic>))
        .toList();
    final maxLength = payload['description_max_length'] is int
        ? payload['description_max_length'] as int
        : int.tryParse('${payload['description_max_length']}') ?? 1000;
    return ReportsMeta(reasons: reasons, descriptionMaxLength: maxLength);
  }

  static Future<ReportSubmitResult> submitReport({
    required String targetType,
    required int targetId,
    required String reason,
    String? description,
  }) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'reports',
      body: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
    if (response == null) {
      throw Exception('No response returned from report endpoint.');
    }

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    switch (response.statusCode) {
      case 201:
        return const ReportSubmitResult(alreadyReported: false);
      case 200:
        return ReportSubmitResult(
          alreadyReported: payload?['already_reported'] == true,
        );
      case 422:
        throw Exception(
          (payload?['message'] ?? 'You cannot report your own content.')
              .toString(),
        );
      case 404:
        throw Exception(
          (payload?['message'] ?? 'This content is no longer available.')
              .toString(),
        );
      case 429:
        throw Exception(
          (payload?['message'] ??
                  'You have reached the report limit. Please try again later.')
              .toString(),
        );
      default:
        throw Exception(
          (payload?['message'] ?? 'Unable to submit report.').toString(),
        );
    }
  }
}
