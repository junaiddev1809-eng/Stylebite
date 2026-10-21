import '../utils/contest_date_parser.dart';
import 'contest_invitation_model.dart';
import 'contest_prize.dart';

String _readString(dynamic value, {String fallback = ''}) {
  final resolved = value?.toString().trim();
  if (resolved == null || resolved.isEmpty || resolved == 'null') {
    return fallback;
  }
  return resolved;
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  return int.tryParse('${value ?? ''}') ?? fallback;
}

double _readDouble(dynamic value, {double fallback = 0}) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('${value ?? ''}') ?? fallback;
}

bool _readBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  final normalized = value?.toString().toLowerCase().trim();
  if (normalized == '1' || normalized == 'true') {
    return true;
  }
  if (normalized == '0' || normalized == 'false') {
    return false;
  }
  return fallback;
}

DateTime? _readDate(dynamic value) => parseContestDate(value);

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

String _firstString(List<Map<String, dynamic>> items, String key) {
  if (items.isEmpty) {
    return '';
  }
  return _readString(items.first[key]);
}

enum ContestCategory { admin, community }

class ContestParticipantRankingModel {
  const ContestParticipantRankingModel({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.rank,
    required this.score,
  });

  final int userId;
  final String username;
  final String avatarUrl;
  final int rank;
  final double score;

  factory ContestParticipantRankingModel.fromJson(Map<String, dynamic> json) {
    return ContestParticipantRankingModel(
      userId: _readInt(json['user_id']),
      username: _readString(json['username'], fallback: 'Unknown'),
      avatarUrl: _readString(json['avatar_url']),
      rank: _readInt(json['rank'] ?? json['rank_position']),
      score: _readDouble(json['score']),
    );
  }
}

class ContestTeamRankingModel {
  const ContestTeamRankingModel({
    required this.city,
    required this.rank,
    required this.score,
    required this.memberCount,
  });

  final String city;
  final int rank;
  final double score;
  final int memberCount;

  factory ContestTeamRankingModel.fromJson(Map<String, dynamic> json) {
    return ContestTeamRankingModel(
      city: _readString(json['city'], fallback: 'Unknown city'),
      rank: _readInt(json['rank']),
      score: _readDouble(json['score']),
      memberCount: _readInt(json['member_count']),
    );
  }
}

class ContestSubmissionModel {
  const ContestSubmissionModel({
    required this.id,
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
    required this.isMine,
    required this.submittedAt,
  });

  final int id;
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
  final bool isMine;
  final DateTime? submittedAt;

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
      isMine: _readBool(json['is_mine']),
      submittedAt: _readDate(json['submitted_at']),
    );
  }
}

class ContestModel {
  const ContestModel({
    required this.id,
    required this.title,
    required this.description,
    required this.contestType,
    required this.status,
    required this.coverImageUrl,
    required this.hasReward,
    required this.rewardAmount,
    required this.isAdminContest,
    required this.featured,
    required this.startAt,
    required this.endAt,
    required this.participantCount,
    required this.maxParticipants,
    required this.enrollmentStartAt,
    required this.enrollmentEndAt,
    required this.votingStartAt,
    required this.votingEndAt,
    required this.participantsRanking,
    required this.teamRanking,
    required this.submissions,
    required this.joinableUsers,
    required this.canJoin,
    required this.winner,
    required this.userRank,
    required this.userScore,
    this.enrolledPostIds = const [],
    this.prizes = const [],
  });

  final int id;
  final String title;
  final String description;
  final String contestType;
  final String status;
  final String coverImageUrl;
  final bool hasReward;
  final double rewardAmount;
  final bool isAdminContest;
  final bool featured;
  final DateTime? startAt;
  final DateTime? endAt;
  final int participantCount;
  final int maxParticipants;
  final DateTime? enrollmentStartAt;
  final DateTime? enrollmentEndAt;
  final DateTime? votingStartAt;
  final DateTime? votingEndAt;
  final List<ContestParticipantRankingModel> participantsRanking;
  final List<ContestTeamRankingModel> teamRanking;
  final List<ContestSubmissionModel> submissions;
  final List<ContestInvitationTargetModel> joinableUsers;
  final bool canJoin;
  final String winner;
  final int userRank;
  final double userScore;
  final List<int> enrolledPostIds;
  final List<ContestPrize> prizes;

  factory ContestModel.fromJson(Map<String, dynamic> json) {
    return ContestModel(
      id: _readInt(json['id']),
      title: _readString(json['title'], fallback: 'Untitled contest'),
      description: _readString(json['description']),
      contestType: _readString(json['contest_type'], fallback: 'contest'),
      status: _readString(json['status'], fallback: 'unknown'),
      coverImageUrl: _readString(json['cover_image_url']),
      hasReward: _readBool(json['has_reward']),
      rewardAmount: _readDouble(json['reward_amount']),
      isAdminContest: _readBool(json['is_admin_contest']),
      featured: _readBool(json['featured']),
      startAt: _readDate(json['start_at']),
      endAt: _readDate(json['end_at']),
      participantCount: _readInt(json['participant_count']),
      maxParticipants: _readInt(json['max_participants']),
      enrollmentStartAt: _readDate(json['enrollment_start_at']),
      enrollmentEndAt: _readDate(json['enrollment_end_at']),
      votingStartAt: _readDate(json['voting_start_at']),
      votingEndAt: _readDate(json['voting_end_at']),
      participantsRanking:
          (json['participants_ranking'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(ContestParticipantRankingModel.fromJson)
              .toList(growable: false),
      teamRanking: (json['team_ranking'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ContestTeamRankingModel.fromJson)
          .toList(growable: false),
      submissions: (json['submissions'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ContestSubmissionModel.fromJson)
          .toList(growable: false),
      joinableUsers:
          (json['joinable_users'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<String, dynamic>>()
              .map(ContestInvitationTargetModel.fromJson)
              .toList(growable: false),
      canJoin: _readBool(json['can_join']),
      winner: _readString(json['winner']),
      userRank: _readInt(json['user_rank']),
      userScore: _readDouble(json['user_score']),
      enrolledPostIds:
          (json['enrolled_post_ids'] as List<dynamic>? ?? const <dynamic>[])
              .map(_readInt)
              .where((id) => id > 0)
              .toList(growable: false),
      prizes: readContestPrizes(json['prizes']),
    );
  }

  bool get isAdminTabItem => hasReward || isAdminContest;

  bool get ended => status.toLowerCase() == 'completed';

  String get imageUrl => coverImageUrl;

  List<String> get badges => <String>[statusLabel, typeLabel];

  String get statusLabel => status.replaceAll('_', ' ').toUpperCase();

  String get typeLabel => 'Contest';

  bool matchesParticipantSearch(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return true;
    }
    bool contains(String value) => value.toLowerCase().contains(needle);
    if (contains(title) || contains(description)) {
      return true;
    }
    for (final person in participantsRanking) {
      if (contains(person.username)) {
        return true;
      }
    }
    for (final submission in submissions) {
      if (contains(submission.username) || contains(submission.fullName)) {
        return true;
      }
    }
    return false;
  }

  String get subtitle => contestPrizeSubtitle(
    prizes: prizes,
    hasReward: hasReward,
    rewardAmount: rewardAmount,
  );

  String get primaryCta => ended ? 'View Results' : 'Join Contest';

  String? get secondaryCta => 'Leaderboard';

  bool get _hasStarted {
    final start = startAt;
    return start == null || !start.isAfter(DateTime.now());
  }

  bool get _hasEnded {
    final end = endAt;
    return end != null && end.isBefore(DateTime.now());
  }

  String get timeCaption {
    if (_hasEnded) {
      return 'ENDED';
    }
    if (!_hasStarted) {
      return 'STARTS IN';
    }
    return 'TIME LEFT';
  }

  String get timeLabel {
    if (_hasEnded) {
      return 'Ended';
    }

    final target = _hasStarted ? endAt : startAt;
    if (target == null) {
      return 'TBA';
    }
    final now = DateTime.now();
    if (target.isBefore(now)) {
      return 'Ended';
    }
    final diff = target.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours.remainder(24);
    if (days > 0) {
      return '${days}d ${hours}h';
    }
    final mins = diff.inMinutes.remainder(60);
    return '${diff.inHours}h ${mins}m';
  }
}
