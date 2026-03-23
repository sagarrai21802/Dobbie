import '../config/api_config.dart';
import '../models/auth_models.dart';
import 'api_client.dart';
import 'token_service.dart';
import 'google_signin_service.dart';

class AuthService {
  final ApiClient _apiClient;
  final TokenService _tokenService;

  AuthService({ApiClient? apiClient, TokenService? tokenService})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenService = tokenService ?? TokenService();

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await _apiClient.post(ApiConfig.fullRegisterUrl, {
      'email': email,
      'password': password,
      'full_name': fullName,
    });
    return UserModel.fromJson(response);
  }

  Future<TokenModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(ApiConfig.fullLoginUrl, {
      'email': email,
      'password': password,
    });
    final tokens = TokenModel.fromJson(response);
    await _tokenService.saveTokens(tokens.accessToken, tokens.refreshToken);
    return tokens;
  }

  Future<TokenModel> googleSignIn() async {
    final googleSignIn = GoogleSignInService();
    
    try {
      final idToken = await googleSignIn.signIn();
      if (idToken == null) {
        throw Exception('Google Sign-In was cancelled');
      }

      // Send ID token to backend for verification and JWT generation
      final response = await _apiClient.post(ApiConfig.fullGoogleLoginUrl, {
        'id_token': idToken,
      });
      
      final tokens = TokenModel.fromJson(response);
      await _tokenService.saveTokens(tokens.accessToken, tokens.refreshToken);
      return tokens;
    } catch (e) {
      // Clean up on error
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      rethrow;
    }
  }

  Future<TokenModel> refreshToken() async {
    final refreshToken = await _tokenService.getRefreshToken();
    if (refreshToken == null) {
      throw ApiException('No refresh token found');
    }

    final response = await _apiClient.post(ApiConfig.fullRefreshUrl, {
      'refresh_token': refreshToken,
    });
    final tokens = TokenModel.fromJson(response);
    await _tokenService.saveTokens(tokens.accessToken, tokens.refreshToken);
    return tokens;
  }

  Future<void> logout() async {
    final refreshToken = await _tokenService.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _apiClient.post(ApiConfig.fullLogoutUrl, {
          'refresh_token': refreshToken,
        }, requiresAuth: true);
      } catch (_) {}
    }
    await _tokenService.clearTokens();
  }

  Future<UserModel?> getCurrentUser() async {
    final hasAnyToken = await _tokenService.hasTokens();
    if (!hasAnyToken) return null;

    try {
      return await _callMeEndpoint();
    } on ApiException catch (e) {
      if (e.statusCode != 401) {
        rethrow;
      }

      // Access token likely expired; try one refresh and retry /me.
      try {
        await refreshToken();
        return await _callMeEndpoint();
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<UserModel?> _callMeEndpoint() async {
    final response = await _apiClient.get(
      ApiConfig.fullMeUrl,
      requiresAuth: true,
    );
    return UserModel.fromJson(response);
  }

  Future<bool> isLoggedIn() async {
    return await _tokenService.hasTokens();
  }
}
