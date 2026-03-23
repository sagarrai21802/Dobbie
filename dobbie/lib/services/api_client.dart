import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
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
  Completer<bool>? _refreshCompleter;

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
      return await _sendWithAuthRetry(
        (headers) => _client.get(Uri.parse(url), headers: headers),
        requiresAuth: requiresAuth,
      );
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
      return await _sendWithAuthRetry(
        (headers) => _client.post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        ),
        requiresAuth: requiresAuth,
      );
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
      return await _sendWithAuthRetry(
        (headers) => _client.put(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode(body),
        ),
        requiresAuth: requiresAuth,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<dynamic> postMultipart(
    String url, {
    required String fileField,
    required Uint8List fileBytes,
    required String filename,
    Map<String, String>? fields,
    bool requiresAuth = false,
  }) async {
    try {
      return await _sendMultipartWithAuthRetry(
        (headers) {
          final request = http.MultipartRequest('POST', Uri.parse(url));
          request.headers.addAll(headers);
          if (fields != null && fields.isNotEmpty) {
            request.fields.addAll(fields);
          }
          request.files.add(
            http.MultipartFile.fromBytes(
              fileField,
              fileBytes,
              filename: filename,
            ),
          );
          return _client.send(request);
        },
        requiresAuth: requiresAuth,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: ${e.toString()}');
    }
  }

  Future<dynamic> _sendWithAuthRetry(
    Future<http.Response> Function(Map<String, String> headers) send, {
    required bool requiresAuth,
  }) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final response = await send(headers);

    if (requiresAuth && response.statusCode == 401) {
      final refreshed = await _refreshTokensWithGuard();
      if (!refreshed) {
        await _tokenService.clearTokens();
        throw ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }

      final retryHeaders = await _getHeaders(requiresAuth: true);
      final retryResponse = await send(retryHeaders);
      if (retryResponse.statusCode == 401) {
        await _tokenService.clearTokens();
        throw ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      return _handleResponse(retryResponse);
    }

    return _handleResponse(response);
  }

  Future<dynamic> _sendMultipartWithAuthRetry(
    Future<http.StreamedResponse> Function(Map<String, String> headers) send, {
    required bool requiresAuth,
  }) async {
    final headers = await _getHeaders(requiresAuth: requiresAuth);
    final response = await send(headers);

    if (requiresAuth && response.statusCode == 401) {
      final refreshed = await _refreshTokensWithGuard();
      if (!refreshed) {
        await _tokenService.clearTokens();
        throw ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }

      final retryHeaders = await _getHeaders(requiresAuth: true);
      final retryResponse = await send(retryHeaders);
      if (retryResponse.statusCode == 401) {
        await _tokenService.clearTokens();
        throw ApiException(
          'Session expired. Please sign in again.',
          statusCode: 401,
        );
      }
      return _handleStreamedResponse(retryResponse);
    }

    return _handleStreamedResponse(response);
  }

  Future<bool> _refreshTokensWithGuard() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refreshed = await _refreshTokens();
      if (!completer.isCompleted) {
        completer.complete(refreshed);
      }
      return refreshed;
    } catch (_) {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = await _tokenService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final response = await _client.post(
      Uri.parse(ApiConfig.fullRefreshUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'refresh_token': refreshToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    if (body is! Map<String, dynamic>) {
      return false;
    }

    final accessToken = body['access_token'] as String?;
    final newRefreshToken = (body['refresh_token'] as String?) ?? refreshToken;

    if (accessToken == null || accessToken.isEmpty) {
      return false;
    }

    await _tokenService.saveTokens(accessToken, newRefreshToken);
    return true;
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

  Future<dynamic> _handleStreamedResponse(http.StreamedResponse response) async {
    final bodyString = await response.stream.bytesToString();
    dynamic body;
    if (bodyString.isNotEmpty) {
      body = jsonDecode(bodyString);
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    String errorMessage = 'An error occurred';
    if (body is Map<String, dynamic>) {
      errorMessage = body['detail'] ?? body['message'] ?? errorMessage;
    }

    throw ApiException(errorMessage, statusCode: response.statusCode);
  }

  void dispose() {
    _client.close();
  }
}
