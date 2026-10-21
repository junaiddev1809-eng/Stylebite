import '../utils/contest_date_parser.dart';

class ContestSubmissionModel {
  const ContestSubmissionModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    required this.fullName,
    required this.avatarUrl,
    required this.mediaType,
    required this.mediaUrl,
    required this.mediaThumbnailUrl,
    required this.caption,
    required this.postStatus,
    required this.totalScore,
    required this.totalVotes,
    this.ratingAverage = 0,
    required this.isMine,
    required this.submittedAt,
    this.viewerScore,
    this.rankPosition,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isSaved = false,
  });

  final int id;
  final int postId;
  final int userId;
  final String username;
  final String fullName;
  final String avatarUrl;
  final String mediaType;
  final String mediaUrl;
  final String mediaThumbnailUrl;
  final String caption;
  final String postStatus;
  final double totalScore;
  final int totalVotes;

  /// Average of the 1–5 contest ratings. Separate from [totalScore], which
  /// is the contest result used for ranking.
  final double ratingAverage;
  final bool isMine;
  final DateTime? submittedAt;

  /// The current viewer's own rating (1–5), null when they haven't voted.
  final int? viewerScore;
  final int? rankPosition;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isSaved;

  bool get hasVisibleMedia =>
      mediaUrl.trim().isNotEmpty || mediaThumbnailUrl.trim().isNotEmpty;

  factory ContestSubmissionModel.fromJson(Map<String, dynamic> json) {
    final media = _asMap(json['media']);
    final post = _asMap(json['post']);
    final postMedia = _asList(post['media']);
    final resolvedMedia = media.isNotEmpty
        ? media
        : postMedia.isNotEmpty
        ? postMedia.first
        : const <String, dynamic>{};

    return ContestSubmissionModel(
      id: _readInt(json['id'] ?? json['submission_id']),
      postId: _readInt(json['post_id'] ?? post['id']),
      userId: _readInt(json['user_id']),
      username: _readString(json['username'], fallback: 'Unknown'),
      fullName: _readString(json['full_name']),
      avatarUrl: _readString(json['avatar_url']),
      mediaType: _readString(
        json['media_type'] ?? resolvedMedia['media_type'] ?? media['type'],
      ),
      mediaUrl: _readString(
        json['media_url'] ??
            media['url'] ??
            resolvedMedia['url'] ??
            _firstString(postMedia, 'url'),
      ),
      mediaThumbnailUrl: _readString(
        json['thumbnail_url'] ??
            media['thumbnail_url'] ??
            resolvedMedia['thumbnail_url'] ??
            _firstString(postMedia, 'thumbnail_url'),
      ),
      caption: _readString(json['caption']),
      postStatus: _readString(json['post_status']),
      totalScore: _readDouble(json['total_score'] ?? json['score']),
      totalVotes: _readInt(json['total_votes'] ?? json['votes_count']),
      ratingAverage: _readRatingAverage(json['rating_average'] ?? json['community_score']),
      isMine: _readBool(json['is_mine']),
      submittedAt: _readDate(json['submitted_at']),
      viewerScore: _readViewerScore(
        json['viewer_score'] ??
            json['my_vote'] ??
            json['my_score'] ??
            json['viewer_rating'],
      ),
      rankPosition: _readNullableRank(json['rank_position'] ?? json['rank']),
      likeCount: _readInt(json['like_count'] ?? post['like_count']),
      commentCount: _readInt(json['comment_count'] ?? post['comment_count']),
      isLiked: _readBool(json['is_liked'] ?? post['is_liked']),
      isSaved: _readBool(json['is_saved'] ?? post['is_saved']),
    );
  }
}

int? _readNullableRank(dynamic value) {
  if (value == null) return null;
  final parsed = value is int ? value : int.tryParse('$value');
  if (parsed == null || parsed <= 0) return null;
  return parsed;
}

int? _readViewerScore(dynamic value) {
  if (value == null) return null;
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  if (parsed == null || parsed <= 0) return null;
  return parsed.round().clamp(1, 5);
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse('${value ?? ''}') ?? fallback;
}

double _readRatingAverage(dynamic value) {
  final parsed = _readDouble(value, fallback: -1);
  if (!parsed.isFinite || parsed < 0 || parsed > 5) {
    return 0;
  }
  return parsed;
}

double _readDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase().trim();
  if (text == '1' || text == 'true') return true;
  if (text == '0' || text == 'false') return false;
  return fallback;
}

String _readString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return fallback;
  return text;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _asList(dynamic value) {
  if (value is List<dynamic>) {
    return value.whereType<Map<String, dynamic>>().toList(growable: false);
  }
  return const <Map<String, dynamic>>[];
}

DateTime? _readDate(dynamic value) => parseContestDate(value);

String _firstString(List<Map<String, dynamic>> items, String key) {
  if (items.isEmpty) return '';
  return _readString(items.first[key]);
}
