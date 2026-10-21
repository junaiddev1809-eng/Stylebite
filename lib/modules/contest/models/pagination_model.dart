class PaginationModel {
  const PaginationModel({
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.hasMorePages,
  });

  final int currentPage;
  final int lastPage;
  final int total;
  final bool hasMorePages;

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    final current = _readInt(json['current_page'], fallback: 1);
    final last = _readInt(json['last_page'], fallback: current);
    return PaginationModel(
      currentPage: current,
      lastPage: last,
      total: _readInt(json['total']),
      hasMorePages:
          json['has_more_pages'] == true || json['next_page_url'] != null
          ? true
          : current < last,
    );
  }
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  return int.tryParse('${value ?? ''}') ?? fallback;
}
