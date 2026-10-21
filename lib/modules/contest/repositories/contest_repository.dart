import '../api/contest_api.dart';
import '../models/contest_detail_model.dart';
import '../models/contest_invitation_model.dart';
import '../models/contest_model.dart';
import '../models/pagination_model.dart';

class ContestListResponse {
  const ContestListResponse({required this.items, required this.pagination});

  final List<ContestModel> items;
  final PaginationModel pagination;
}

class ContestInvitationResponse {
  const ContestInvitationResponse({
    required this.items,
    required this.pagination,
  });

  final List<ContestInvitationModel> items;
  final PaginationModel pagination;
}

class ContestMetaOption {
  const ContestMetaOption({required this.id, required this.label});

  final int id;
  final String label;
}

class ContestRepository {
  ContestRepository({ContestApi? api}) : _api = api ?? ContestApi();

  final ContestApi _api;

  Future<ContestListResponse> getContests({String? type, int page = 1}) async {
    final payload = await _api.getContests(type: type, page: page);
    final list =
        (payload['data']?['contests'] ??
                payload['contests'] ??
                payload['data'] ??
                const <dynamic>[])
            as List<dynamic>;
    final contests = list
        .whereType<Map<String, dynamic>>()
        .map(ContestModel.fromJson)
        .toList(growable: false);
    final pagination = PaginationModel.fromJson(
      (payload['data']?['pagination'] ??
              payload['pagination'] ??
              const <String, dynamic>{})
          as Map<String, dynamic>,
    );
    return ContestListResponse(items: contests, pagination: pagination);
  }

  Future<ContestListResponse> getAdminContests({int page = 1}) async {
    final payload = await _api.getAdminContests(page: page);
    final list =
        (payload['data']?['contests'] ??
                payload['contests'] ??
                payload['data'] ??
                const <dynamic>[])
            as List<dynamic>;
    final contests = list
        .whereType<Map<String, dynamic>>()
        .map(ContestModel.fromJson)
        .toList(growable: false);
    final pagination = PaginationModel.fromJson(
      (payload['data']?['pagination'] ??
              payload['pagination'] ??
              const <String, dynamic>{})
          as Map<String, dynamic>,
    );
    return ContestListResponse(items: contests, pagination: pagination);
  }

  Future<ContestDetailModel> getContestDetail(int contestId) async {
    final payload = await _api.getContestDetail(contestId);
    final raw =
        (payload['data']?['contest'] ?? payload['contest'] ?? payload['data'])
            as Map<String, dynamic>;
    return ContestDetailModel.fromJson(raw);
  }

  Future<ContestListResponse> getProfileResults({int page = 1}) async {
    final payload = await _api.getProfileResults(page: page);
    final list =
        (payload['data']?['results'] ??
                payload['results'] ??
                payload['data'] ??
                const <dynamic>[])
            as List<dynamic>;
    final items = list
        .whereType<Map<String, dynamic>>()
        .map(ContestModel.fromJson)
        .toList(growable: false);
    final pagination = PaginationModel.fromJson(
      (payload['data']?['pagination'] ??
              payload['pagination'] ??
              const <String, dynamic>{})
          as Map<String, dynamic>,
    );
    return ContestListResponse(items: items, pagination: pagination);
  }

  Future<ContestInvitationResponse> getInvitations({int page = 1}) async {
    final payload = await _api.getInvitations(page: page);
    final list =
        (payload['data']?['invitations'] ??
                payload['invitations'] ??
                payload['data'] ??
                const <dynamic>[])
            as List<dynamic>;
    final items = list
        .whereType<Map<String, dynamic>>()
        .map(ContestInvitationModel.fromJson)
        .toList(growable: false);
    final pagination = PaginationModel.fromJson(
      (payload['data']?['pagination'] ??
              payload['pagination'] ??
              const <String, dynamic>{})
          as Map<String, dynamic>,
    );
    return ContestInvitationResponse(items: items, pagination: pagination);
  }

  Future<List<ContestMetaOption>> getContestUsers({
    required String scope,
    String? q,
  }) async {
    final payload = await _api.getContestUsers(scope: scope, q: q);
    final list =
        (payload['data']?['users'] ??
                payload['users'] ??
                payload['data'] ??
                const <dynamic>[])
            as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ContestMetaOption(
            id: _readInt(item['id'] ?? item['user_id']),
            label: _readString(
              item['username'] ?? item['name'],
              fallback: 'Unknown',
            ),
          ),
        )
        .toList(growable: false);
  }

  Future<List<String>> getCities({String? q}) async {
    final payload = await _api.getCities(q: q);
    final list =
        (payload['data']?['cities'] ??
                payload['cities'] ??
                payload['data'] ??
                const <dynamic>[])
            as List<dynamic>;
    return list
        .map(
          (item) => _readString(
            item is Map<String, dynamic>
                ? (item['name'] ?? item['city'])
                : item,
          ),
        )
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<String>> getTags() async {
    final payload = await _api.getTags();
    final list =
        (payload['data']?['tags'] ??
                payload['tags'] ??
                payload['data'] ??
                const <dynamic>[])
            as List<dynamic>;
    return list
        .map(
          (item) => _readString(
            item is Map<String, dynamic> ? (item['name'] ?? item['tag']) : item,
          ),
        )
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> createOneVsOne(ContestFormData data) =>
      _api.createOneVsOne(data);

  Future<void> createCityVsCity(ContestFormData data) =>
      _api.createCityVsCity(data);

  Future<void> requestJoin1v1(int contestId) => _api.requestJoin1v1(contestId);

  Future<void> requestJoin1v1WithProfile(
    int contestId,
    ContestFormData formData,
  ) => _api.requestJoin1v1WithProfile(contestId, formData);

  Future<void> respondInvitation(int invitationId, String status) =>
      _api.respondInvitation(invitationId, status);

  Future<void> selectOpponent(int contestId, int participantUserId) =>
      _api.selectOpponent(contestId, participantUserId);

  Future<void> joinCityContest(int contestId) =>
      _api.joinCityContest(contestId);

  Future<void> joinContest(int contestId, ContestFormData data) =>
      _api.joinContest(contestId, data);

  Future<void> submitContestOutfit(int contestId, ContestFormData data) =>
      _api.submitContestOutfit(contestId, data);

  Future<ContestDetailModel?> voteContest(
    int contestId,
    int submissionId,
    double score,
  ) async {
    final payload = await _api.voteContest(contestId, submissionId, score);
    final raw = payload['contest'] ?? payload['data']?['contest'];
    if (raw is! Map) {
      return null;
    }
    return ContestDetailModel.fromJson(Map<String, dynamic>.from(raw));
  }
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse('${value ?? ''}') ?? fallback;
}

String _readString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty || text == 'null') return fallback;
  return text;
}
