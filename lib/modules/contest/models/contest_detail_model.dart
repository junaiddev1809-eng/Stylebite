import '../utils/contest_date_parser.dart';
import 'contest_invitation_model.dart';
import 'contest_prize.dart';
import 'contest_ranking_model.dart';
import 'contest_submission_model.dart';

class ContestDetailModel {
  const ContestDetailModel({
    required this.id,
    required this.title,
    required this.description,
    required this.contestType,
    required this.status,
    required this.coverImageUrl,
    required this.isAdminContest,
    required this.hasReward,
    required this.rewardAmount,
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
    this.prizes = const [],
  });

  final int id;
  final String title;
  final String description;
  final String contestType;
  final String status;
  final String coverImageUrl;
  final bool isAdminContest;
  final bool hasReward;
  final double rewardAmount;
  final bool featured;
  final DateTime? startAt;
  final DateTime? endAt;
  final int participantCount;
  final int maxParticipants;
  final DateTime? enrollmentStartAt;
  final DateTime? enrollmentEndAt;
  final DateTime? votingStartAt;
  final DateTime? votingEndAt;
  final List<ContestRankingModel> participantsRanking;
  final List<ContestRankingModel> teamRanking;
  final List<ContestSubmissionModel> submissions;
  final List<ContestInvitationTargetModel> joinableUsers;
  final bool canJoin;
  final List<ContestPrize> prizes;

  String get statusLabel => status.replaceAll('_', ' ').toUpperCase();

  /// Official prize place for this entry, or the current top standing when
  /// winners have not been assigned yet.
  int? placeForSubmission(ContestSubmissionModel submission) {
    for (final prize in prizes) {
      if (prize.winnerUserId > 0 && prize.winnerUserId == submission.userId) {
        return prize.place;
      }
      final winner = prize.winner
          .replaceFirst(RegExp(r'^@+'), '')
          .trim()
          .toLowerCase();
      final username = submission.username
          .replaceFirst(RegExp(r'^@+'), '')
          .trim()
          .toLowerCase();
      if (winner.isNotEmpty && winner == username) {
        return prize.place;
      }
    }

    final hasOfficialWinner = prizes.any(
      (prize) => prize.winnerUserId > 0 || prize.winner.trim().isNotEmpty,
    );
    if (hasOfficialWinner) {
      return null;
    }

    var rank = submission.rankPosition ?? 0;
    if (rank <= 0) {
      for (final row in liveParticipantsRanking) {
        final sameUser =
            submission.userId > 0 && row.userId == submission.userId;
        final sameName =
            submission.username.trim().isNotEmpty &&
            row.username.trim().toLowerCase() ==
                submission.username.trim().toLowerCase();
        if (sameUser || sameName) {
          rank = row.rankPosition ?? row.rank;
          break;
        }
      }
    }
    if (rank <= 0) {
      return null;
    }

    final slots = prizes.isNotEmpty ? prizes.length : 3;
    if (rank > slots) {
      return null;
    }
    return rank;
  }

  String get typeLabel => 'Contest';

  List<ContestSubmissionModel> get visibleSubmissions => submissions
      .where((item) => item.hasVisibleMedia)
      .toList(growable: false);

  /// Participants whose entry is still live. The live API returns every
  /// approved participant, including ones whose post was later deleted or
  /// removed; those have no visible submission and must not be ranked.
  List<ContestRankingModel> get liveParticipantsRanking {
    // Older payloads carry no submissions at all — nothing to cross-check.
    if (submissions.isEmpty) {
      return participantsRanking;
    }
    final liveUserIds = <int>{};
    final liveUsernames = <String>{};
    for (final submission in visibleSubmissions) {
      if (submission.userId > 0) {
        liveUserIds.add(submission.userId);
      }
      final name = submission.username.trim().toLowerCase();
      if (name.isNotEmpty && name != 'unknown') {
        liveUsernames.add(name);
      }
    }
    return participantsRanking.where((item) {
      if (item.userId > 0 && liveUserIds.contains(item.userId)) {
        return true;
      }
      return liveUsernames.contains(item.username.trim().toLowerCase());
    }).toList(growable: false);
  }

  int get liveParticipantCount => submissions.isEmpty
      ? participantCount
      : liveParticipantsRanking.length;

  String get subtitle => contestPrizeSubtitle(
    prizes: prizes,
    hasReward: hasReward,
    rewardAmount: rewardAmount,
  );

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

  factory ContestDetailModel.fromJson(Map<String, dynamic> json) {
    return ContestDetailModel(
      id: _readInt(json['id']),
      title: _readString(json['title'], fallback: 'Untitled contest'),
      description: _readString(json['description']),
      contestType: _readString(json['contest_type'], fallback: 'contest'),
      status: _readString(json['status'], fallback: 'unknown'),
      coverImageUrl: _readString(json['cover_image_url']),
      isAdminContest: _readBool(
        json['is_admin_contest'] ?? json['admin_contest'],
      ),
      hasReward: _readBool(json['has_reward']),
      rewardAmount: _readDouble(json['reward_amount']),
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
              .map(ContestRankingModel.fromJson)
              .toList(growable: false),
      teamRanking: (json['team_ranking'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(ContestRankingModel.fromJson)
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
      prizes: readContestPrizes(json['prizes']),
    );
  }
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse('${value ?? ''}') ?? fallback;
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

DateTime? _readDate(dynamic value) => parseContestDate(value);
