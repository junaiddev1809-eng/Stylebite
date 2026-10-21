import '../utils/contest_date_parser.dart';

class ContestInvitationTargetModel {
  const ContestInvitationTargetModel({
    required this.userId,
    required this.username,
    required this.avatarUrl,
  });

  final int userId;
  final String username;
  final String avatarUrl;

  factory ContestInvitationTargetModel.fromJson(Map<String, dynamic> json) {
    return ContestInvitationTargetModel(
      userId: _readInt(json['user_id']),
      username: _readString(json['username'], fallback: 'Unknown'),
      avatarUrl: _readString(json['avatar_url']),
    );
  }
}

class ContestInvitationModel {
  const ContestInvitationModel({
    required this.id,
    required this.contestId,
    required this.contestTitle,
    required this.invitationType,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final int contestId;
  final String contestTitle;
  final String invitationType;
  final String status;
  final DateTime? createdAt;

  bool get isPending => status.toLowerCase() == 'pending';

  factory ContestInvitationModel.fromJson(Map<String, dynamic> json) {
    return ContestInvitationModel(
      id: _readInt(json['id']),
      contestId: _readInt(json['contest_id']),
      contestTitle: _readString(
        json['contest_title'] ?? json['contest']?['title'],
        fallback: 'Contest',
      ),
      invitationType: _readString(json['type'], fallback: 'invite'),
      status: _readString(json['status'], fallback: 'pending'),
      createdAt: _readDate(json['created_at']),
    );
  }
}

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

DateTime? _readDate(dynamic value) => parseContestDate(value);
