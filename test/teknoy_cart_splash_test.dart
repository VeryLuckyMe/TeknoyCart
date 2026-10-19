import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/splash/splash_view.dart';
import 'package:teknoycart/features/splash/teknoy_cart_logo_painter.dart';
import 'mock_http_client.dart';

void main() {
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
    await SupabaseConfig.initialize();
  });

  group('TeknoyCartLogoPainter Unit Tests', () {
    test('paints cleanly without throwing at various animation values', () {
      final painter = TeknoyCartLogoPainter(
        cartSlideX: 0.0,
        cartTilt: 0.05,
        cartBounceY: 0.2,
        boxDropY: 0.0,
        boxOpacity: 1.0,
        bookDropY: 0.0,
        bookOpacity: 1.0,
        gear1DropY: 0.0,
        gear1Opacity: 1.0,
        gear1Angle: 1.5,
        gear2DropY: 0.0,
        gear2Opacity: 1.0,
        gear2Angle: 1.5,
        primaryColor: TeknoyTheme.citMaroon,
        isDark: false,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(140, 140);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
    });

    test('shouldRepaint returns true when properties change', () {
      final painter1 = TeknoyCartLogoPainter(
        cartSlideX: -1.0,
        cartTilt: 0.0,
        cartBounceY: 0.0,
        boxDropY: -1.0,
        boxOpacity: 0.0,
        bookDropY: -1.0,
        bookOpacity: 0.0,
        gear1DropY: -1.0,
        gear1Opacity: 0.0,
        gear1Angle: 0.0,
        gear2DropY: -1.0,
        gear2Opacity: 0.0,
        gear2Angle: 0.0,
        primaryColor: TeknoyTheme.citMaroon,
        isDark: false,
      );

      final painter2 = TeknoyCartLogoPainter(
        cartSlideX: 0.0,
        cartTilt: 0.0,
        cartBounceY: 0.0,
        boxDropY: 0.0,
        boxOpacity: 1.0,
        bookDropY: 0.0,
        bookOpacity: 1.0,
        gear1DropY: 0.0,
        gear1Opacity: 1.0,
        gear1Angle: 0.0,
        gear2DropY: 0.0,
        gear2Opacity: 1.0,
        gear2Angle: 0.0,
        primaryColor: TeknoyTheme.citMaroon,
        isDark: false,
      );

      expect(painter2.shouldRepaint(painter1), isTrue);
    });
  });

  group('SplashView Assembly & In-Place Settle Widget Tests', () {
    testWidgets('renders SplashView and reaches settle phase without error', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SplashView(),
          ),
        ),
      );

      // Frame 0: Blank canvas check
      expect(find.byType(SplashView), findsOneWidget);
      await tester.pump();

      // Pump 200ms into Step 2 (cart flash-in)
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(CustomPaint), findsWidgets);

      // Pump through Step 3 (box drop), Step 4 (book drop), Step 5 (gear 1)
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(CustomPaint), findsWidgets);

      // Pump through Step 7 (brand reveal)
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('TEKNOYCART'), findsOneWidget);
      expect(find.text('CIT-U EXCLUSIVE CAMPUS MARKETPLACE'), findsOneWidget);

      // Pump through Step 8 settle
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
