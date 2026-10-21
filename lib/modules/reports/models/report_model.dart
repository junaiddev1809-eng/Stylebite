class ReportModel {
  const ReportModel({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.description,
    required this.status,
    required this.createdAt,
    required this.reviewedAt,
  });

  final int id;
  final String targetType;
  final int targetId;
  final String reason;
  final String description;
  final String status;
  final String createdAt;
  final String? reviewedAt;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: _asInt(json['id']),
      targetType: _asString(json['target_type']),
      targetId: _asInt(json['target_id']),
      reason: _asString(json['reason']),
      description: _asString(json['description']),
      status: _asString(json['status']),
      createdAt: _asString(json['created_at']),
      reviewedAt: _nullableString(json['reviewed_at']),
    );
  }
}

class ReportsPaginationModel {
  const ReportsPaginationModel({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.hasMorePages,
  });

  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool hasMorePages;

  factory ReportsPaginationModel.fromJson(Map<String, dynamic> json) {
    final currentPage = _asInt(json['current_page'], fallback: 1);
    final lastPage = _asInt(json['last_page'], fallback: 1);

    return ReportsPaginationModel(
      currentPage: currentPage <= 0 ? 1 : currentPage,
      perPage: _asInt(json['per_page'], fallback: 20),
      total: _asInt(json['total']),
      lastPage: lastPage <= 0 ? 1 : lastPage,
      hasMorePages:
          _asBool(json['has_more_pages']) ||
          (currentPage > 0 && lastPage > 0 && currentPage < lastPage),
    );
  }
}

class ReportsListResponseModel {
  const ReportsListResponseModel({
    required this.reports,
    required this.pagination,
  });

  final List<ReportModel> reports;
  final ReportsPaginationModel pagination;

  factory ReportsListResponseModel.fromJson(Map<String, dynamic> json) {
    final items = (json['reports'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(ReportModel.fromJson)
        .toList(growable: false);

    return ReportsListResponseModel(
      reports: items,
      pagination: ReportsPaginationModel.fromJson(
        (json['pagination'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value) ?? fallback;
  }
  return fallback;
}

String _asString(dynamic value) => value?.toString().trim() ?? '';

String? _nullableString(dynamic value) {
  final resolved = value?.toString().trim();
  if (resolved == null || resolved.isEmpty || resolved == 'null') {
    return null;
  }
  return resolved;
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final raw = value?.toString().trim().toLowerCase() ?? '';
  return raw == '1' || raw == 'true' || raw == 'yes';
}
