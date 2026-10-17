import 'dart:io';

// True while running under `flutter test` (the flutter_tester sets FLUTTER_TEST=true).
bool get isFlutterTestEnvironment =>
    Platform.environment['FLUTTER_TEST'] == 'true';
