import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/views/manage_listings_view.dart';
import 'package:teknoycart/features/feed/views/tabs/profile_tab.dart';
import 'package:teknoycart/features/reports/views/financial_reports_view.dart';
import 'mock_http_client.dart';

void main() {
  late MockHttpOverrides mockHttp;

  setUpAll(() async {
    mockHttp = MockHttpOverrides();
    HttpOverrides.global = mockHttp;
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/shared_preferences'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') return <String, dynamic>{};
        return null;
      },
    );
    await SupabaseConfig.initialize();
  });

  group('GAP-04: Seller Sales Analytics & Reports Navigation Tests', () {
    final verifiedSeller = Profile(
      id: 'seller-verified-01',
      username: 'CIT Tech Merch',
      email: 'techmerch@cit.edu',
      role: 'SELLER',
      isSellerVerified: true,
      createdAt: DateTime.now(),
    );

    final regularBuyer = Profile(
      id: 'buyer-student-01',
      username: 'Regular Buyer',
      email: 'buyer@cit.edu',
      role: 'BUYER',
      isSellerVerified: false,
      createdAt: DateTime.now(),
    );

    testWidgets('Verified seller profile renders Sales & Financial Reports tile in settings', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(verifiedSeller)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sales & Financial Reports'), findsOneWidget);
      expect(find.textContaining('revenue breakdown'), findsOneWidget);
    });

    testWidgets('Verified seller profile renders Sales Analytics action button in Vendor Control Hub', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(verifiedSeller)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sales Analytics'), findsOneWidget);
    });

    testWidgets('Tapping Sales & Financial Reports tile navigates to FinancialReportsView', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(verifiedSeller)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.text('Sales & Financial Reports');
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(FinancialReportsView), findsOneWidget);
    });

    testWidgets('Regular student buyer profile suppresses sales analytics buttons and settings tile', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(regularBuyer)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sales & Financial Reports'), findsNothing);
      expect(find.text('Sales Analytics'), findsNothing);
    });

    testWidgets('ManageListingsView exposes AppBar action for Sales Analytics that opens FinancialReportsView', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(verifiedSeller)),
          ],
          child: const MaterialApp(
            home: ManageListingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final analyticsAction = find.byTooltip('Sales Analytics & Reports');
      expect(analyticsAction, findsOneWidget);

      await tester.tap(analyticsAction);
      await tester.pumpAndSettle();

      expect(find.byType(FinancialReportsView), findsOneWidget);
    });
  });
}
