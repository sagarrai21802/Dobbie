import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../config/api_config.dart';

class LinkedInPostResult {
  final bool success;
  final String? postId;
  final String? imageUrl;
  final String imageStatus;

  const LinkedInPostResult({
    required this.success,
    required this.postId,
    required this.imageUrl,
    required this.imageStatus,
  });

  factory LinkedInPostResult.fromJson(Map<String, dynamic> json) {
    return LinkedInPostResult(
      success: json['success'] as bool? ?? false,
      postId: json['post_id'] as String?,
      imageUrl: json['image_url'] as String?,
      imageStatus: json['image_status'] as String? ?? 'skipped_failed',
    );
  }
}

class LinkedInImageResult {
  final String? imageUrl;
  final String imageStatus;

  const LinkedInImageResult({
    required this.imageUrl,
    required this.imageStatus,
  });

  factory LinkedInImageResult.fromJson(Map<String, dynamic> json) {
    return LinkedInImageResult(
      imageUrl: json['image_url'] as String?,
      imageStatus: json['image_status'] as String? ?? 'skipped_failed',
    );
  }
}

class LinkedInService {
  final ApiClient _apiClient;
  static const String _linkedinConnectedKey = 'linkedin_connected';

  LinkedInService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  Future<String> getOAuthUrl() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.fullLinkedinAuthorizeUrl,
        requiresAuth: true,
      );
      return response['authorization_url'] as String;
    } catch (e) {
      throw Exception('Failed to get OAuth URL: $e');
    }
  }

  Future<bool> checkConnectionStatus() async {
    try {
      final response = await _apiClient.get(
        ApiConfig.fullLinkedinStatusUrl,
        requiresAuth: true,
      );
      final isConnected = response['connected'] as bool? ?? false;

      if (isConnected) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_linkedinConnectedKey, true);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_linkedinConnectedKey, false);
      }

      return isConnected;
    } on ApiException catch (e) {
      final prefs = await SharedPreferences.getInstance();
      if (e.statusCode == 400 || e.statusCode == 401) {
        await prefs.setBool(_linkedinConnectedKey, false);
        return false;
      }
      return prefs.getBool(_linkedinConnectedKey) ?? false;
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_linkedinConnectedKey) ?? false;
    }
  }

  Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_linkedinConnectedKey) ?? false;
  }

  String _buildImagePromptFromPost(String postText) {
    final normalized = postText.replaceAll(RegExp(r'\s+'), ' ').trim();
    final excerpt = normalized.length > 700
        ? '${normalized.substring(0, 700)}...'
        : normalized;

    return '''
Create a high-quality LinkedIn cover image based on the post content below.

POST_CONTENT:
$excerpt

VISUAL_DIRECTION:
- Professional, modern, and clean
- Strong focal subject related to the post theme
- Minimal composition with clear depth
- 16:9 landscape cover format
- High contrast, sharp details
- Corporate-friendly palette (blue/teal/neutral)

CONSTRAINTS:
- No logos
- No watermark
- No readable text overlay
- No cluttered background

GOAL:
A visually compelling LinkedIn cover image that represents the post's core message.
''';
  }

  Future<LinkedInImageResult> generateImageForPost({
    required String content,
  }) async {
    try {
      final wrappedPrompt = _buildImagePromptFromPost(content);
      final response = await _apiClient.post(
        ApiConfig.fullLinkedinGenerateImageUrl,
        {'content': wrappedPrompt},
        requiresAuth: true,
      );
      return LinkedInImageResult.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to generate image: $e');
    }
  }

  Future<LinkedInPostResult> postToLinkedIn({
    required String content,
    String? imageUrl,
    String? imageStatus,
  }) async {
    try {
      final body = <String, dynamic>{'content': content};

      if (imageUrl != null && imageUrl.isNotEmpty) {
        body['image_url'] = imageUrl;
      }

      if (imageStatus != null && imageStatus.isNotEmpty) {
        body['image_status'] = imageStatus;
      }

      final response = await _apiClient.post(
        ApiConfig.fullLinkedinPostUrl,
        body,
        requiresAuth: true,
      );
      return LinkedInPostResult.fromJson(response as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to post to LinkedIn: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _apiClient.post(
        ApiConfig.fullLinkedinDisconnectUrl,
        {},
        requiresAuth: true,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to disconnect LinkedIn: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_linkedinConnectedKey, false);
  }
}
