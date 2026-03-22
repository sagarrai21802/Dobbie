import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  final TokenService _tokenService;
  final http.Client _client;

  ApiClient({TokenService? tokenService, http.Client? client})
    : _tokenService = tokenService ?? TokenService(),
      _client = client ?? http.Client();

  Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _tokenService.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(String url, {bool requiresAuth = false}) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _client.get(Uri.parse(url), headers: headers);
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<dynamic> post(
    String url,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<dynamic> put(
    String url,
    Map<String, dynamic> body, {
    bool requiresAuth = false,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _client.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );
      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  dynamic _handleResponse(http.Response response) {
    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String errorMessage = 'An error occurred';
    if (body != null && body is Map<String, dynamic>) {
      errorMessage = body['detail'] ?? body['message'] ?? errorMessage;
    }

    throw ApiException(errorMessage, statusCode: response.statusCode);
  }

  void dispose() {
    _client.close();
  }
}
