import '../../../core/utils/app_time_formatter.dart';
import '../../../core/utils/local_storage.dart';
import '../../../core/utils/verified_flag.dart';

class PostCommentModel {
  const PostCommentModel({
    required this.id,
    required this.user,
    required this.displayName,
    required this.avatar,
    required this.text,
    required this.time,
    this.commentId = '',
    this.parentReplyId,
    this.likes = 0,
    this.replyCount = 0,
    this.isLiked = false,
    this.replies = const <PostCommentModel>[],
    this.isVerifiedBadge = false,
  });

  final String id;
  final String user;
  final String displayName;
  final String avatar;
  final String text;
  final String time;
  final String commentId;
  final String? parentReplyId;
  final int likes;
  final int replyCount;
  final bool isLiked;
  final List<PostCommentModel> replies;
  final bool isVerifiedBadge;

  bool get hasAvatar => avatar.trim().isNotEmpty;
  bool get isLocalPending => id.startsWith('local-');

  bool get isOwnedByViewer {
    final currentUsername = LocalStorage.getUsername()
        ?.trim()
        .replaceFirst('@', '')
        .toLowerCase();
    if (currentUsername == null || currentUsername.isEmpty) {
      return false;
    }
    final commentUsername = user.trim().replaceFirst('@', '').toLowerCase();
    return commentUsername.isNotEmpty && commentUsername == currentUsername;
  }

  factory PostCommentModel.localFromViewer({
    required String text,
    String? commentId,
    String? parentReplyId,
  }) {
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final username = (LocalStorage.getUsername() ?? '')
        .trim()
        .replaceFirst('@', '');
    return PostCommentModel(
      id: localId,
      user: username.isEmpty ? 'you' : username,
      displayName: username.isEmpty ? 'You' : username,
      avatar: (LocalStorage.getAvatarUrl() ?? '').trim(),
      text: text,
      time: '1s',
      commentId: commentId ?? localId,
      parentReplyId: parentReplyId,
      likes: 0,
      replies: const <PostCommentModel>[],
    );
  }

  PostCommentModel copyWith({
    String? id,
    String? user,
    String? displayName,
    String? avatar,
    String? text,
    String? time,
    String? commentId,
    String? parentReplyId,
    int? likes,
    int? replyCount,
    bool? isLiked,
    List<PostCommentModel>? replies,
    bool? isVerifiedBadge,
  }) {
    return PostCommentModel(
      id: id ?? this.id,
      user: user ?? this.user,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      text: text ?? this.text,
      time: time ?? this.time,
      commentId: commentId ?? this.commentId,
      parentReplyId: parentReplyId ?? this.parentReplyId,
      likes: likes ?? this.likes,
      replyCount: replyCount ?? this.replyCount,
      isLiked: isLiked ?? this.isLiked,
      replies: replies ?? this.replies,
      isVerifiedBadge: isVerifiedBadge ?? this.isVerifiedBadge,
    );
  }

  factory PostCommentModel.fromJson(Map<String, dynamic> json) {
    final user = asStringKeyedMap(
      json['user'] ??
          json['commenter'] ??
          json['comment_user'] ??
          json['author'] ??
          json['profile'],
    );
    final profile = asStringKeyedMap(user['profile'] ?? json['profile']);
    final username = (user['username'] ?? json['username'] ?? '').toString();

    return PostCommentModel(
      id: (json['id'] ?? '').toString(),
      user: username,
      displayName: (user['display_name'] ??
              profile['display_name'] ??
              user['username'] ??
              '')
          .toString(),
      avatar: (user['avatar_url'] ??
              user['avatar'] ??
              profile['avatar_url'] ??
              profile['avatar'] ??
              json['avatar_url'] ??
              json['user_avatar'] ??
              json['commenter_avatar'] ??
              '')
          .toString(),
      text: (json['body'] ?? '').toString(),
      time: AppTimeFormatter.formatCommentTime(
        (json['created_at'] ?? '').toString(),
      ),
      commentId: (json['comment_id'] ?? json['id'] ?? '').toString(),
      parentReplyId: _nullableString(json['parent_reply_id']),
      likes: _asInt(json['like_count']),
      replyCount: _asInt(json['reply_count']),
      isVerifiedBadge: VerifiedBadgeCache.resolve(
        username,
        parseVerifiedFlag(json) || parseVerifiedFlag(user, profile),
      ),
      isLiked: _asBool(
        asStringKeyedMap(json['viewer_state'])['is_liked'],
      ),
      replies: (json['replies'] as List<dynamic>? ?? const [])
          .map(
            (item) => PostCommentModel.fromJson(asStringKeyedMap(item)),
          )
          .toList(growable: false),
    );
  }
}

String? _nullableString(dynamic value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty || normalized == 'null') {
    return null;
  }
  return normalized;
}

class PostCommentsPagination {
  const PostCommentsPagination({
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

  factory PostCommentsPagination.fromJson(Map<String, dynamic> json) {
    return PostCommentsPagination(
      currentPage: _asInt(json['current_page']),
      perPage: _asInt(json['per_page']),
      total: _asInt(json['total']),
      lastPage: _asInt(json['last_page']),
      hasMorePages: _asBool(json['has_more_pages']),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  return int.tryParse('${value ?? ''}') ?? fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final raw = (value ?? '').toString().toLowerCase();
  if (raw == 'true' || raw == '1') {
    return true;
  }
  if (raw == 'false' || raw == '0') {
    return false;
  }
  return fallback;
}
