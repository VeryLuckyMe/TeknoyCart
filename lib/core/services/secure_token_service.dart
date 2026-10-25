import 'package:flutter/foundation.dart';
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
  static const String _keyLockoutUntil = 'teknoy_auth_lockout_until';
  static const String _keyFailedAttempts = 'teknoy_auth_failed_attempts';

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
    } catch (e) {
      // Storage failures shouldn't crash the app (e.g. unsupported desktop env)
      debugPrint('SECURE_TOKEN_SAVE: $e');
    }
  }

  /// Retrieves the active bearer token for backend requests.
  /// Prefers active Supabase session (live token, auto-refreshed by SDK), then falls back to secure storage.
  static Future<String?> getBearerToken() async {
    // 1. Primary: live Supabase session (auto-refreshed by Supabase SDK)
    try {
      final sessionToken = SupabaseConfig.client.auth.currentSession?.accessToken;
      if (sessionToken != null && sessionToken.isNotEmpty) {
        return sessionToken;
      }
    } catch (e) {
      debugPrint('SECURE_TOKEN_SESSION_READ: $e');
    }

    // 2. Fallback: stored backend JWT or access token from secure storage
    try {
      final backendToken = await _storage.read(key: _keyBackendToken);
      if (backendToken != null && backendToken.isNotEmpty) {
        return backendToken;
      }
      final token = await _storage.read(key: _keyAccessToken);
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (e) {
      debugPrint('SECURE_TOKEN_READ: $e');
    }

    return null;
  }

  /// Retrieves the stored refresh token.
  static Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (e) {
      debugPrint('SECURE_TOKEN_REFRESH_READ: $e');
      return null;
    }
  }

  /// Retrieves the Spring Boot backend JWT (if needed).
  static Future<String?> getBackendToken() async {
    try {
      return await _storage.read(key: _keyBackendToken);
    } catch (e) {
      debugPrint('SECURE_TOKEN_BACKEND_READ: $e');
      return null;
    }
  }

  /// Clears all stored tokens upon logout.
  static Future<void> clearTokens() async {
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyBackendToken);
    } catch (e) { debugPrint('SECURE_TOKEN_CLEAR: $e'); }
  }

  /// Saves the lockout expiration timestamp so the 10-minute cooldown persists across app restarts.
  static Future<void> saveLockoutUntil(DateTime lockUntil) async {
    try {
      await _storage.write(key: _keyLockoutUntil, value: lockUntil.toIso8601String());
    } catch (e) {
      debugPrint('SECURE_LOCKOUT_SAVE: $e');
    }
  }

  /// Retrieves the lockout expiration timestamp if active.
  static Future<DateTime?> getLockoutUntil() async {
    try {
      final val = await _storage.read(key: _keyLockoutUntil);
      if (val != null && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
    } catch (e) {
      debugPrint('SECURE_LOCKOUT_READ: $e');
    }
    return null;
  }

  /// Saves failed attempt count to persist across app restarts.
  static Future<void> saveFailedAttempts(int count) async {
    try {
      await _storage.write(key: _keyFailedAttempts, value: count.toString());
    } catch (e) {
      debugPrint('SECURE_ATTEMPTS_SAVE: $e');
    }
  }

  /// Retrieves stored failed attempt count.
  static Future<int> getFailedAttempts() async {
    try {
      final val = await _storage.read(key: _keyFailedAttempts);
      if (val != null && val.isNotEmpty) {
        return int.tryParse(val) ?? 0;
      }
    } catch (e) {
      debugPrint('SECURE_ATTEMPTS_READ: $e');
    }
    return 0;
  }

  /// Clears lockout state and failed attempts counter upon successful login or timer expiration.
  static Future<void> clearLockout() async {
    try {
      await _storage.delete(key: _keyLockoutUntil);
      await _storage.delete(key: _keyFailedAttempts);
    } catch (e) {
      debugPrint('SECURE_LOCKOUT_CLEAR: $e');
    }
  }
}
