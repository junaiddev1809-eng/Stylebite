class ContestRankingModel {
  const ContestRankingModel({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.rank,
    required this.rankPosition,
    required this.score,
    required this.city,
    required this.memberCount,
    this.postId,
    this.submissionId,
  });

  final int userId;
  final String username;
  final String avatarUrl;
  final int rank;
  final int? rankPosition;
  final double score;
  final String city;
  final int memberCount;
  final int? postId;
  final int? submissionId;

  factory ContestRankingModel.fromJson(Map<String, dynamic> json) {
    return ContestRankingModel(
      userId: _readInt(json['user_id']),
      username: _readString(json['username']),
      avatarUrl: _readString(json['avatar_url']),
      rank: _readInt(json['rank'] ?? json['rank_position']),
      rankPosition: _readNullableInt(
        json['rank_position'] ?? json['rankPosition'],
      ),
      score: _readDouble(json['score']),
      city: _readString(json['city']),
      memberCount: _readInt(json['member_count']),
      postId: _readNullableInt(json['post_id']),
      submissionId: _readNullableInt(json['submission_id']),
    );
  }
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse('${value ?? ''}') ?? fallback;
}

int? _readNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString().trim());
}

double _readDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse('${value ?? ''}') ?? fallback;
}

String _readString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return fallback;
  return text;
}
