// Platform-agnostic detection of `flutter test` runs (consumed by supabase_client.dart).
// On IO platforms we read the FLUTTER_TEST environment variable; on the web the stub
// always reports false.
export 'test_env_stub.dart' if (dart.library.io) 'test_env_io.dart';
