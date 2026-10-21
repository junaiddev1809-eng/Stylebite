import 'dart:convert';

import '../../../core/utils/api_helper.dart';

/// Which contest a post is entered in. `contestId` is 0 when only the
/// enrollment is known (older API payloads without contest metadata).
class ContestEnrollmentInfo {
  const ContestEnrollmentInfo({
    required this.contestId,
    required this.contestTitle,
  });

  final int contestId;
  final String contestTitle;

  bool get hasContest => contestId > 0;

  ContestEnrollmentInfo merge(ContestEnrollmentInfo other) {
    return ContestEnrollmentInfo(
      contestId: other.contestId > 0 ? other.contestId : contestId,
      contestTitle: other.contestTitle.trim().isNotEmpty
          ? other.contestTitle
          : contestTitle,
    );
  }
}

/// Post IDs currently enrolled in a contest (plus which contest). Feed,
/// reel, profile and detail cards use this so rating + contest badges show
/// on those posts even when the live feed payload has no `in_contest` /
/// `contest` fields.
class ContestEnrollmentStore {
  ContestEnrollmentStore._();

  static final ContestEnrollmentStore instance = ContestEnrollmentStore._();

  final Map<String, ContestEnrollmentInfo> _byPostId =
      <String, ContestEnrollmentInfo>{};
  DateTime? _loadedAt;
  Future<void>? _inFlight;

  bool contains(String? postId) {
    final id = _normalizeId(postId);
    return id.isNotEmpty && _byPostId.containsKey(id);
  }

  ContestEnrollmentInfo? infoFor(String? postId) {
    final id = _normalizeId(postId);
    if (id.isEmpty) {
      return null;
    }
    return _byPostId[id];
  }

  void add(dynamic postId, {int contestId = 0, String contestTitle = ''}) {
    final id = _normalizeId('$postId');
    if (id.isEmpty) {
      return;
    }
    final incoming = ContestEnrollmentInfo(
      contestId: contestId,
      contestTitle: contestTitle.trim(),
    );
    final existing = _byPostId[id];
    _byPostId[id] = existing == null ? incoming : existing.merge(incoming);
  }

  void addAll(
    Iterable<dynamic> postIds, {
    int contestId = 0,
    String contestTitle = '',
  }) {
    for (final postId in postIds) {
      add(postId, contestId: contestId, contestTitle: contestTitle);
    }
  }

  Future<void> ensureLoaded() {
    final loadedAt = _loadedAt;
    if (loadedAt != null &&
        DateTime.now().difference(loadedAt) < const Duration(minutes: 5) &&
        _inFlight == null) {
      return Future<void>.value();
    }
    return refresh();
  }

  Future<void> refresh() {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _load();
    _inFlight = future;
    return future.whenComplete(() {
      if (identical(_inFlight, future)) {
        _inFlight = null;
      }
    });
  }

  Future<void> _load() async {
    try {
      if (await _loadFromEnrolledEndpoint()) {
        _loadedAt = DateTime.now();
        return;
      }
      await _loadFromContestLists();
      _loadedAt = DateTime.now();
    } catch (_) {
      _loadedAt = DateTime.now();
    }
  }

  Future<bool> _loadFromEnrolledEndpoint() async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'contests/enrolled-posts',
      );
      if (response == null || response.statusCode != 200) {
        return false;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return false;
      }
      final payload = Map<String, dynamic>.from(decoded);
      if ('${payload['status_code']}' != '1') {
        return false;
      }
      final posts = payload['posts'];
      if (posts is List && posts.isNotEmpty) {
        for (final item in posts) {
          if (item is! Map) {
            continue;
          }
          add(
            item['post_id'],
            contestId: int.tryParse('${item['contest_id'] ?? ''}') ?? 0,
            contestTitle: (item['contest_title'] ?? '').toString(),
          );
        }
        return true;
      }
      final ids = payload['post_ids'];
      if (ids is! List) {
        return false;
      }
      addAll(ids);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadFromContestLists() async {
    final contests = <Map<String, dynamic>>[
      ...await _fetchContestMaps('contests/home'),
      ...await _fetchContestMaps('contests/admin'),
    ];
    final missingDetailIds = <int>[];
    for (final contest in contests) {
      final before = _byPostId.length;
      _ingestContest(contest);
      final contestId = int.tryParse('${contest['id'] ?? ''}');
      if (contestId != null && _byPostId.length == before) {
        missingDetailIds.add(contestId);
      }
    }
    await Future.wait(
      missingDetailIds.take(20).map(_loadContestDetail),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchContestMaps(String endpoint) async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
      if (response == null || response.statusCode != 200) {
        return const <Map<String, dynamic>>[];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return const <Map<String, dynamic>>[];
      }
      final payload = Map<String, dynamic>.from(decoded);
      final list =
          payload['contests'] ?? payload['data']?['contests'] ?? payload['data'];
      if (list is! List) {
        return const <Map<String, dynamic>>[];
      }
      return list.whereType<Map>().map((item) {
        return item.map((key, value) => MapEntry(key.toString(), value));
      }).toList(growable: false);
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  Future<void> _loadContestDetail(int contestId) async {
    try {
      final response = await ApiHelper.fetchDataWithAuthorization(
        'contests/$contestId',
      );
      if (response == null || response.statusCode != 200) {
        return;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return;
      }
      final payload = Map<String, dynamic>.from(decoded);
      final contest = payload['contest'] ?? payload['data']?['contest'];
      if (contest is Map) {
        _ingestContest(
          contest.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {}
  }

  void _ingestContest(Map<String, dynamic> contest) {
    final contestId = int.tryParse('${contest['id'] ?? ''}') ?? 0;
    final contestTitle = (contest['title'] ?? '').toString();
    addAll(
      contest['enrolled_post_ids'] as List<dynamic>? ?? const [],
      contestId: contestId,
      contestTitle: contestTitle,
    );
    addAll(
      contest['post_ids'] as List<dynamic>? ?? const [],
      contestId: contestId,
      contestTitle: contestTitle,
    );
    final submissions = contest['submissions'];
    if (submissions is! List) {
      return;
    }
    for (final item in submissions) {
      if (item is! Map) {
        continue;
      }
      add(
        item['post_id'] ?? item['postId'],
        contestId: contestId,
        contestTitle: contestTitle,
      );
    }
  }

  String _normalizeId(String? raw) {
    final id = (raw ?? '').trim();
    if (id.isEmpty || id == '0' || id == 'null') {
      return '';
    }
    return id;
  }
}
