import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/services/wishlist_service.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_detail_view.dart';
import 'package:teknoycart/features/feed/views/widgets/feed_product_card.dart';
import 'package:teknoycart/features/feed/views/wishlist_view.dart';

class FakeWishlistStorage implements WishlistStorageAdapter {
  final Map<String, String> db = {};
  @override
  Future<String?> read(String key) async => db[key];
  @override
  Future<void> write(String key, String value) async => db[key] = value;
  @override
  Future<void> delete(String key) async => db.remove(key);
}

class FakeCartStorage implements CartStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

void main() {
  group('WishlistNotifier Unit Tests', () {
    late FakeWishlistStorage fakeStorage;
    late WishlistNotifier notifier;

    setUp(() {
      fakeStorage = FakeWishlistStorage();
      notifier = WishlistNotifier(storage: fakeStorage, autoLoad: false);
    });

    test('toggle adds and removes productId and persists to storage', () async {
      final added = await notifier.toggle('prod-1');
      expect(added, isTrue);
      expect(notifier.state.contains('prod-1'), isTrue);
      expect(fakeStorage.db[WishlistService.storageKey], contains('prod-1'));

      final addedAgain = await notifier.toggle('prod-1');
      expect(addedAgain, isFalse);
      expect(notifier.state.contains('prod-1'), isFalse);
    });

    test('loadFromDisk handles corrupted JSON gracefully without throwing', () async {
      fakeStorage.db[WishlistService.storageKey] = '{not_a_valid_json_array';
      await notifier.loadFromDisk();
      expect(notifier.state, isEmpty);
    });

    test('clearAll and restoreAll manage bulk state for Undo support', () async {
      await notifier.toggle('prod-1');
      await notifier.toggle('prod-2');
      final backup = Set<String>.from(notifier.state);

      await notifier.clearAll();
      expect(notifier.state, isEmpty);

      await notifier.restoreAll(backup);
      expect(notifier.state, equals({'prod-1', 'prod-2'}));
    });

    test('wishlistedProductsProvider resolves only existing products and ignores stale IDs', () async {
      final p1 = Product(
        id: 'prod-1',
        title: 'Calculus Book',
        description: 'Math textbook',
        price: 250.0,
        category: 'Books',
        condition: 'Like New',
        sellerId: 'seller-1',
        createdAt: DateTime.now(),
      );
      await notifier.restoreAll({'prod-1', 'prod-stale-deleted'});

      final container = ProviderContainer(
        overrides: [
          wishlistProvider.overrideWith((ref) => notifier),
          productsListProvider.overrideWith((ref) => Future.value([p1])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(productsListProvider.future);
      final resolved = container.read(wishlistedProductsProvider).valueOrNull;
      expect(resolved, isNotNull);
      expect(resolved!.length, 1);
      expect(resolved.first.id, 'prod-1');
    });
  });

  group('FeedProductCard Reactive Wishlist Sync Tests', () {
    testWidgets('tapping heart on FeedProductCard updates wishlistProvider and reflects pre-saved state',
        (WidgetTester tester) async {
      final fakeStorage = FakeWishlistStorage();
      final notifier = WishlistNotifier(storage: fakeStorage, autoLoad: false);
      final product = Product(
        id: 'prod-sync-1',
        title: 'CIT-U PE Uniform Medium',
        description: 'Official PE shirt',
        price: 300.0,
        category: 'Uniforms',
        condition: 'New',
        sellerId: 'seller-1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wishlistProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 220,
                height: 360,
                child: FeedProductCard(product: product),
              ),
            ),
          ),
        ),
      );

      expect(notifier.state.contains('prod-sync-1'), isFalse);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pumpAndSettle();

      expect(notifier.state.contains('prod-sync-1'), isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    });
  });

  group('WishlistView Screen Widget Tests', () {
    late Product regularProduct;
    late Product preorderProduct;

    setUp(() {
      regularProduct = Product(
        id: 'prod-reg-1',
        title: 'Engineering Thermodynamics Book',
        description: 'Clean textbook',
        price: 420.0,
        category: 'Books',
        condition: 'Like New',
        sellerId: 'seller-1',
        createdAt: DateTime.now(),
      );

      preorderProduct = Product(
        id: 'prod-pre-2',
        title: 'Custom CS Department Lanyard',
        description: 'Pre-order batch',
        price: 150.0,
        category: 'Campus Gear',
        condition: 'New',
        sellerId: 'seller-2',
        isPreorderEnabled: true,
        createdAt: DateTime.now(),
      );
    });

    testWidgets('empty wishlist renders Your Wishlist is Empty and Explore Campus Deals CTA',
        (WidgetTester tester) async {
      final notifier = WishlistNotifier(storage: FakeWishlistStorage(), autoLoad: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wishlistProvider.overrideWith((ref) => notifier),
            productsListProvider.overrideWith((ref) => Future.value([regularProduct])),
          ],
          child: const MaterialApp(
            home: WishlistView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Wishlist is Empty'), findsOneWidget);
      expect(find.text('Explore Campus Deals'), findsOneWidget);
    });

    testWidgets('populated wishlist renders saved items, supports Add to Cart, Remove with Undo, and Clear All',
        (WidgetTester tester) async {
      final notifier = WishlistNotifier(storage: FakeWishlistStorage(), autoLoad: false);
      await notifier.restoreAll({'prod-reg-1', 'prod-pre-2'});
      final cartNotifier = CartNotifier(storage: FakeCartStorage(), autoLoad: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wishlistProvider.overrideWith((ref) => notifier),
            cartProvider.overrideWith((ref) => cartNotifier),
            productsListProvider.overrideWith(
              (ref) => Future.value([regularProduct, preorderProduct]),
            ),
          ],
          child: const MaterialApp(
            home: WishlistView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 Saved Items'), findsOneWidget);
      expect(find.text('Engineering Thermodynamics Book'), findsOneWidget);
      expect(find.text('Custom CS Department Lanyard'), findsOneWidget);

      // Quick Add to Cart on regular product
      await tester.tap(find.byKey(const Key('wishlist_action_prod-reg-1')));
      await tester.pumpAndSettle();
      expect(cartNotifier.state.length, 1);
      expect(cartNotifier.state.first.product.id, 'prod-reg-1');

      // Dismiss current snackbar before testing remove + undo
      ScaffoldMessenger.of(tester.element(find.byType(WishlistView))).clearSnackBars();
      await tester.pumpAndSettle();

      // Remove single item and Undo
      await tester.tap(find.byKey(const Key('wishlist_remove_prod-reg-1')));
      await tester.pumpAndSettle();
      expect(notifier.state.contains('prod-reg-1'), isFalse);
      expect(find.text('1 Saved Item'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(notifier.state.contains('prod-reg-1'), isTrue);
      expect(find.text('2 Saved Items'), findsOneWidget);

      // Clear All with confirmation dialog + Undo
      ScaffoldMessenger.of(tester.element(find.byType(WishlistView))).clearSnackBars();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();
      expect(find.text('Clear Saved Wishlist?'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear All'));
      await tester.pumpAndSettle();
      expect(notifier.state, isEmpty);
      expect(find.text('Your Wishlist is Empty'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(notifier.state.length, 2);
    });

    testWidgets('tapping action on pre-order item routes to ProductDetailView instead of direct cart insert',
        (WidgetTester tester) async {
      final notifier = WishlistNotifier(storage: FakeWishlistStorage(), autoLoad: false);
      await notifier.restoreAll({'prod-pre-2'});
      final cartNotifier = CartNotifier(storage: FakeCartStorage(), autoLoad: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wishlistProvider.overrideWith((ref) => notifier),
            cartProvider.overrideWith((ref) => cartNotifier),
            authStateProvider.overrideWithValue(const AsyncValue.data(null)),
            productsListProvider.overrideWith(
              (ref) => Future.value([preorderProduct]),
            ),
          ],
          child: const MaterialApp(
            home: WishlistView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('View Pre-Order'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wishlist_action_prod-pre-2')));
      await tester.pumpAndSettle();

      expect(cartNotifier.state, isEmpty);
      expect(find.byType(ProductDetailView), findsOneWidget);
    });
  });
}
