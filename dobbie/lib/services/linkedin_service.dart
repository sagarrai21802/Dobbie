import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../config/api_config.dart';

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
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_linkedinConnectedKey) ?? false;
    }
  }

  Future<bool> isConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_linkedinConnectedKey) ?? false;
  }

  Future<Map<String, dynamic>> postToLinkedIn({required String content}) async {
    try {
      final response = await _apiClient.post(ApiConfig.fullLinkedinPostUrl, {
        'content': content,
      }, requiresAuth: true);
      return response;
    } on ApiException {
      rethrow;
    } catch (e) {
      throw Exception('Failed to post to LinkedIn: $e');
    }
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_linkedinConnectedKey);
  }
}
