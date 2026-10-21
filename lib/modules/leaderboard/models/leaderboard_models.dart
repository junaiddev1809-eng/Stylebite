class LeaderboardContestContext {
  const LeaderboardContestContext({
    required this.id,
    required this.source,
    required this.name,
    required this.subtitle,
    required this.format,
    required this.window,
    required this.status,
    required this.heroTitle,
    required this.heroMeta,
    required this.participants,
    required this.defaultPeriod,
    required this.defaultCategory,
    this.team1Name,
    this.team1Pct,
    this.team2Name,
    this.team2Pct,
  });

  final String id;
  final String source;
  final String name;
  final String subtitle;
  final String format;
  final String window;
  final String status;
  final String heroTitle;
  final String heroMeta;
  final String participants;
  final String defaultPeriod;
  final String defaultCategory;
  final String? team1Name;
  final int? team1Pct;
  final String? team2Name;
  final int? team2Pct;

  bool get hasTeams =>
      team1Name != null &&
      team1Pct != null &&
      team2Name != null &&
      team2Pct != null;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.handle,
    required this.points,
    required this.earnings,
    required this.avatar,
  });

  final int rank;
  final String name;
  final String handle;
  final String points;
  final String earnings;
  final String avatar;
}
