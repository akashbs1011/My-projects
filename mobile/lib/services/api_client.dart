import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/api_exception.dart';
import '../utils/config.dart';
import 'token_storage.dart';

/// The single place this app talks to the network.
///
/// It attaches the bearer token, decodes JSON, and converts every possible
/// failure into an [ApiException] carrying a message a person can act on. No
/// screen ever sees a status code or a raw socket error.
class ApiClient {
  ApiClient({required TokenStorage tokenStorage, http.Client? httpClient})
      : _tokenStorage = tokenStorage,
        _http = httpClient ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _http;

  /// Invoked when the server rejects the token, so the app can end the session
  /// once instead of every screen handling expiry separately.
  void Function()? onUnauthorized;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${AppConfig.apiBaseUrl}$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: query.map((k, v) => MapEntry(k, '$v')),
    );
  }

  Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth) {
      final token = await _tokenStorage.read();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() async => _http
          .get(_uri(path, query), headers: await _headers())
          .timeout(AppConfig.requestTimeout));

  Future<dynamic> post(String path, {Object? body, bool withAuth = true}) =>
      _send(() async => _http
          .post(
            _uri(path),
            headers: await _headers(withAuth: withAuth),
            body: jsonEncode(body ?? const {}),
          )
          .timeout(AppConfig.requestTimeout));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() async => _http
          .patch(
            _uri(path),
            headers: await _headers(),
            body: jsonEncode(body ?? const {}),
          )
          .timeout(AppConfig.requestTimeout));

  Future<dynamic> delete(String path) => _send(() async => _http
      .delete(_uri(path), headers: await _headers())
      .timeout(AppConfig.requestTimeout));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request();
    } on SocketException {
      throw const ApiException(
        "Can't reach the server. Check your connection and that the backend is running.",
        isNetworkError: true,
      );
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Try again.',
        isNetworkError: true,
      );
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}', isNetworkError: true);
    }

    return _decode(response);
  }

  dynamic _decode(http.Response response) {
    final status = response.statusCode;
    dynamic body;
    if (response.body.isNotEmpty) {
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        body = null;
      }
    }

    if (status >= 200 && status < 300) return body;

    if (status == 401) onUnauthorized?.call();

    throw ApiException(_messageFor(status, body), statusCode: status);
  }

  /// FastAPI reports errors as a `detail` string, or as a list of validation
  /// objects. Both are unwrapped here so the message is always readable.
  String _messageFor(int status, dynamic body) {
    if (body is Map) {
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) {
          final field = (first['loc'] as List?)?.skip(1).join('.') ?? '';
          final msg = '${first['msg']}';
          return field.isEmpty ? msg : '$field: $msg';
        }
      }
    }

    switch (status) {
      case 400:
        return "That request couldn't be processed. Check the details and try again.";
      case 401:
        return 'Your session has ended. Sign in again.';
      case 403:
        return "You don't have access to that.";
      case 404:
        return "That wasn't found.";
      case 409:
        return 'That already exists.';
      case 422:
        return 'Some details are missing or invalid.';
      case 429:
        return 'Too many requests. Wait a moment and try again.';
      case 503:
        return 'A backend component is unavailable. Check that the model is trained and the database is running.';
      default:
        return status >= 500
            ? 'The server ran into a problem. Try again shortly.'
            : 'Something went wrong. Try again.';
    }
  }

  void dispose() => _http.close();
}
