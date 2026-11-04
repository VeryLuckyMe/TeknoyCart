import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/auth/views/auth_gate_view.dart';
import 'package:teknoycart/main.dart';

final _linkAffordanceStorage = <String, String>{};

/// Regression tests for "Sign in / Sign up doesn't look clickable".
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') return <String, dynamic>{};
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall methodCall) async {
        final key = methodCall.arguments?['key'] as String?;
        if (methodCall.method == 'read') return _linkAffordanceStorage[key];
        if (methodCall.method == 'write') {
          final value = methodCall.arguments?['value'] as String?;
          if (key != null && value != null) {
            _linkAffordanceStorage[key] = value;
          }
          return null;
        }
        if (methodCall.method == 'delete' && key != null) {
          _linkAffordanceStorage.remove(key);
        }
        if (methodCall.method == 'deleteAll') _linkAffordanceStorage.clear();
        if (methodCall.method == 'readAll') return _linkAffordanceStorage;
        if (methodCall.method == 'containsKey') {
          return key != null && _linkAffordanceStorage.containsKey(key);
        }
        return null;
      },
    );
    await SupabaseConfig.initialize();
  });

  Future<void> pumpAuthGate(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => const AsyncValue.data(null)),
        ],
        child: const TeknoyCartApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AuthGateView), findsOneWidget);
  }

  testWidgets('Sign up is a real button with a 48dp tap target', (tester) async {
    await pumpAuthGate(tester);

    final signUp = find.widgetWithText(TextButton, 'Sign up');
    expect(signUp, findsOneWidget);

    final size = tester.getSize(signUp);
    expect(size.height, greaterThanOrEqualTo(48.0));
    expect(size.width, greaterThanOrEqualTo(48.0));

    final style = tester.widget<TextButton>(signUp).style!;
    expect(style.minimumSize?.resolve(<WidgetState>{})?.height, 48.0);

    final textStyle = style.textStyle?.resolve(<WidgetState>{});
    expect(textStyle?.decoration, TextDecoration.underline);
    expect(textStyle?.fontFamily, 'Outfit');
  });

  testWidgets('Sign up keeps brand maroon and still switches tabs',
      (tester) async {
    await pumpAuthGate(tester);

    final style = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Sign up'))
        .style!;
    expect(
      style.foregroundColor?.resolve(<WidgetState>{}),
      TeknoyTheme.citMaroon,
    );

    await tester.tap(find.widgetWithText(TextButton, 'Sign up'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Sign in'), findsOneWidget);
  });
}
