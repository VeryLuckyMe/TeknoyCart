/// Centralized API and environment configuration for the TeknoyCart Flutter app.
/// Sourced from compile-time `--dart-define` flags:
///   flutter run --dart-define=BACKEND_URL=https://...
class ApiConfig {
  /// Base API URL for the Spring Boot backend
  static const String baseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://teknoycart-backend.onrender.com/api',
  );

  /// Orders endpoint base URL
  static String get ordersUrl => '$baseUrl/orders';

  /// Authentication endpoint base URL
  static String get authUrl => '$baseUrl/auth';

  /// Payments endpoint base URL
  static String get paymentsUrl => '$baseUrl/payments';
}
