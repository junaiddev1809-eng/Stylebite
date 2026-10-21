enum StoryKind { outfit, food }

StoryKind storyKindFrom(Object? raw) {
  final value = (raw ?? '').toString().trim().toLowerCase();
  if (value == 'food' || value == 'bite' || value == '2') {
    return StoryKind.food;
  }
  return StoryKind.outfit;
}

class StoryItem {
  const StoryItem({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.mediaPath,
    required this.createdAt,
    this.mediaUrl = '',
    this.remoteId = '',
    this.caption = '',
    this.isVideo = false,
    this.seen = false,
    this.kind = StoryKind.outfit,
  });

  final String id;
  final String username;
  final String avatarUrl;
  final String mediaPath;
  final String mediaUrl;
  final String remoteId;
  final DateTime createdAt;
  final String caption;
  final bool isVideo;
  final bool seen;
  final StoryKind kind;

  bool get isFood => kind == StoryKind.food;

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

  StoryItem copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    String? mediaPath,
    String? mediaUrl,
    String? remoteId,
    DateTime? createdAt,
    String? caption,
    bool? isVideo,
    bool? seen,
    StoryKind? kind,
  }) {
    return StoryItem(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      remoteId: remoteId ?? this.remoteId,
      createdAt: createdAt ?? this.createdAt,
      caption: caption ?? this.caption,
      isVideo: isVideo ?? this.isVideo,
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
      'isVideo': isVideo,
      'seen': seen,
      'storyKind': kind.name,
    };
  }

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url'] ?? '').toString(),
      mediaPath: (json['mediaPath'] ?? json['media_path'] ?? '').toString(),
      mediaUrl: (json['mediaUrl'] ?? json['media_url'] ?? '').toString(),
      remoteId: (json['remoteId'] ?? json['remote_id'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? json['created_at'] ?? '').toString()) ??
          DateTime.now(),
      caption: (json['caption'] ?? '').toString(),
      isVideo: json['isVideo'] == true || json['is_video'] == true,
      seen: json['seen'] == true,
      kind: storyKindFrom(
        json['storyKind'] ?? json['post_type'] ?? json['feed_type'],
      ),
    );
  }
}

class StoryBucket {
  const StoryBucket({
    required this.username,
    required this.avatarUrl,
    required this.items,
    required this.isMine,
    this.kind = StoryKind.outfit,
  });

  final String username;
  final String avatarUrl;
  final List<StoryItem> items;
  final bool isMine;
  final StoryKind kind;

  bool get hasUnseen => items.any((item) => !item.seen);
}

class StoryPeer {
  const StoryPeer({
    required this.username,
    required this.avatarUrl,
  });

  final String username;
  final String avatarUrl;
}
