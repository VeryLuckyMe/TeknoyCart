import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
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

  group('UnreadChatCountNotifier Unit Tests', () {
    test('increment, decrement, and reset manage state accurately', () {
      final notifier = UnreadChatCountNotifier(SupabaseConfig.client, 'user-123', autoInit: false);
      expect(notifier.state, 0);

      notifier.increment();
      expect(notifier.state, 1);

      notifier.increment();
      expect(notifier.state, 2);

      notifier.decrement();
      expect(notifier.state, 1);

      notifier.decrement();
      expect(notifier.state, 0);

      // Decrement does not go below 0
      notifier.decrement();
      expect(notifier.state, 0);

      notifier.increment();
      notifier.increment();
      notifier.reset();
      expect(notifier.state, 0);
    });

    test('incoming realtime message payload increments only when from other user and unread', () {
      final notifier = UnreadChatCountNotifier(SupabaseConfig.client, 'my-user-id', autoInit: false);

      // Message from another user, unread -> increment
      notifier.handleIncomingMessage({
        'sender_id': 'other-user-id',
        'is_read': false,
        'content': 'Hello!',
      });
      expect(notifier.state, 1);

      // Message from oneself -> do NOT increment
      notifier.handleIncomingMessage({
        'sender_id': 'my-user-id',
        'is_read': false,
        'content': 'My own message',
      });
      expect(notifier.state, 1);

      // Message already read -> do NOT increment
      notifier.handleIncomingMessage({
        'sender_id': 'other-user-id',
        'is_read': true,
        'content': 'Already read',
      });
      expect(notifier.state, 1);
    });
  });

  group('Bottom Navigation Messages Badge UI Tests', () {
    final mockProfile = Profile(
      id: 'my-user-id',
      username: 'Test User',
      email: 'test@cit.edu',
      role: 'STUDENT',
      createdAt: DateTime.now(),
    );

    testWidgets('Messages tab hides badge when unreadChatCount is 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(mockProfile)),
            unreadChatCountProvider.overrideWith((ref) => 0),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Messages tab icon is rendered
      expect(find.byIcon(Icons.forum_outlined), findsOneWidget);
      // No badge number is displayed on the bottom bar
      expect(find.text('0'), findsNothing);
    });

    testWidgets('Messages tab renders badge pill with count when unreadChatCount > 0', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(mockProfile)),
            unreadChatCountProvider.overrideWith((ref) => 3),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3'), findsWidgets);
    });

    testWidgets('Messages tab renders 99+ when unreadChatCount exceeds 99', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(mockProfile)),
            unreadChatCountProvider.overrideWith((ref) => 120),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('99+'), findsWidgets);
    });
  });
}
