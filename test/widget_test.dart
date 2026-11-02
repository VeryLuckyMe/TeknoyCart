import 'support/test_harness.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/main.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
void main() {
  setUpAll(() async {
    await TestHarness.setUpAllEnvironment();
  });

  testWidgets('App renders onboarding page by default', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => const AsyncValue.data(null)),
        ],
        child: const TeknoyCartApp(),
      ),
    );

    // Verify that the MaterialApp structure is successfully instantiated
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
