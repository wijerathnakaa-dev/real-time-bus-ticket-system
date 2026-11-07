import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  bool get isConflict => statusCode == 409;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}

/// Thin JSON client for the Go REST API. The bearer token is set by AuthService.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? token;
  http.Client _http = http.Client();

  /// Lets tests inject a mock client.
  set httpClient(http.Client c) => _http = c;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${ApiConfig.apiUrl}$path').replace(queryParameters: query?.isEmpty ?? true ? null : query);

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send(() => _http.get(_uri(path, query), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) =>
      _send(() => _http.post(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Object? body]) =>
      _send(() => _http.put(_uri(path), headers: _headers, body: jsonEncode(body ?? {})));

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response res;
    try {
      res = await request().timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw ApiException(0, 'The server is taking too long to respond. Check your connection.');
    } catch (_) {
      throw ApiException(0, 'Cannot reach the CityBus server at ${ApiConfig.baseUrl}. Check your connection.');
    }
    final body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final msg = body is Map && body['error'] != null ? body['error'].toString() : 'Request failed (${res.statusCode})';
    throw ApiException(res.statusCode, msg);
  }
}
