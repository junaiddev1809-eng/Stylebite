import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:stylebite/core/utils/app_helper.dart';
import 'package:stylebite/core/utils/config.dart';
import 'package:stylebite/core/utils/local_storage.dart';

import '../../app/routes/app_routes.dart';
import '../../modules/messages/services/chat_socket_service.dart';
import '../../modules/post/services/post_interaction_store.dart';

class ApiHelper {
  // Without this, a stalled connection leaves the awaiting call (and
  // whatever loading flag/RefreshIndicator/button spinner is waiting on
  // it) hanging forever instead of ever reaching a catch/finally block.
  static const Duration _requestTimeout = Duration(seconds: 20);
  // Media uploads legitimately take longer than a plain JSON request.
  static const Duration _uploadTimeout = Duration(minutes: 3);

  static bool _isHandlingSessionExpiry = false;
  static bool _isHandlingAccountRestriction = false;
  static const _restrictionCodes = <String>{
    'account_banned',
    'account_suspended',
    'account_inactive',
  };

  static Map<String, String> _headers({bool withAuth = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final accessKey = LocalStorage.getAccessKey();
      if (accessKey != null && accessKey.isNotEmpty) {
        headers['Authorization'] = accessKey.toLowerCase().startsWith('bearer ')
            ? accessKey
            : 'Bearer $accessKey';
      }
    }

    return headers;
  }

  static Uri _uriFor(String endpoint) {
    final root = apiRootForEndpoint(endpoint);
    final normalizedBase = root.endsWith('/')
        ? root.substring(0, root.length - 1)
        : root;
    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint.substring(1)
        : endpoint;
    return Uri.parse('$normalizedBase/$normalizedEndpoint');
  }

  static bool _isLocalUpdatedHost(Uri? url) {
    final host = url?.host ?? '';
    return host == '10.0.2.2' || host == '127.0.0.1' || host == 'localhost';
  }

  static Future<void> _interceptAuthFailure(http.Response response) async {
    // A live-server login token is invalid on local Laravel. Never sign the
    // user out of the previous backend because a new local module 401'd.
    if (_isLocalUpdatedHost(response.request?.url)) {
      return;
    }
    if (response.statusCode == 401) {
      await _handleSessionExpired(response);
      return;
    }

    if (response.statusCode == 403) {
      await _handleAccountRestricted(response);
    }
  }

  static Future<void> _handleSessionExpired(http.Response response) async {
    Map<String, dynamic>? payload;
    try {
      payload = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    final message = (payload?['message'] ?? '').toString().trim();
    if (message != 'Invalid or expired token.') {
      return;
    }

    if (_isHandlingSessionExpiry) {
      return;
    }
    _isHandlingSessionExpiry = true;

    await LocalStorage.removeAccessKey();
    await LocalStorage.removeUsername();
    await LocalStorage.removeUserId();
    await LocalStorage.removeAvatarUrl();
    PostInteractionStore.ensure().clear();
    await ChatSocketService.instance.disconnect();
    errorSnackBar(message: message);
    Get.offAllNamed(AppRoutes.login);

    Future<void>.delayed(const Duration(milliseconds: 300), () {
      _isHandlingSessionExpiry = false;
    });
  }

  static Future<void> _handleAccountRestricted(http.Response response) async {
    Map<String, dynamic>? payload;
    try {
      payload = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    final code = (payload?['code'] ?? '').toString().trim();
    if (!_restrictionCodes.contains(code)) {
      return;
    }

    if (_isHandlingAccountRestriction) {
      return;
    }
    _isHandlingAccountRestriction = true;

    final suspendedUntilRaw = payload?['suspended_until']?.toString();
    final suspendedUntil = suspendedUntilRaw == null
        ? null
        : DateTime.tryParse(suspendedUntilRaw);

    await LocalStorage.removeAccessKey();
    await LocalStorage.removeUsername();
    await LocalStorage.removeUserId();
    await LocalStorage.removeAvatarUrl();
    PostInteractionStore.ensure().clear();
    await ChatSocketService.instance.disconnect();

    Get.offAllNamed(
      AppRoutes.accountRestricted,
      arguments: {
        'code': code,
        'message': payload?['message']?.toString(),
        'reason': payload?['reason']?.toString(),
        'suspendedUntil': suspendedUntil,
      },
    );

    Future<void>.delayed(const Duration(milliseconds: 300), () {
      _isHandlingAccountRestriction = false;
    });
  }

  static Future<http.Response?> postRequest(
    String endpoint,
    dynamic body,
  ) async {
    final Uri url = _uriFor(endpoint);

    try {
      final http.Response response = await http
          .post(url, headers: _headers(), body: json.encode(body))
          .timeout(_requestTimeout);

      await _interceptAuthFailure(response);
      return response;
    } on SocketException {
      if (usesUpdatedLocalModule(endpoint)) {
        return null;
      }
      errorSnackBar(message: "No Internet");
      return null;
    } on TimeoutException {
      errorSnackBar(message: "Request timed out. Please try again.");
      return null;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response?> postRequestWithAuthorization(
    String endpoint, {
    dynamic body,
    bool interceptAuthFailure = true,
  }) async {
    final Uri url = _uriFor(endpoint);

    try {
      final http.Response response = await http
          .post(
            url,
            headers: _headers(withAuth: true),
            body: body == null ? null : json.encode(body),
          )
          .timeout(_requestTimeout);

      if (interceptAuthFailure) {
        await _interceptAuthFailure(response);
      }
      return response;
    } on SocketException {
      if (usesUpdatedLocalModule(endpoint)) {
        return null;
      }
      errorSnackBar(message: "No Internet");
      return null;
    } on TimeoutException {
      errorSnackBar(message: "Request timed out. Please try again.");
      return null;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response?> getRequest(
    String endpoint, {
    bool withAuth = false,
  }) async {
    final Uri url = _uriFor(endpoint);

    try {
      final http.Response response = await http
          .get(url, headers: _headers(withAuth: withAuth))
          .timeout(_requestTimeout);
      await _interceptAuthFailure(response);
      return response;
    } on SocketException {
      if (usesUpdatedLocalModule(endpoint)) {
        return null;
      }
      errorSnackBar(message: "No Internet");
      return null;
    } on TimeoutException {
      errorSnackBar(message: "Request timed out. Please try again.");
      return null;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response?> fetchDataWithAuthorization(
    String endpoint, {
    bool interceptAuthFailure = true,
  }) async {
    final Uri url = _uriFor(endpoint);

    try {
      final http.Response response = await http
          .get(url, headers: _headers(withAuth: true))
          .timeout(_requestTimeout);

      if (interceptAuthFailure) {
        await _interceptAuthFailure(response);
      }
      return response;
    } on SocketException {
      if (usesUpdatedLocalModule(endpoint)) {
        return null;
      }
      errorSnackBar(message: "No Internet");
      return null;
    } on TimeoutException {
      errorSnackBar(message: "Request timed out. Please try again.");
      return null;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response?> deleteRequestWithAuthorization(
    String endpoint, {
    dynamic body,
  }) async {
    final Uri url = _uriFor(endpoint);

    try {
      final http.Response response = await http
          .delete(
            url,
            headers: _headers(withAuth: true),
            body: body == null ? null : json.encode(body),
          )
          .timeout(_requestTimeout);

      await _interceptAuthFailure(response);
      return response;
    } on SocketException {
      if (usesUpdatedLocalModule(endpoint)) {
        return null;
      }
      errorSnackBar(message: "No Internet");
      return null;
    } on TimeoutException {
      errorSnackBar(message: "Request timed out. Please try again.");
      return null;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response?> patchRequestWithAuthorization(
    String endpoint, {
    dynamic body,
  }) async {
    final Uri url = _uriFor(endpoint);

    try {
      final http.Response response = await http
          .patch(
            url,
            headers: _headers(withAuth: true),
            body: body == null ? null : json.encode(body),
          )
          .timeout(_requestTimeout);

      await _interceptAuthFailure(response);
      return response;
    } on SocketException {
      if (usesUpdatedLocalModule(endpoint)) {
        return null;
      }
      errorSnackBar(message: "No Internet");
      return null;
    } on TimeoutException {
      errorSnackBar(message: "Request timed out. Please try again.");
      return null;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.Response?> multipartRequest(
    String endpoint, {
    required Map<String, String> fields,
    String method = 'POST',
    String? fileFieldName,
    String? filePath,
    List<MapEntry<String, String>> files = const <MapEntry<String, String>>[],
    bool withAuth = false,
  }) async {
    final Uri url = _uriFor(endpoint);

    try {
      final multipartHeaders = Map<String, String>.from(
        _headers(withAuth: withAuth),
      )..remove('Content-Type');
      final request = http.MultipartRequest(method, url)
        ..headers.addAll(multipartHeaders)
        ..fields.addAll(fields);

      if (fileFieldName != null &&
          fileFieldName.isNotEmpty &&
          filePath != null &&
          filePath.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(fileFieldName, filePath),
        );
      }
      for (final file in files) {
        if (file.key.trim().isEmpty || file.value.trim().isEmpty) {
          continue;
        }
        request.files.add(
          await http.MultipartFile.fromPath(file.key, file.value),
        );
      }

      final response = await request.send().timeout(_uploadTimeout);
      final materialized = await http.Response.fromStream(
        response,
      ).timeout(_uploadTimeout);
      await _interceptAuthFailure(materialized);

      return materialized;
    } on SocketException {
      if (usesUpdatedLocalModule(endpoint)) {
        return null;
      }
      errorSnackBar(message: "No Internet");
      return null;
    } on TimeoutException {
      errorSnackBar(message: "Upload timed out. Please try again.");
      return null;
    } catch (e) {
      rethrow;
    }
  }

  static Future<http.StreamedResponse?> multipartRequestWithAuthorization(
    String endpoint, {
    required Map<String, String> fields,
    String method = 'POST',
    String? fileFieldName,
    String? filePath,
    List<MapEntry<String, String>> files = const <MapEntry<String, String>>[],
  }) async {
    final response = await multipartRequest(
      endpoint,
      fields: fields,
      method: method,
      fileFieldName: fileFieldName,
      filePath: filePath,
      files: files,
      withAuth: true,
    );

    if (response == null) return null;

    return http.StreamedResponse(
      Stream<List<int>>.fromIterable(<List<int>>[response.bodyBytes]),
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
