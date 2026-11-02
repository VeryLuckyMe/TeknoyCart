import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/supabase_client.dart';
import '../mock_http_client.dart';

/// Centralized test harness for TeknoyCart widget and integration tests.
///
/// Eliminates duplicated `setUpAll` boilerplate across test suites by configuring:
/// 1. Mock HTTP overrides for Supabase backend endpoints
/// 2. `TestWidgetsFlutterBinding` initialization
/// 3. Standard `defaultBinaryMessenger` handlers for SharedPreferences & FlutterSecureStorage
/// 4. `SupabaseConfig` client initialization
class TestHarness {
  TestHarness._();

  /// Configures and initializes the standard mock testing environment.
  static Future<MockHttpOverrides> setUpAllEnvironment({
    MockHttpOverrides? customHttpOverrides,
  }) async {
    final overrides = customHttpOverrides ?? MockHttpOverrides();
    HttpOverrides.global = overrides;
    TestWidgetsFlutterBinding.ensureInitialized();

    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    // Standard SharedPreferences mock
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        return null;
      },
    );

    // Standard FlutterSecureStorage mock
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    await SupabaseConfig.initialize();
    return overrides;
  }
}

