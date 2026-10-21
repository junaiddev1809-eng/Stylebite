import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/utils/api_helper.dart';

class ContestFormData {
  ContestFormData({
    Map<String, String>? fields,
    Map<String, String>? arrayFields,
    Map<String, String>? filePaths,
  }) : fields = fields ?? <String, String>{},
       arrayFields = arrayFields ?? <String, String>{},
       filePaths = filePaths ?? <String, String>{};

  final Map<String, String> fields;
  final Map<String, String> arrayFields;
  final Map<String, String> filePaths;

  Map<String, String> toMultipartFields() => <String, String>{
    ...fields,
    ...arrayFields,
  };
}

class ContestApi {
  Future<Map<String, dynamic>> getContests({String? type, int page = 1}) async {
    final query = <String, String>{'page': '$page'};
    if (type != null && type.trim().isNotEmpty) {
      query['type'] = type.trim();
    }
    final endpoint = Uri(
      path: 'contests/home',
      queryParameters: query,
    ).toString();
    final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
    return _parse(response, fallbackMessage: 'Failed to fetch contests');
  }

  Future<Map<String, dynamic>> getAdminContests({int page = 1}) async {
    final endpoint = Uri(
      path: 'contests/admin',
      queryParameters: <String, String>{'page': '$page'},
    ).toString();
    final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
    return _parse(response, fallbackMessage: 'Failed to fetch admin contests');
  }

  Future<Map<String, dynamic>> getContestDetail(int contestId) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      'contests/$contestId',
    );
    return _parse(response, fallbackMessage: 'Failed to fetch contest detail');
  }

  Future<Map<String, dynamic>> getProfileResults({int page = 1}) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      'contests/profile/results?page=$page',
    );
    return _parse(response, fallbackMessage: 'Failed to fetch profile results');
  }

  Future<Map<String, dynamic>> getInvitations({int page = 1}) async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      'contests/invitations?page=$page',
    );
    return _parse(response, fallbackMessage: 'Failed to fetch invitations');
  }

  Future<Map<String, dynamic>> getContestUsers({
    required String scope,
    String? q,
  }) async {
    final query = <String, String>{'scope': scope};
    if (q != null && q.trim().isNotEmpty) {
      query['q'] = q.trim();
    }
    final endpoint = Uri(
      path: 'contests/meta/users',
      queryParameters: query,
    ).toString();
    final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
    return _parse(response, fallbackMessage: 'Failed to load users');
  }

  Future<Map<String, dynamic>> getCities({String? q}) async {
    final query = <String, String>{};
    if (q != null && q.trim().isNotEmpty) {
      query['q'] = q.trim();
    }
    final endpoint = Uri(
      path: 'contests/meta/cities',
      queryParameters: query.isEmpty ? null : query,
    ).toString();
    final response = await ApiHelper.fetchDataWithAuthorization(endpoint);
    return _parse(response, fallbackMessage: 'Failed to load cities');
  }

  Future<Map<String, dynamic>> getTags() async {
    final response = await ApiHelper.fetchDataWithAuthorization(
      'contests/meta/tags',
    );
    return _parse(response, fallbackMessage: 'Failed to load tags');
  }

  Future<Map<String, dynamic>> createOneVsOne(ContestFormData formData) async {
    final response = await _multipart(
      'contests/one-vs-one',
      formData: formData,
    );
    return _parseStreamed(response, fallbackMessage: 'Failed to create 1v1');
  }

  Future<Map<String, dynamic>> createCityVsCity(
    ContestFormData formData,
  ) async {
    final response = await _multipart(
      'contests/city-vs-city',
      formData: formData,
    );
    return _parseStreamed(response, fallbackMessage: 'Failed to create city');
  }

  Future<Map<String, dynamic>> requestJoin1v1(int contestId) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'contests/$contestId/one-vs-one/request-join',
      body: <String, dynamic>{},
    );
    return _parse(response, fallbackMessage: 'Unable to request join');
  }

  Future<Map<String, dynamic>> requestJoin1v1WithProfile(
    int contestId,
    ContestFormData formData,
  ) async {
    final response = await _multipart(
      'contests/$contestId/one-vs-one/request-join',
      formData: formData,
    );
    return _parseStreamed(response, fallbackMessage: 'Unable to request join');
  }

  Future<Map<String, dynamic>> respondInvitation(
    int invitationId,
    String status,
  ) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'contests/invitations/$invitationId/respond',
      body: <String, dynamic>{'status': status},
    );
    return _parse(response, fallbackMessage: 'Unable to respond invitation');
  }

  Future<Map<String, dynamic>> selectOpponent(
    int contestId,
    int participantUserId,
  ) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'contests/$contestId/one-vs-one/select-opponent',
      body: <String, dynamic>{'participant_user_id': participantUserId},
    );
    return _parse(response, fallbackMessage: 'Unable to select opponent');
  }

  Future<Map<String, dynamic>> joinCityContest(int contestId) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'contests/$contestId/city/join',
      body: <String, dynamic>{},
    );
    return _parse(response, fallbackMessage: 'Unable to join city contest');
  }

  Future<Map<String, dynamic>> joinContest(
    int contestId,
    ContestFormData formData,
  ) async {
    final response = await _multipart(
      'contests/$contestId/join',
      formData: formData,
    );
    return _parseStreamed(response, fallbackMessage: 'Unable to join contest');
  }

  Future<Map<String, dynamic>> submitContestOutfit(
    int contestId,
    ContestFormData formData,
  ) async {
    final response = await _multipart(
      'contests/$contestId/submissions',
      formData: formData,
    );
    return _parseStreamed(response, fallbackMessage: 'Unable to submit outfit');
  }

  Future<Map<String, dynamic>> voteContest(
    int contestId,
    int submissionId,
    double score,
  ) async {
    final response = await ApiHelper.postRequestWithAuthorization(
      'contests/$contestId/vote',
      body: <String, dynamic>{'submission_id': submissionId, 'score': score},
    );
    return _parse(response, fallbackMessage: 'Unable to submit vote');
  }

  Future<http.StreamedResponse?> _multipart(
    String endpoint, {
    required ContestFormData formData,
  }) async {
    final files = formData.filePaths.entries
        .where(
          (entry) =>
              entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty,
        )
        .toList(growable: false);
    return ApiHelper.multipartRequestWithAuthorization(
      endpoint,
      fields: formData.toMultipartFields(),
      files: files,
    );
  }

  Map<String, dynamic> _parse(
    http.Response? response, {
    required String fallbackMessage,
  }) {
    if (response == null) {
      throw Exception('No response returned from server.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final statusCode = body['status_code']?.toString();
    final ok =
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (statusCode == null || statusCode == '1');
    if (!ok) {
      throw Exception((body['message'] ?? fallbackMessage).toString());
    }
    return body;
  }

  Future<Map<String, dynamic>> _parseStreamed(
    http.StreamedResponse? response, {
    required String fallbackMessage,
  }) async {
    if (response == null) {
      throw Exception('No response returned from server.');
    }
    final materialized = await http.Response.fromStream(response);
    return _parse(materialized, fallbackMessage: fallbackMessage);
  }
}
