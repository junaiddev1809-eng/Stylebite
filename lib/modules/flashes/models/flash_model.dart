enum FlashKind { outfit, food }

FlashKind flashKindFrom(Object? raw) {
  final value = (raw ?? '').toString().trim().toLowerCase();
  if (value == 'food' || value == 'bite' || value == '2') {
    return FlashKind.food;
  }
  return FlashKind.outfit;
}

String flashPluralLabel(FlashKind kind) =>
    kind == FlashKind.food ? 'Bites' : 'Flashes';

String flashSingularLabel(FlashKind kind) =>
    kind == FlashKind.food ? 'Bite' : 'Flash';

String flashOwnLabel(FlashKind kind) =>
    kind == FlashKind.food ? 'Your Bite' : 'Your Flash';

class FlashItem {
  const FlashItem({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.mediaPath,
    required this.createdAt,
    this.mediaUrl = '',
    this.remoteId = '',
    this.caption = '',
    this.seen = false,
    this.kind = FlashKind.outfit,
  });

  final String id;
  final String username;
  final String avatarUrl;
  final String mediaPath;
  final String mediaUrl;
  final String remoteId;
  final DateTime createdAt;
  final String caption;
  final bool seen;
  final FlashKind kind;

  bool get isFood => kind == FlashKind.food;

  static const lifetime = Duration(hours: 24);

  bool get isExpired => DateTime.now().isAfter(createdAt.add(lifetime));

  bool get isPublished => remoteId.trim().isNotEmpty;

  String get mergeKey {
    final remote = remoteId.trim();
    if (remote.isNotEmpty) {
      return 'r:$remote';
    }
    return 'l:$id';
  }

  FlashItem copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    String? mediaPath,
    String? mediaUrl,
    String? remoteId,
    DateTime? createdAt,
    String? caption,
    bool? seen,
    FlashKind? kind,
  }) {
    return FlashItem(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      remoteId: remoteId ?? this.remoteId,
      createdAt: createdAt ?? this.createdAt,
      caption: caption ?? this.caption,
      seen: seen ?? this.seen,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'mediaPath': mediaPath,
      'mediaUrl': mediaUrl,
      'remoteId': remoteId,
      'createdAt': createdAt.toIso8601String(),
      'caption': caption,
      'seen': seen,
      'flashKind': kind.name,
    };
  }

  factory FlashItem.fromJson(Map<String, dynamic> json) {
    return FlashItem(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url'] ?? '').toString(),
      mediaPath: (json['mediaPath'] ?? json['media_path'] ?? '').toString(),
      mediaUrl: (json['mediaUrl'] ?? json['media_url'] ?? '').toString(),
      remoteId: (json['remoteId'] ?? json['remote_id'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      caption: (json['caption'] ?? '').toString(),
      seen: json['seen'] == true,
      kind: flashKindFrom(
        json['flashKind'] ?? json['post_type'] ?? json['feed_type'],
      ),
    );
  }
}

class FlashBucket {
  const FlashBucket({
    required this.username,
    required this.avatarUrl,
    required this.items,
    required this.isMine,
    this.kind = FlashKind.outfit,
  });

  final String username;
  final String avatarUrl;
  final List<FlashItem> items;
  final bool isMine;
  final FlashKind kind;

  bool get hasUnseen => items.any((item) => !item.seen);
}
