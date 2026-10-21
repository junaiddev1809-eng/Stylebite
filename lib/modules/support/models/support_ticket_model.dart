class SupportTicketModel {
  const SupportTicketModel({
    required this.id,
    required this.reference,
    required this.category,
    required this.subject,
    required this.body,
    required this.attachmentUrls,
    required this.status,
    required this.statusLabel,
    required this.messagesCount,
    required this.unreadCount,
    required this.lastReplyBy,
    required this.lastReplyAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String reference;
  final String category;
  final String subject;
  final String body;
  final List<String> attachmentUrls;
  final String status;
  final String? statusLabel;
  final int messagesCount;
  final int unreadCount;
  final String? lastReplyBy;
  final String? lastReplyAt;
  final String createdAt;
  final String updatedAt;

  bool get isClosed => status == 'closed';

  SupportTicketModel copyWith({int? unreadCount}) {
    return SupportTicketModel(
      id: id,
      reference: reference,
      category: category,
      subject: subject,
      body: body,
      attachmentUrls: attachmentUrls,
      status: status,
      statusLabel: statusLabel,
      messagesCount: messagesCount,
      unreadCount: unreadCount ?? this.unreadCount,
      lastReplyBy: lastReplyBy,
      lastReplyAt: lastReplyAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: _asInt(json['id']),
      reference: _asString(json['reference'] ?? json['id']),
      category: _asString(json['category']),
      subject: _asString(json['subject']),
      body: _asString(json['body'] ?? json['description'] ?? json['message']),
      attachmentUrls: _parseAttachments(json['attachments']),
      status: _asString(json['status']),
      statusLabel: _nullableString(json['status_label']),
      messagesCount: _asInt(json['messages_count']),
      unreadCount: _asInt(json['unread_count']),
      lastReplyBy: _nullableString(json['last_reply_by']),
      lastReplyAt: _nullableString(json['last_reply_at']),
      createdAt: _asString(json['created_at']),
      updatedAt: _asString(json['updated_at'] ?? json['created_at']),
    );
  }
}

class SupportTicketMessageModel {
  const SupportTicketMessageModel({
    required this.id,
    required this.body,
    required this.isMine,
    required this.attachmentUrls,
    required this.createdAt,
  });

  final int id;
  final String body;
  final bool isMine;
  final List<String> attachmentUrls;
  final String createdAt;

  factory SupportTicketMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketMessageModel(
      id: _asInt(json['id']),
      body: _asString(json['body'] ?? json['message']),
      isMine: _resolveIsMine(json),
      attachmentUrls: _parseAttachments(json['attachments']),
      createdAt: _asString(json['created_at']),
    );
  }

  static bool _resolveIsMine(Map<String, dynamic> json) {
    if (json.containsKey('is_mine')) {
      return _asBool(json['is_mine']);
    }
    final senderType = (json['sender_type'] ?? json['author_type'] ?? json['type'] ?? '')
        .toString()
        .toLowerCase();
    if (senderType.isNotEmpty) {
      return senderType == 'user' ||
          senderType == 'customer' ||
          senderType == 'requester';
    }
    final staffFlag = json['is_staff'] ?? json['is_admin'] ?? json['is_agent'];
    if (staffFlag != null) {
      return !_asBool(staffFlag);
    }
    return false;
  }
}

class SupportTicketDetailModel {
  const SupportTicketDetailModel({required this.ticket, required this.messages});

  final SupportTicketModel ticket;
  final List<SupportTicketMessageModel> messages;

  factory SupportTicketDetailModel.fromJson(Map<String, dynamic> json) {
    final ticketJson =
        (json['ticket'] as Map<String, dynamic>?) ??
        (json['data'] as Map<String, dynamic>?) ??
        json;
    final messagesJson = _resolveMessagesList(json);
    final messages = messagesJson
        .whereType<Map<String, dynamic>>()
        .map(SupportTicketMessageModel.fromJson)
        .toList(growable: false);

    return SupportTicketDetailModel(
      ticket: SupportTicketModel.fromJson(ticketJson),
      messages: messages,
    );
  }

  static List<dynamic> _resolveMessagesList(Map<String, dynamic> json) {
    for (final key in <String>['messages', 'replies', 'conversation']) {
      final value = json[key];
      if (value is List) {
        return value;
      }
      final nested = json['data'];
      if (nested is Map<String, dynamic> && nested[key] is List) {
        return nested[key] as List<dynamic>;
      }
      final ticketNested = json['ticket'];
      if (ticketNested is Map<String, dynamic> && ticketNested[key] is List) {
        return ticketNested[key] as List<dynamic>;
      }
    }
    return const <dynamic>[];
  }
}

class SupportTicketsPaginationModel {
  const SupportTicketsPaginationModel({
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

  factory SupportTicketsPaginationModel.fromJson(Map<String, dynamic> json) {
    final currentPage = _asInt(json['current_page'], fallback: 1);
    final lastPage = _asInt(json['last_page'], fallback: 1);

    return SupportTicketsPaginationModel(
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

class SupportTicketsListResponseModel {
  const SupportTicketsListResponseModel({
    required this.tickets,
    required this.pagination,
  });

  final List<SupportTicketModel> tickets;
  final SupportTicketsPaginationModel pagination;

  factory SupportTicketsListResponseModel.fromJson(Map<String, dynamic> json) {
    final items = (json['tickets'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(SupportTicketModel.fromJson)
        .toList(growable: false);

    return SupportTicketsListResponseModel(
      tickets: items,
      pagination: SupportTicketsPaginationModel.fromJson(
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

List<String> _parseAttachments(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) {
        if (item is String) {
          return item;
        }
        if (item is Map) {
          return (item['url'] ?? item['file_url'] ?? '').toString();
        }
        return '';
      })
      .where((url) => url.trim().isNotEmpty)
      .toList(growable: false);
}
