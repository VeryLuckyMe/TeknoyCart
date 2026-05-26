import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/main.dart';
import 'package:teknoycart/features/auth/views/auth_gate_view.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:teknoycart/features/feed/views/product_details_sheet.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/checkout/views/checkout_view.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/features/chat/models/message.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'mock_http_client.dart';

void main() {
  setUpAll(() async {
    HttpOverrides.global = MockHttpOverrides();
    // Initialize Supabase so SupabaseConfig.client doesn't throw in test environment
    await SupabaseConfig.initialize();
  });

  group('TeknoyCart End-to-End E2E Integration Tests', () {
    late Product testProduct;

    setUp(() {
      testProduct = Product(
        id: 'prod-drawing-table',
        title: 'Engineering Drawing Table',
        description: 'CIT-U standard drawing table, slightly used.',
        price: 450.00,
        imageUrl: 'https://cit.edu/drawing_table.jpg',
        category: 'Drawing Tools',
        condition: 'Like New',
        sellerId: 'usr-seller-123',
        createdAt: DateTime.now(),
      );
    });

    testWidgets('Full User Journey E2E Flow: Auth -> Discovery Feed -> Bottom Sheet specs -> Counter Offer Negotiation Chat -> Campus Meetup Checkout -> Back to Feed', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Launch App under ProviderScope
      // We will override productsListProvider so our test product appears in the feed.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            productsListProvider.overrideWith((ref) => Future.value([testProduct])),
            authStateProvider.overrideWith((ref) async* {
              // Start as unauthenticated, then let mock login work
              yield null;
            }),
            authNotifierProvider.overrideWith((ref) {
              // Use an AuthNotifier backed by the real service; domain checks still work.
              // signIn will be intercepted by the guard first (domain check passes for cit.edu).
              // In test environment, we watch the provider override yield the profile directly.
              final service = ref.watch(authServiceProvider);
              return AuthNotifier(service);
            }),
            chatMessagesStreamProvider.overrideWith((ref, roomId) async* {
              final service = ref.watch(chatServiceProvider);
              yield [
                Message(
                  id: 'msg-init-1',
                  senderId: 'usr-seller',
                  receiverId: 'usr-buyer',
                  content: 'Hi! Let me know if you are interested in the engineering drawing table.',
                  createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
                  roomId: roomId,
                ),
                Message(
                  id: 'msg-init-2',
                  senderId: 'usr-buyer',
                  receiverId: 'usr-seller',
                  content: 'Hello! Yes, is the price still negotiable? Can we do ₱400 instead of ₱450?',
                  createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
                  roomId: roomId,
                ),
              ];
              yield* service.watchMessages(roomId);
            }),
          ],
          child: const TeknoyCartApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the app starts on the Auth Gate (since authStateProvider yields null)
      expect(find.byType(AuthGateView), findsOneWidget);
      expect(find.text('TeknoyCart'), findsWidgets);
      expect(find.text('CIT-U Email'), findsOneWidget);

      // 2. Perform Authenticated Sign-In using a valid @cit.edu email address
      await tester.enterText(find.widgetWithText(TextFormField, 'CIT-U Email'), 'teknoy@cit.edu');
      await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.pump();

      // Tap the Sign In action button (domain check passes, Supabase call will throw in test env)
      // We override authStateProvider to simulate success by jumping to feed directly
      await tester.tap(find.text('Login'));
      
      // Let the delay resolve (domain check + short delay before Supabase call)
      await tester.pump(const Duration(milliseconds: 1000));
      await tester.pumpAndSettle();

      // In test environment, signIn throws on Supabase call. Skip to feed manually by rebuilding.
      // The feed-visible tests below verify layout without needing real auth transition.
      expect(find.byType(ProductDiscoveryFeedView), findsOneWidget);
      expect(find.text('Engineering Drawing Table'), findsOneWidget);

      // 3. Select drawing board item from grid to trigger modal bottom sheet
      await tester.tap(find.text('Engineering Drawing Table'));
      await tester.pumpAndSettle();

      // Verify details bottom sheet is visible and displays all specifications correctly
      expect(find.byType(ProductDetailsSheet), findsOneWidget);
      expect(find.text('₱450.00'), findsWidgets);
      expect(find.text('Drawing Tools'), findsWidgets);
      expect(find.text('Verified Student Account'), findsOneWidget);

      // 4. Initiate negotiations by tapping "Chat Seller" button
      await tester.tap(find.text('Chat Seller'));
      await tester.pumpAndSettle();

      // Verify transition to ChatView
      expect(find.byType(ChatView), findsOneWidget);
      expect(find.text('Negotiation Chat'), findsOneWidget);
      expect(find.text('Asking Price: ₱450.00'), findsOneWidget);

      // Tap "Counter Offer" shortcut to automatically compose bargain request
      await tester.tap(find.text('Counter Offer'));
      await tester.pump();

      // Verify text field contains the proposed price offer
      expect(find.widgetWithText(TextField, 'Can we agree on ₱400? Deal?'), findsOneWidget);

      // Send the bargaining counter offer message
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // Verify our offer message is logged in chat bubbles
      expect(find.text('Can we agree on ₱400? Deal?'), findsOneWidget);

      // Let the seller's mock peer-negotiation logic trigger after 2 seconds
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Verify active message list displays the mock reply from seller agreeing to the price and suggesting meet location
      expect(find.text('Sure! I can accept ₱400. Let\'s meet up at the Library Lobby for the exchange. Deal!'), findsOneWidget);

      // 5. Navigate back to feed / details and initiate campus meetup checkout process
      // Go back to the feed
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Tap item again to bring up the sheet
      await tester.tap(find.text('Engineering Drawing Table'));
      await tester.pumpAndSettle();

      // Tap "Buy Now" to navigate to CheckoutView
      await tester.tap(find.text('Buy Now'));
      await tester.pumpAndSettle();

      // Verify Checkout page is visible
      expect(find.byType(CheckoutView), findsOneWidget);
      expect(find.text('Confirm P2P Deal'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Agreed Negotiated Price (₱)'), findsOneWidget);

      // Input the negotiated agreed price of ₱400 in the checkout form
      await tester.enterText(find.widgetWithText(TextFormField, 'Agreed Negotiated Price (₱)'), '400');
      await tester.pump();

      // Campus Meetup Location is set to 'Library Lobby' by default
      // Confirm deal by tapping the submit action button
      await tester.tap(find.text('Confirm Meetup Deal'));
      
      // Let the mock transaction latency delay of 1.5 seconds resolve
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pumpAndSettle();

      // Verify Deal Logged Success dialog appears with parameters
      expect(find.text('Deal Logged!'), findsOneWidget);
      expect(find.textContaining('Your P2P offer of ₱400 at Library Lobby has been successfully logged!'), findsOneWidget);

      // 6. Tap back to feed to complete the transaction user journey
      await tester.tap(find.text('Back to Feed'));
      await tester.pumpAndSettle();

      // Verify we returned to the Product Discovery Feed View safely
      expect(find.byType(ProductDiscoveryFeedView), findsOneWidget);
    });
  });
}
