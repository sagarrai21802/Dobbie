import '../config/api_config.dart';
import '../models/auth_models.dart';
import 'api_client.dart';
import 'token_service.dart';

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
    try {
      final hasToken = await _tokenService.hasTokens();
      if (!hasToken) return null;

      final response = await _apiClient.get(
        ApiConfig.fullMeUrl,
        requiresAuth: true,
      );
      return UserModel.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isLoggedIn() async {
    return await _tokenService.hasTokens();
  }
}
