import 'package:flutter/foundation.dart';

import '../models/profile_model.dart';
import '../services/api_client.dart';
import '../services/profile_service.dart';

class ProfileProvider with ChangeNotifier {
  final ProfileService _profileService;

  UserProfile? profile;
  bool isProfileComplete = false;
  bool isUploading = false;
  bool isExtracting = false;
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  Map<String, dynamic>? extractedData;

  bool get hasPersonalizationStarted {
    final current = profile;
    if (current == null) {
      return false;
    }

    return current.name.trim().isNotEmpty ||
        current.headline.trim().isNotEmpty ||
        current.location.trim().isNotEmpty ||
        current.currentRole.trim().isNotEmpty ||
        current.industry.trim().isNotEmpty ||
        current.skills.isNotEmpty ||
        (current.yearsExperience != null && current.yearsExperience! >= 0);
  }

  ProfileProvider({ProfileService? profileService})
    : _profileService = profileService ?? ProfileService();

  Future<void> loadProfile() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      profile = await _profileService.getMyProfile();
      isProfileComplete = profile?.isComplete ?? false;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        // Non-blocking personalization: keep app flows functional if profile isn't available.
        profile = UserProfile.empty();
        isProfileComplete = false;
      } else {
        errorMessage = e.message;
      }
    } catch (e) {
      errorMessage = 'Could not load profile';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<UserProfile?> uploadPdf({
    required Uint8List bytes,
    required String fileName,
  }) async {
    isUploading = true;
    isExtracting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final extracted = await _profileService.uploadLinkedInPdf(
        bytes: bytes,
        fileName: fileName,
      );
      extractedData = extracted.toJson();
      return extracted;
    } on ApiException catch (e) {
      errorMessage = e.message;
      return null;
    } catch (e) {
      errorMessage = 'Failed to upload and parse PDF';
      return null;
    } finally {
      isUploading = false;
      isExtracting = false;
      notifyListeners();
    }
  }

  Future<bool> saveProfile(UserProfile nextProfile) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();

    try {
      final saved = await _profileService.saveProfile(nextProfile);
      profile = saved;
      isProfileComplete = saved.isComplete;
      extractedData = null;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      errorMessage = 'Failed to save profile';
      notifyListeners();
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void setError(String message) {
    errorMessage = message;
    notifyListeners();
  }
}
