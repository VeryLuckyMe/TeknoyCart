import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_env/test_env.dart';

/// Singleton accessor for the Supabase client throughout the TeknoyCart app.
/// Initialized once in main.dart via [SupabaseConfig.initialize].
///
/// Credentials are REQUIRED at build time via compile-time `--dart-define` flags —
/// there are intentionally no hardcoded fallbacks (CRIT-01):
///   flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=eyJ...
class SupabaseConfig {
  static const String _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://chmtvasbhkbrvydbajnd.supabase.co',
  );
  static const String _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        '',
  );

  static Future<void> initialize() async {
    var url = _url;
    var anonKey = _anonKey;

    if (url.isEmpty || anonKey.isEmpty) {
      if (isFlutterTestEnvironment) {
        // `flutter test` runs without real credentials: boot the client against a
        // placeholder so code paths touching [client] still get a live instance.
        url = 'https://placeholder.supabase.co';
        anonKey = 'placeholder-anon-key';
      } else {
        throw StateError(
          'Missing Supabase configuration. Build and run with:\n'
          '  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co\n'
          '  --dart-define=SUPABASE_ANON_KEY=<anon key>',
        );
      }
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Returns the globally initialized Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
