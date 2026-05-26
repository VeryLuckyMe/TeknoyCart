import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton accessor for the Supabase client throughout the TeknoyCart app.
/// Initialized once in main.dart via [SupabaseConfig.initialize].
class SupabaseConfig {
  static const String _url = 'https://chmtvasbhkbrvydbajnd.supabase.co';
  static const String _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNobXR2YXNiaGticnZ5ZGJham5kIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3NjMwMDgsImV4cCI6MjA5NTMzOTAwOH0.IJJIrh-dr4xRoXPPeBJoN_pVVHrNY4db5E1VY1Czj3I';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
    );
  }

  /// Returns the globally initialized Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
