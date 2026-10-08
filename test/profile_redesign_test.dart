import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:teknoycart/core/supabase_client.dart';
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

  group('Profile Page Redesign & Ponytail Heuristics Widget Tests', () {
    late Profile testStudent;

    setUp(() {
      testStudent = Profile(
        id: 'usr-student-42',
        username: 'Mikel Wildcat',
        email: 'mikel.student@cit.edu',
        studentId: '21-0492-811',
        department: 'College of Computer Studies',
        contact: '09171234567',
        gcashNumber: '09171234567',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime.now(),
      );
    });

    testWidgets('renders Digital Wildcat Student ID Pass and institutional branding', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testStudent)),
            productsListProvider.overrideWith((ref) => Future.value(<Product>[])),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(initialTab: 4),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Institutional ribbon text
      expect(find.text('CEBU INSTITUTE OF TECHNOLOGY - UNIVERSITY'), findsOneWidget);
      expect(find.text('TEKNOYCART OFFICIAL STUDENT PASS'), findsOneWidget);
      expect(find.text('OFFICIAL'), findsOneWidget);

      // Student identity
      expect(find.text('Mikel Wildcat'), findsOneWidget);
      expect(find.text('ID: 21-0492-811'), findsOneWidget);
      expect(find.text('mikel.student@cit.edu'), findsWidgets);
      expect(find.text('ENROLLED WILDCAT BUYER'), findsOneWidget);
      expect(find.text('College of Computer Studies'), findsWidgets);

      // 3-Pillar Metrics Strip
      expect(find.text('Listings'), findsOneWidget);
      expect(find.text('Deals Done'), findsOneWidget);
      expect(find.text('Reputation'), findsOneWidget);

      // Inset Group 1: Campus Credentials
      expect(find.text('CAMPUS CREDENTIALS'), findsOneWidget);
      expect(find.text('Edit Details'), findsOneWidget);
      expect(find.text('LOCKED'), findsOneWidget);

      // Inset Group 2: Marketplace & Orders
      expect(find.text('MARKETPLACE & ORDERS'), findsOneWidget);
      expect(find.text('My Orders & Reservations'), findsOneWidget);
      expect(find.text('Inventory & Listings Hub'), findsOneWidget);
      expect(find.text('Buyer Reviews & Feedback'), findsOneWidget);

      // Inset Group 3: Campus Trust & Safety
      expect(find.text('CAMPUS TRUST & SAFETY'), findsOneWidget);
      expect(find.text('Campus Meetup Safe Zones'), findsOneWidget);
      expect(find.text('Terms of Student Commerce'), findsOneWidget);

      // Inset Group 4: Account Actions
      expect(find.text('ACCOUNT SETTINGS'), findsOneWidget);
      expect(find.text('Sign Out Account'), findsOneWidget);
      expect(find.text('Delete Account Permanently'), findsOneWidget);
    });

    testWidgets('tapping Campus Meetup Safe Zones opens guidelines modal sheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testStudent)),
            productsListProvider.overrideWith((ref) => Future.value(<Product>[])),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(initialTab: 4),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Campus Meetup Safe Zones
      final safeZonesTile = find.text('Campus Meetup Safe Zones');
      expect(safeZonesTile, findsOneWidget);
      await tester.tap(safeZonesTile);
      await tester.pumpAndSettle();

      // Verify bottom sheet contents
      expect(find.text('Campus Trade Safe Zones'), findsOneWidget);
      expect(find.text('CIT-U Student Lounge'), findsOneWidget);
      expect(find.text('University Library Lobby'), findsOneWidget);
      expect(find.text('Main Campus Food Court'), findsOneWidget);
      expect(find.text('University Main Gate Security Post'), findsOneWidget);
    });

    testWidgets('tapping Terms of Student Commerce opens honor code modal sheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testStudent)),
            productsListProvider.overrideWith((ref) => Future.value(<Product>[])),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(initialTab: 4),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Terms of Student Commerce
      final termsTile = find.text('Terms of Student Commerce');
      expect(termsTile, findsOneWidget);
      await tester.tap(termsTile);
      await tester.pumpAndSettle();

      // Verify bottom sheet contents
      expect(find.text('Terms of Student Commerce'), findsWidgets);
      expect(find.text('Academic Honor Code Compliance'), findsOneWidget);
      expect(find.text('No Scalping or Ticket Price-Gouging'), findsOneWidget);
      expect(find.text('Accurate Item Disclosures'), findsOneWidget);
    });

    testWidgets('tapping Edit Details opens unified edit profile modal with CIT-U departments', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(testStudent)),
            productsListProvider.overrideWith((ref) => Future.value(<Product>[])),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(initialTab: 4),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Edit Details
      final editBtn = find.text('Edit Details');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      // Verify modal bottom sheet fields
      expect(find.text('Edit Profile Details'), findsOneWidget);
      expect(find.text('CIT-U Department / College'), findsOneWidget);
      expect(find.text('Mobile Contact Number'), findsOneWidget);
      expect(find.text('GCash Payout Number'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });
}
