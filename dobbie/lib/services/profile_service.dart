import 'dart:typed_data';

import '../config/api_config.dart';
import '../models/profile_model.dart';
import 'api_client.dart';

class ProfileService {
  final ApiClient _apiClient;

  ProfileService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<UserProfile> getMyProfile() async {
    final response = await _apiClient.get(
      ApiConfig.fullProfileMeUrl,
      requiresAuth: true,
    );

    if (response is! Map<String, dynamic>) {
      throw ApiException('Invalid profile response');
    }

    return UserProfile.fromJson(
      (response['profile'] as Map<String, dynamic>?) ?? {},
    );
  }

  Future<UserProfile> saveProfile(UserProfile profile) async {
    final response = await _apiClient.post(
      ApiConfig.fullProfileSaveUrl,
      profile.toJson(),
      requiresAuth: true,
    );

    if (response is! Map<String, dynamic>) {
      throw ApiException('Invalid profile save response');
    }

    return UserProfile.fromJson(
      (response['profile'] as Map<String, dynamic>?) ?? {},
    );
  }

  Future<UserProfile> uploadLinkedInPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final response = await _apiClient.postMultipart(
      ApiConfig.fullProfileUploadPdfUrl,
      fileField: 'file',
      fileBytes: bytes,
      filename: fileName,
      requiresAuth: true,
    );

    if (response is! Map<String, dynamic>) {
      throw ApiException('Invalid upload response');
    }

    return UserProfile.fromJson(
      (response['extracted'] as Map<String, dynamic>?) ?? {},
    );
  }
}
