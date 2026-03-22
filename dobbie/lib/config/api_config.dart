class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';
  static const String apiPrefix = '/api/v1';

  // Auth endpoints
  static const String registerEndpoint = '$apiPrefix/auth/register';
  static const String loginEndpoint = '$apiPrefix/auth/login';
  static const String refreshEndpoint = '$apiPrefix/auth/refresh';
  static const String logoutEndpoint = '$apiPrefix/auth/logout';
  static const String meEndpoint = '$apiPrefix/auth/me';

  // AI/Content Generation endpoints
  static const String generatePostEndpoint = '$apiPrefix/ai/generate-post';

  // LinkedIn OAuth & API endpoints (backend handles credentials)
  static const String linkedinAuthorizeEndpoint =
      '$apiPrefix/auth/linkedin/authorize';
  static const String linkedinStatusEndpoint =
      '$apiPrefix/auth/linkedin/status';
  static const String linkedinGenerateImageEndpoint =
      '$apiPrefix/auth/linkedin/generate-image';
  static const String linkedinPostEndpoint = '$apiPrefix/auth/linkedin/post';

  // URLs
  static String get fullRegisterUrl => '$baseUrl$registerEndpoint';
  static String get fullLoginUrl => '$baseUrl$loginEndpoint';
  static String get fullRefreshUrl => '$baseUrl$refreshEndpoint';
  static String get fullLogoutUrl => '$baseUrl$logoutEndpoint';
  static String get fullMeUrl => '$baseUrl$meEndpoint';
  static String get fullGeneratePostUrl => '$baseUrl$generatePostEndpoint';
  static String get fullLinkedinAuthorizeUrl =>
      '$baseUrl$linkedinAuthorizeEndpoint';
  static String get fullLinkedinStatusUrl => '$baseUrl$linkedinStatusEndpoint';
    static String get fullLinkedinGenerateImageUrl =>
            '$baseUrl$linkedinGenerateImageEndpoint';
  static String get fullLinkedinPostUrl => '$baseUrl$linkedinPostEndpoint';
}
