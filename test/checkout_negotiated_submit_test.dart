import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/checkout_view.dart';

import 'mock_http_client.dart';
import 'support/test_harness.dart';

/// End-to-end proof that the widget sends the price it displays and the chat
/// id the server needs to verify the seller's acceptance.
void main() {
  late MockHttpOverrides overrides;

  setUpAll(() async {
    overrides = await TestHarness.setUpAllEnvironment();
  });

  testWidgets('submits the accepted Tawad price and chat id to checkout',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final user = Profile(
      id: 'usr-1',
      username: 'teknoy_wildcat',
      email: 'teknoy@cit.edu',
      createdAt: DateTime.now(),
    );

    final product = Product(
      id: 'prod-test-1',
      title: 'Drawing Board Kit',
      description: 'CIT-U Drawing board with straightedge ruler.',
      price: 300.0,
      category: 'Drawing Tools',
      condition: 'Like New',
      sellerId: 'usr-123',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AsyncValue.data(user)),
          inertUnreadChatCountOverride,
        ],
        child: MaterialApp(
          home: CheckoutView(
            product: product,
            agreedPrice: 255.0,
            isDirectBuy: true,
            roomId: '11111111-1111-4111-8111-111111111111',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    overrides.requestBodies.clear();
    await tester.tap(find.byKey(const Key('checkout-confirm-deal-btn')));
    await tester.pumpAndSettle();

    final checkoutBody = overrides.requestBodies.firstWhere(
      (body) => body.contains('p_chat_id'),
      orElse: () => '',
    );

    expect(checkoutBody, isNotEmpty,
        reason: 'checkout must call the negotiated 4-argument RPC');
    expect(checkoutBody, contains('11111111-1111-4111-8111-111111111111'));
    // The serialized line price must match the Tawad price on screen.
    expect(checkoutBody, contains('"unit_price":255'));
    expect(checkoutBody, isNot(contains('"unit_price":300')));
  });

  testWidgets('demo chat checkout sends catalog price and no chat id',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final user = Profile(
      id: 'usr-1',
      username: 'teknoy_wildcat',
      email: 'teknoy@cit.edu',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => AsyncValue.data(user)),
          inertUnreadChatCountOverride,
        ],
        child: MaterialApp(
          home: CheckoutView(
            product: Product(
              id: 'prod-test-1',
              title: 'Drawing Board Kit',
              description: 'CIT-U Drawing board with straightedge ruler.',
              price: 300.0,
              category: 'Drawing Tools',
              condition: 'Like New',
              sellerId: 'usr-123',
              createdAt: DateTime.now(),
            ),
            agreedPrice: 255.0,
            isDirectBuy: true,
            roomId: 'room-demo',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    overrides.requestBodies.clear();
    await tester.tap(find.byKey(const Key('checkout-confirm-deal-btn')));
    await tester.pumpAndSettle();

    final checkoutBody = overrides.requestBodies.firstWhere(
      (body) => body.contains('p_lines'),
      orElse: () => '',
    );

    expect(checkoutBody, isNotEmpty, reason: 'demo checkout must still work');
    expect(checkoutBody, isNot(contains('p_chat_id')));
    // Demo checkout charges catalog, exactly what the screen displays.
    expect(checkoutBody, contains('"unit_price":300'));

    // Let the demo auto-reply timer fire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
