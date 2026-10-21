class SupportOption {
  const SupportOption({required this.value, required this.label});

  final String value;
  final String label;

  factory SupportOption.fromJson(Map<String, dynamic> json) {
    return SupportOption(
      value: (json['value'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
    );
  }
}

class SupportMetaModel {
  const SupportMetaModel({
    required this.categories,
    required this.statuses,
    required this.maxAttachments,
    required this.maxAttachmentSizeMb,
    required this.subjectMaxLength,
    required this.bodyMaxLength,
  });

  final List<SupportOption> categories;
  final List<SupportOption> statuses;
  final int maxAttachments;
  final int maxAttachmentSizeMb;
  final int subjectMaxLength;
  final int bodyMaxLength;

  factory SupportMetaModel.fromJson(Map<String, dynamic> json) {
    // Fields live at the top level per the API contract; the nested
    // `limits` object is only checked as a defensive fallback.
    final limits = (json['limits'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    int readInt(String key, {required int fallback}) {
      if (json[key] != null) {
        return _asInt(json[key], fallback: fallback);
      }
      if (limits[key] != null) {
        return _asInt(limits[key], fallback: fallback);
      }
      return fallback;
    }

    return SupportMetaModel(
      categories: (json['categories'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SupportOption.fromJson)
          .toList(growable: false),
      statuses: (json['statuses'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(SupportOption.fromJson)
          .toList(growable: false),
      maxAttachments: readInt('max_attachments', fallback: 5),
      // 5MB per file is a fixed rule, not a meta field — still honor an
      // override if the backend ever starts sending one.
      maxAttachmentSizeMb: readInt('max_attachment_size_mb', fallback: 5),
      subjectMaxLength: readInt('subject_max_length', fallback: 191),
      bodyMaxLength: readInt('body_max_length', fallback: 5000),
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
