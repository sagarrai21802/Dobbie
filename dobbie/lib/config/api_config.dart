class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';
  static const String apiPrefix = '/api/v1';
  static const String linkedinCallbackScheme = 'dobbie';

  // Auth endpoints
  static const String registerEndpoint = '$apiPrefix/auth/register';
  static const String loginEndpoint = '$apiPrefix/auth/login';
  static const String googleLoginEndpoint = '$apiPrefix/auth/google';
  static const String refreshEndpoint = '$apiPrefix/auth/refresh';
  static const String logoutEndpoint = '$apiPrefix/auth/logout';
  static const String meEndpoint = '$apiPrefix/auth/me';

  // AI/Content Generation endpoints
  static const String generatePostEndpoint = '$apiPrefix/ai/generate-post';
    static const String researchTopicsEndpoint = '$apiPrefix/ai/research-topics';

    // Profile personalization endpoints
    static const String profileUploadPdfEndpoint = '$apiPrefix/profile/upload-pdf';
    static const String profileSaveEndpoint = '$apiPrefix/profile/save';
    static const String profileMeEndpoint = '$apiPrefix/profile/me';

  // LinkedIn OAuth & API endpoints (backend handles credentials)
  static const String linkedinAuthorizeEndpoint =
      '$apiPrefix/auth/linkedin/authorize';
  static const String linkedinStatusEndpoint =
      '$apiPrefix/auth/linkedin/status';
  static const String linkedinGenerateImageEndpoint =
      '$apiPrefix/auth/linkedin/generate-image';
  static const String linkedinPostEndpoint = '$apiPrefix/auth/linkedin/post';
  static const String linkedinDisconnectEndpoint =
      '$apiPrefix/auth/linkedin/disconnect';

  // URLs
  static String get fullRegisterUrl => '$baseUrl$registerEndpoint';
  static String get fullLoginUrl => '$baseUrl$loginEndpoint';
  static String get fullGoogleLoginUrl => '$baseUrl$googleLoginEndpoint';
  static String get fullRefreshUrl => '$baseUrl$refreshEndpoint';
  static String get fullLogoutUrl => '$baseUrl$logoutEndpoint';
  static String get fullMeUrl => '$baseUrl$meEndpoint';
  static String get fullGeneratePostUrl => '$baseUrl$generatePostEndpoint';
    static String get fullResearchTopicsUrl => '$baseUrl$researchTopicsEndpoint';
    static String get fullProfileUploadPdfUrl => '$baseUrl$profileUploadPdfEndpoint';
    static String get fullProfileSaveUrl => '$baseUrl$profileSaveEndpoint';
    static String get fullProfileMeUrl => '$baseUrl$profileMeEndpoint';
  static String get fullLinkedinAuthorizeUrl =>
      '$baseUrl$linkedinAuthorizeEndpoint';
  static String get fullLinkedinStatusUrl => '$baseUrl$linkedinStatusEndpoint';
  static String get fullLinkedinGenerateImageUrl =>
      '$baseUrl$linkedinGenerateImageEndpoint';
  static String get fullLinkedinPostUrl => '$baseUrl$linkedinPostEndpoint';
  static String get fullLinkedinDisconnectUrl =>
      '$baseUrl$linkedinDisconnectEndpoint';
}
