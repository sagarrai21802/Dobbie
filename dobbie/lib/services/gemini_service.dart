import '../config/api_config.dart';
import 'api_client.dart';

class ResearchTopic {
  final String topic;
  final String content;

  const ResearchTopic({required this.topic, required this.content});

  factory ResearchTopic.fromJson(Map<String, dynamic> json) {
    return ResearchTopic(
      topic: (json['topic'] as String? ?? '').trim(),
      content: (json['content'] as String? ?? '').trim(),
    );
  }
}

class GeminiService {
  final ApiClient _apiClient;

  GeminiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<String> generateLinkedInPost(String topic) async {
    try {
      final response = await _apiClient.post(
        ApiConfig.fullGeneratePostUrl,
        {'topic': topic},
        requiresAuth: true,
      );

      if (response is! Map<String, dynamic>) {
        throw ApiException('Failed to generate post');
      }

      return response['content'] as String? ?? '';
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<List<ResearchTopic>> generateResearchTopics() async {
    try {
      final data = await _apiClient.post(
        ApiConfig.fullResearchTopicsUrl,
        {},
        requiresAuth: true,
      );
      if (data is! List) {
        throw ApiException('Unexpected research topics response format');
      }

      final topics = data
          .whereType<Map<String, dynamic>>()
          .map(ResearchTopic.fromJson)
          .where((item) => item.topic.isNotEmpty && item.content.isNotEmpty)
          .toList();

      if (topics.isEmpty) {
        throw ApiException('No valid research topics returned from API');
      }

      if (topics.length < 5) {
        throw ApiException('Research topics response is incomplete (got ${topics.length}, expected 5)');
      }

      return topics.take(5).toList();
    } on ApiException catch (e) {
      if (e.statusCode == 504) {
        throw ApiException(
          'The AI research topics generator is taking too long to respond. Please try again in a moment.',
          statusCode: 504,
        );
      }
      rethrow;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  void dispose() {}
}
