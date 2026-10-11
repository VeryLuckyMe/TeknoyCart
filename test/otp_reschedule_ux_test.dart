import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'mock_http_client.dart';

void main() {
  setUpAll(() async {
    HttpOverrides.global = MockHttpOverrides();
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel('plugins.flutter.io/shared_preferences')
        .setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAll') return <String, dynamic>{};
      return null;
    });
    await SupabaseConfig.initialize();
  });

  Profile makeSellerProfile({String id = 'seller-123'}) => Profile(
        id: id,
        username: 'Test Seller',
        email: 'seller@cit.edu',
        role: 'SELLER',
        isSellerVerified: true,
        createdAt: DateTime(2025, 1, 1),
      );

  Profile makeBuyerProfile({String id = 'buyer-456'}) => Profile(
        id: id,
        username: 'Clark Kent',
        email: 'buyer@cit.edu',
        role: 'BUYER',
        isSellerVerified: false,
        createdAt: DateTime(2025, 1, 1),
      );

  Map<String, dynamic> makeOrder({
    required String orderId,
    required String status,
    String? handoffOtp,
    String? otpCreatedAt,
    String paymentMethod = 'GCASH',
    String sellerId = 'seller-123',
    String buyerId = 'buyer-456',
  }) {
    return {
      'order_id': orderId,
      'status': status,
      'payment_method': paymentMethod,
      'seller_id': sellerId,
      'buyer_id': buyerId,
      'buyer_name': 'Clark Kent',
      'seller_name': 'Test Seller',
      'total_amount': '150.00',
      'pickup_location': 'Library Lobby',
      'pickup_day': 'Today',
      'pickup_time': '12:00 PM - 01:30 PM',
      'handoff_otp': handoffOtp,
      'otp_created_at': otpCreatedAt,
      'created_at': DateTime.now().toIso8601String(),
      'version': 0,
    };
  }

  Widget createWidget({
    required Map<String, dynamic> order,
    required Profile user,
    required bool isSeller,
    required WidgetTester tester,
  }) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    return ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => AsyncValue.data(user)),
      ],
      child: MaterialApp(
        home: OrderDetailView(
          order: order,
          isSeller: isSeller,
        ),
      ),
    );
  }

  group('Expired OTP & Meetup Reschedule UX Tests', () {
    testWidgets('Buyer with expired OTP (>48 hours) sees Handoff Code Expired warning and Generate Fresh Code & QR button', (tester) async {
      // Created 50 hours ago (expired beyond 48-hour security window)
      final expiredAt = DateTime.now().toUtc().subtract(const Duration(hours: 50)).toIso8601String();
      final order = makeOrder(
        orderId: 'ORD-EXP-001',
        status: 'MEETUP_SCHEDULED',
        handoffOtp: '654321',
        otpCreatedAt: expiredAt,
      );
      final buyer = makeBuyerProfile();

      await tester.pumpWidget(createWidget(order: order, user: buyer, isSeller: false, tester: tester));
      await tester.pumpAndSettle();

      expect(find.text('Handoff Code Expired'), findsOneWidget);
      expect(find.textContaining('Meetup security window (48 hours) has elapsed'), findsOneWidget);
      expect(find.text('EXPIRED CODE'), findsOneWidget);
      expect(find.text('Generate Fresh Code & QR'), findsOneWidget);
    });

    testWidgets('Buyer with active OTP for Today sees Code Ready banner and Regenerate Code / Refresh QR button', (tester) async {
      // Created 1 hour ago (within 48-hour window)
      final activeAt = DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String();
      final order = makeOrder(
        orderId: 'ORD-ACT-002',
        status: 'MEETUP_SCHEDULED',
        handoffOtp: '123456',
        otpCreatedAt: activeAt,
      );
      final buyer = makeBuyerProfile();

      await tester.pumpWidget(createWidget(order: order, user: buyer, isSeller: false, tester: tester));
      await tester.pumpAndSettle();

      expect(find.text('Handoff Verification'), findsOneWidget);
      expect(find.textContaining('Code Ready • Today'), findsOneWidget);
      expect(find.text('Regenerate Code / Refresh QR'), findsOneWidget);
    });

    testWidgets('Buyer with active OTP for Tomorrow sees Campus Meetup Scheduled and At Meetup Spot? Refresh Code & QR button', (tester) async {
      // Created 2 hours ago for a tomorrow rendezvous
      final activeAt = DateTime.now().toUtc().subtract(const Duration(hours: 2)).toIso8601String();
      final order = makeOrder(
        orderId: 'ORD-TOM-003',
        status: 'MEETUP_SCHEDULED',
        handoffOtp: '789012',
        otpCreatedAt: activeAt,
      );
      order['pickup_day'] = 'Tomorrow';
      final buyer = makeBuyerProfile();

      await tester.pumpWidget(createWidget(order: order, user: buyer, isSeller: false, tester: tester));
      await tester.pumpAndSettle();

      expect(find.text('Campus Meetup Scheduled'), findsOneWidget);
      expect(find.textContaining('Tomorrow • 12:00 PM - 01:30 PM'), findsOneWidget);
      expect(find.textContaining('Rendezvous: Library Lobby'), findsOneWidget);
      expect(find.text('At Meetup Spot? Refresh Code & QR'), findsOneWidget);
    });

    testWidgets('Seller in MEETUP_SCHEDULED sees Reschedule Meetup / Update Time button', (tester) async {
      final order = makeOrder(
        orderId: 'ORD-SEL-003',
        status: 'MEETUP_SCHEDULED',
        handoffOtp: '123456',
      );
      final seller = makeSellerProfile();

      await tester.pumpWidget(createWidget(order: order, user: seller, isSeller: true, tester: tester));
      await tester.pumpAndSettle();

      expect(find.text('Verify Buyer Handoff (OTP)'), findsOneWidget);
      expect(find.text('Reschedule Meetup / Update Time'), findsOneWidget);
      expect(find.text('Report No-Show'), findsOneWidget);
    });

    testWidgets('Seller tapping Reschedule Meetup / Update Time opens reschedule sheet', (tester) async {
      final order = makeOrder(
        orderId: 'ORD-SEL-004',
        status: 'MEETUP_SCHEDULED',
        handoffOtp: '123456',
      );
      final seller = makeSellerProfile();

      await tester.pumpWidget(createWidget(order: order, user: seller, isSeller: true, tester: tester));
      await tester.pumpAndSettle();

      final rescheduleBtn = find.text('Reschedule Meetup / Update Time');
      expect(rescheduleBtn, findsOneWidget);
      await tester.tap(rescheduleBtn);
      await tester.pumpAndSettle();

      expect(find.text('Reschedule Meetup / Update Time'), findsWidgets);
      expect(find.text('Update Schedule & Generate Fresh Code'), findsOneWidget);
    });
  });
}
