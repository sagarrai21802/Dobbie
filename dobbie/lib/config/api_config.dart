class ApiConfig {
  static const String baseUrl = 'http://localhost:8000';
  static const String apiPrefix = '/api/v1';

  static const String registerEndpoint = '$apiPrefix/auth/register';
  static const String loginEndpoint = '$apiPrefix/auth/login';
  static const String refreshEndpoint = '$apiPrefix/auth/refresh';
  static const String logoutEndpoint = '$apiPrefix/auth/logout';
  static const String meEndpoint = '$apiPrefix/auth/me';

  static String get fullRegisterUrl => '$baseUrl$registerEndpoint';
  static String get fullLoginUrl => '$baseUrl$loginEndpoint';
  static String get fullRefreshUrl => '$baseUrl$refreshEndpoint';
  static String get fullLogoutUrl => '$baseUrl$logoutEndpoint';
  static String get fullMeUrl => '$baseUrl$meEndpoint';
}
