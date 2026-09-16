import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teknoycart/core/supabase_client.dart';

/// Service for securely persisting authentication tokens using hardware-backed keystore/keychain.
/// Prevents plaintext token storage vulnerabilities (HIGH-01).
class SecureTokenService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _keyAccessToken = 'teknoy_access_token';
  static const String _keyRefreshToken = 'teknoy_refresh_token';
  static const String _keyBackendToken = 'teknoy_backend_token';

  /// Securely stores auth tokens after successful authentication.
  static Future<void> saveTokens({
    String? accessToken,
    String? refreshToken,
    String? backendToken,
  }) async {
    try {
      if (accessToken != null) {
        await _storage.write(key: _keyAccessToken, value: accessToken);
      }
      if (refreshToken != null) {
        await _storage.write(key: _keyRefreshToken, value: refreshToken);
      }
      if (backendToken != null) {
        await _storage.write(key: _keyBackendToken, value: backendToken);
      }
    } catch (_) {
      // Fallback: storage failures shouldn't crash the app (e.g. unsupported desktop env)
    }
  }

  /// Retrieves the active bearer token for backend requests.
  /// Prefers secure storage, falls back to Supabase session.
  static Future<String?> getBearerToken() async {
    try {
      final token = await _storage.read(key: _keyAccessToken);
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (_) {}

    // Fallback to active Supabase session if secure storage read fails
    return SupabaseConfig.client.auth.currentSession?.accessToken;
  }

  /// Retrieves the stored refresh token.
  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the Spring Boot backend JWT (if needed).
  static Future<String?> getBackendToken() async {
    try {
      return await _storage.read(key: _keyBackendToken);
    } catch (_) {
      return null;
    }
  }

  /// Clears all stored tokens upon logout.
  static Future<void> clearTokens() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyBackendToken);
    } catch (_) {}
  }
}
