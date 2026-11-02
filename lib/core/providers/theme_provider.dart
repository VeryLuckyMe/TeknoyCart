import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider for dynamic theme mode (Light / Dark / System).
/// Persisted locally across app launches using FlutterSecureStorage (MED-01).
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _storageKey = 'teknoycart_theme_mode';
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  ThemeModeNotifier({ThemeMode initialMode = ThemeMode.light}) : super(initialMode) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final saved = await _storage.read(key: _storageKey);
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'light') {
        state = ThemeMode.light;
      } else if (saved == 'system') {
        state = ThemeMode.system;
      }
    } catch (error, stackTrace) {
      // Graceful fallback to the current theme mode when storage is unavailable.
      debugPrint('THEME_LOAD_ERROR: $error\n$stackTrace');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final value = mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
              ? 'light'
              : 'system';
      await _storage.write(key: _storageKey, value: value);
    } catch (error, stackTrace) {
      debugPrint('THEME_SAVE_ERROR: $error\n$stackTrace');
    }
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}
