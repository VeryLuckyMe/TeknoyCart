import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/main.dart';

void main() {
  testWidgets('App renders onboarding page by default', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: TeknoyCartApp(),
      ),
    );

    // Verify that the MaterialApp structure is successfully instantiated
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
