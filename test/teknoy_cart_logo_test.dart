import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/widgets/teknoy_cart_logo.dart';

void main() {
  group('TeknoyCartLogo Widget Tests', () {
    testWidgets('renders CustomPaint with default size and color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TeknoyCartLogo(),
            ),
          ),
        ),
      );

      final logoFinder = find.byType(TeknoyCartLogo);
      expect(logoFinder, findsOneWidget);

      final customPaintFinder = find.descendant(
        of: logoFinder,
        matching: find.byType(CustomPaint),
      );
      expect(customPaintFinder, findsOneWidget);

      final sizedBoxFinder = find.descendant(
        of: logoFinder,
        matching: find.byType(SizedBox),
      );
      expect(sizedBoxFinder, findsOneWidget);

      final SizedBox sizedBox = tester.widget(sizedBoxFinder);
      expect(sizedBox.width, 48.0);
      expect(sizedBox.height, 48.0);
    });

    testWidgets('respects custom size and custom color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TeknoyCartLogo(
                size: 64.0,
                color: TeknoyTheme.citGold,
              ),
            ),
          ),
        ),
      );

      final logoFinder = find.byType(TeknoyCartLogo);
      expect(logoFinder, findsOneWidget);

      final TeknoyCartLogo logo = tester.widget(logoFinder);
      expect(logo.size, 64.0);
      expect(logo.color, TeknoyTheme.citGold);
    });
  });
}
