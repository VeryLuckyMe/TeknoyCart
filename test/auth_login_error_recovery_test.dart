import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';
import 'package:teknoycart/core/services/secure_token_service.dart';
import 'package:teknoycart/features/auth/views/auth_gate_view.dart';
import 'package:teknoycart/main.dart';
import 'mock_http_client.dart';

class _FailingAuthService extends AuthService {
  final Exception errorToThrow;

  _FailingAuthService(this.errorToThrow);

  @override
  Future<Profile> signIn({required String email, required String password}) async {
    throw errorToThrow;
  }
}

class _DelayedFailingAuthService extends AuthService {
  final Exception errorToThrow;
  final Duration delay;

  _DelayedFailingAuthService(this.errorToThrow, {this.delay = const Duration(milliseconds: 100)});

  @override
  Future<Profile> signIn({required String email, required String password}) async {
    await Future.delayed(delay);
    throw errorToThrow;
  }
}

final secureStorageMemory = <String, String>{};

void main() {
  setUp(() {
    secureStorageMemory.clear();
  });

  setUpAll(() async {
    HttpOverrides.global = MockHttpOverrides();
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel('plugins.flutter.io/shared_preferences')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    });
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      final key = methodCall.arguments?['key'] as String?;
      if (methodCall.method == 'read') {
        return secureStorageMemory[key];
      } else if (methodCall.method == 'write') {
        final value = methodCall.arguments?['value'] as String?;
        if (key != null && value != null) {
          secureStorageMemory[key] = value;
        }
        return null;
      } else if (methodCall.method == 'delete') {
        if (key != null) secureStorageMemory.remove(key);
        return null;
      } else if (methodCall.method == 'deleteAll') {
        secureStorageMemory.clear();
        return null;
      } else if (methodCall.method == 'readAll') {
        return secureStorageMemory;
      } else if (methodCall.method == 'containsKey') {
        return key != null && secureStorageMemory.containsKey(key);
      }
      return null;
    });
    await SupabaseConfig.initialize();
  });

  group('Auth Login Error Recovery & UI/UX Pro Max Tests', () {
    test('AuthNotifier resets state to data(null) on login error instead of unrecoverable AsyncValue.error',
        () async {
      final fakeService = _FailingAuthService(
        const FormatException('Invalid email or password. 4 attempts remaining before lockout.'),
      );
      final notifier = AuthNotifier(fakeService);

      expect(notifier.state.valueOrNull, isNull);

      try {
        await notifier.login(email: 'test@cit.edu', password: 'wrongpassword');
        fail('Should have rethrown the exception');
      } catch (e) {
        expect(e, isA<FormatException>());
      }

      // State MUST be data(null) so the UI tree doesn't break into a critical error screen
      expect(notifier.state, isA<AsyncData<Profile?>>());
      expect(notifier.state.valueOrNull, isNull);
      expect(notifier.state.hasError, isFalse);
    });

    testWidgets(
        'TeknoyCartApp retains AuthGateView with SnackBar on wrong credentials instead of bricking into Critical Error screen',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = _FailingAuthService(
        const FormatException('Invalid email or password. 4 attempts remaining before lockout.'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => fakeService),
          ],
          child: const TeknoyCartApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify we are on AuthGateView
      expect(find.byType(AuthGateView), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);

      // Enter credentials
      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'student@cit.edu');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongpass');
      await tester.pump();

      // Tap Login button
      await tester.tap(find.text('Login'));
      await tester.pump(); // Start async call
      await tester.pumpAndSettle(); // Finish failure and show SnackBar

      // CRITICAL ASSERTION: The app must NOT show the black "Critical Error" screen
      expect(find.textContaining('Critical Error:'), findsNothing);

      // AuthGateView must still be mounted and alive
      expect(find.byType(AuthGateView), findsOneWidget);

      // The entered email and password must still be in the fields for immediate editing
      expect(find.text('student@cit.edu'), findsOneWidget);

      // A friendly floating SnackBar must display the attempts remaining warning
      expect(find.text('Invalid email or password. 4 attempts remaining before lockout.'), findsOneWidget);
    });

    testWidgets('TeknoyCartApp falls back to AuthGateView gracefully if authStateProvider emits error',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => AsyncValue.error('Unexpected auth token failure', StackTrace.empty),
            ),
          ],
          child: const TeknoyCartApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Even with an unexpected error state in authStateProvider, the app MUST NOT brick
      expect(find.textContaining('Critical Error:'), findsNothing);
      expect(find.byType(AuthGateView), findsOneWidget);
    });

    testWidgets(
        'UI/UX Pro Max: Renders 5-dot attempt warning meter when attemptsRemaining is below 5',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = _FailingAuthService(
        AccountLockoutException(
          message: 'Invalid email or password. 4 attempts remaining before lockout.',
          attemptsRemaining: 4,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => fakeService),
          ],
          child: const TeknoyCartApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'student@cit.edu');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongpass');
      await tester.pump();

      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pumpAndSettle();

      // In-form attempt banner must display "4 of 5 attempts remaining"
      expect(find.text('4 of 5 attempts remaining'), findsOneWidget);
      expect(find.text('After 5 incorrect attempts, sign-in will be paused for 10 minutes.'), findsOneWidget);
      // Form should remain interactive
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
    });

    testWidgets(
        'UI/UX Pro Max: Renders live 10-minute lockout card, disables inputs, and updates button to Locked (10:00)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = _FailingAuthService(
        AccountLockoutException(
          message: 'Account temporarily locked. Please wait 10 minutes.',
          isLocked: true,
          remainingSeconds: 600,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => fakeService),
          ],
          child: const TeknoyCartApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'student@cit.edu');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongpass');
      await tester.pump();

      await tester.tap(find.text('Login'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify the lockout card is visible
      expect(find.text('Security Lockout Active'), findsOneWidget);
      expect(find.text('Sign-in is paused for 10 minutes.'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('Forgot Password? Reset via Outlook'), findsOneWidget);

      // Verify submit button shows locked timer
      expect(find.text('Locked (10:00)'), findsOneWidget);

      // Advance clock by 2 seconds to verify the live countdown ticks down
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('09:58'), findsOneWidget);
      expect(find.text('Locked (09:58)'), findsOneWidget);
    });

    testWidgets(
        'UI/UX Pro Max: Reaching 5 client-side failed attempts automatically initiates 10-minute countdown',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeService = _FailingAuthService(
        const FormatException('Wrong credentials'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => fakeService),
          ],
          child: const TeknoyCartApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'student@cit.edu');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongpass');
      await tester.pump();

      // Submit 5 times
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('Login'));
        await tester.pump();
        await tester.pumpAndSettle();
      }

      // After 5 attempts, lockout card activates with 10:00 timer
      expect(find.text('Security Lockout Active'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text('Locked (10:00)'), findsOneWidget);
    });

    testWidgets(
        'UI/UX Pro Max: Delayed network authentication failure never unmounts AuthGateView and preserves typed email',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final delayedService = _DelayedFailingAuthService(
        const FormatException('Invalid email or password. 4 attempts remaining before lockout.'),
        delay: const Duration(milliseconds: 200),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => delayedService),
          ],
          child: const TeknoyCartApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextFormField, 'Email Address'), 'student@cit.edu');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongpass');
      await tester.pump();

      // Tap Login to start async network request
      await tester.tap(find.text('Login'));
      await tester.pump(); // Start request

      // While request is in-flight (100ms in), AuthGateView MUST remain mounted
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AuthGateView), findsOneWidget);
      expect(find.text('student@cit.edu'), findsOneWidget);

      // Finish delayed async failure
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // After failure completes, AuthGateView MUST still be mounted, text preserved, and SnackBar shown
      expect(find.byType(AuthGateView), findsOneWidget);
      expect(find.text('student@cit.edu'), findsOneWidget);
      expect(find.text('Invalid email or password. 4 attempts remaining before lockout.'), findsOneWidget);
      expect(find.text('4 of 5 attempts remaining'), findsOneWidget);
    });

    testWidgets(
        'Ponytail Heuristic: Active lockout in SecureTokenService restores 10-minute cooldown on fresh app launch',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Simulate a previously saved 10-minute lockout in secure storage (e.g. user closed and reopened app)
      await SecureTokenService.saveLockoutUntil(DateTime.now().add(const Duration(seconds: 600)));

      await tester.pumpWidget(
        const ProviderScope(
          child: TeknoyCartApp(),
        ),
      );
      await tester.pumpAndSettle();

      // On fresh launch, lockout card MUST be immediately restored
      expect(find.text('Security Lockout Active'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^(10:00|09:59)$')), findsOneWidget);
      expect(find.textContaining('Locked ('), findsOneWidget);
      expect(find.text('Forgot Password? Reset via Outlook'), findsOneWidget);
    });
  });
}

