import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'api_client.dart';

class GeminiService {
  final http.Client _client;

  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> generateLinkedInPost(String topic) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConfig.fullGeneratePostUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'topic': topic}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'] as String;
      } else {
        final errorBody = jsonDecode(response.body);
        throw ApiException(
          errorBody['detail'] ??
              errorBody['message'] ??
              'Failed to generate post',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
