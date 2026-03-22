import 'package:flutter/foundation.dart';
import '../services/linkedin_service.dart';
import '../services/gemini_service.dart';
import '../services/api_client.dart';

enum LinkedInState { initial, loading, connected, disconnected, posting, error }

class LinkedInProvider with ChangeNotifier {
  final LinkedInService _linkedInService;
  final GeminiService _geminiService;

  LinkedInState _state = LinkedInState.initial;
  String? _generatedPost;
  String? _editedPost;
  String? _errorMessage;
  String? _previewImageUrl;
  String? _previewImageStatus;
  String? _lastPostedImageUrl;
  String? _lastImageStatus;
  bool _isGeneratingPost = false;
  bool _isGeneratingImage = false;

  LinkedInProvider({
    LinkedInService? linkedInService,
    GeminiService? geminiService,
  }) : _linkedInService = linkedInService ?? LinkedInService(),
       _geminiService = geminiService ?? GeminiService();

  LinkedInState get state => _state;
  String? get generatedPost => _generatedPost;
  String? get editedPost => _editedPost ?? _generatedPost;
  String? get errorMessage => _errorMessage;
  String? get previewImageUrl => _previewImageUrl;
  String? get previewImageStatus => _previewImageStatus;
  String? get lastPostedImageUrl => _lastPostedImageUrl;
  String? get lastImageStatus => _lastImageStatus;
  bool get isGeneratingPost => _isGeneratingPost;
  bool get isGeneratingImage => _isGeneratingImage;
  bool get isConnected => _state == LinkedInState.connected;
  bool get isPosting => _state == LinkedInState.posting;

  Future<void> checkConnectionStatus() async {
    _state = LinkedInState.loading;
    notifyListeners();

    try {
      final isConnected = await _linkedInService.checkConnectionStatus();
      _state = isConnected
          ? LinkedInState.connected
          : LinkedInState.disconnected;
    } catch (e) {
      final isConnected = await _linkedInService.isConnected();
      _state = isConnected
          ? LinkedInState.connected
          : LinkedInState.disconnected;
    }
    notifyListeners();
  }

  Future<String> getOAuthUrl() async {
    try {
      return await _linkedInService.getOAuthUrl();
    } catch (e) {
      _errorMessage = 'Failed to get OAuth URL';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> generatePost(String topic) async {
    if (topic.trim().isEmpty) {
      _errorMessage = 'Please enter a topic';
      notifyListeners();
      return;
    }

    _isGeneratingPost = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _generatedPost = await _geminiService.generateLinkedInPost(topic);
      _editedPost = null;
      _previewImageUrl = null;
      _previewImageStatus = null;
    } catch (e) {
      _errorMessage = 'Failed to generate post: ${e.toString()}';
    } finally {
      _isGeneratingPost = false;
      notifyListeners();
    }
  }

  Future<void> generateImagePreview() async {
    final postContent = (_editedPost ?? _generatedPost ?? '').trim();
    if (postContent.isEmpty) {
      _errorMessage = 'Generate or enter post content before generating image';
      notifyListeners();
      return;
    }

    _isGeneratingImage = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _linkedInService.generateImageForPost(content: postContent);
      _previewImageUrl = result.imageUrl;
      _previewImageStatus = result.imageStatus;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _previewImageUrl = null;
      _previewImageStatus = 'skipped_failed';
    } catch (e) {
      _errorMessage = 'Failed to generate image: ${e.toString()}';
      _previewImageUrl = null;
      _previewImageStatus = 'skipped_failed';
    } finally {
      _isGeneratingImage = false;
      notifyListeners();
    }
  }

  void updateEditedPost(String post) {
    _editedPost = post;
    notifyListeners();
  }

  Future<bool> postToLinkedIn() async {
    final postContent = _editedPost ?? _generatedPost;
    if (postContent == null || postContent.isEmpty) {
      _errorMessage = 'No post content to publish';
      notifyListeners();
      return false;
    }

    _state = LinkedInState.posting;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _linkedInService.postToLinkedIn(
        content: postContent,
        imageUrl: _previewImageUrl,
        imageStatus: _previewImageStatus,
      );
      _lastPostedImageUrl = result.imageUrl;
      _lastImageStatus = result.imageStatus;
      _state = LinkedInState.connected;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _state = LinkedInState.connected;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Failed to post: ${e.toString()}';
      _state = LinkedInState.connected;
      notifyListeners();
      return false;
    }
  }

  void clearPost() {
    _generatedPost = null;
    _editedPost = null;
    _errorMessage = null;
    _previewImageUrl = null;
    _previewImageStatus = null;
    _lastPostedImageUrl = null;
    _lastImageStatus = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
