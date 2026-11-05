enum StoryKind { outfit, food }

StoryKind storyKindFrom(Object? raw) {
  final value = (raw ?? '').toString().trim().toLowerCase();
  if (value == 'food' || value == 'bite' || value == '2') {
    return StoryKind.food;
  }
  return StoryKind.outfit;
}

class StoryViewer {
  const StoryViewer({
    required this.userId,
    required this.username,
    this.fullName = '',
    this.avatarUrl = '',
    this.viewedAt,
  });

  final int userId;
  final String username;
  final String fullName;
  final String avatarUrl;
  final DateTime? viewedAt;

  factory StoryViewer.fromJson(Map<String, dynamic> json) {
    return StoryViewer(
      userId: int.tryParse((json['user_id'] ?? '').toString()) ?? 0,
      username: (json['username'] ?? '').toString().trim().replaceFirst('@', ''),
      fullName: (json['full_name'] ?? '').toString().trim(),
      avatarUrl: (json['avatar_url'] ?? '').toString().trim(),
      viewedAt: DateTime.tryParse((json['viewed_at'] ?? '').toString()),
    );
  }
}

class StoryItem {
  const StoryItem({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.mediaPath,
    required this.createdAt,
    this.mediaUrl = '',
    this.posterUrl = '',
    this.remoteId = '',
    this.caption = '',
    this.isVideo = false,
    this.seen = false,
    this.kind = StoryKind.outfit,
    this.viewCount = 0,
  });

  final String id;
  final String username;
  final String avatarUrl;
  final String mediaPath;
  final String mediaUrl;
  /// Optional still frame for video stories (chat reply card).
  final String posterUrl;
  final String remoteId;
  final DateTime createdAt;
  final String caption;
  final bool isVideo;
  final bool seen;
  final StoryKind kind;
  /// Owner-only; 0 for everyone else's stories.
  final int viewCount;

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
    String? posterUrl,
    String? remoteId,
    DateTime? createdAt,
    String? caption,
    bool? isVideo,
    bool? seen,
    StoryKind? kind,
    int? viewCount,
  }) {
    return StoryItem(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      posterUrl: posterUrl ?? this.posterUrl,
      remoteId: remoteId ?? this.remoteId,
      createdAt: createdAt ?? this.createdAt,
      caption: caption ?? this.caption,
      isVideo: isVideo ?? this.isVideo,
      seen: seen ?? this.seen,
      kind: kind ?? this.kind,
      viewCount: viewCount ?? this.viewCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'avatarUrl': avatarUrl,
      'mediaPath': mediaPath,
      'mediaUrl': mediaUrl,
      'posterUrl': posterUrl,
      'remoteId': remoteId,
      'createdAt': createdAt.toIso8601String(),
      'caption': caption,
      'isVideo': isVideo,
      'seen': seen,
      'storyKind': kind.name,
      'viewCount': viewCount,
    };
  }

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar_url'] ?? '').toString(),
      mediaPath: (json['mediaPath'] ?? json['media_path'] ?? '').toString(),
      mediaUrl: (json['mediaUrl'] ?? json['media_url'] ?? '').toString(),
      posterUrl: (json['posterUrl'] ?? json['poster_url'] ?? '').toString(),
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
      viewCount: int.tryParse(
            (json['viewCount'] ?? json['view_count'] ?? 0).toString(),
          ) ??
          0,
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
