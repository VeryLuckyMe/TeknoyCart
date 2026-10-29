import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/services/wishlist_service.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';

class FakeWishlistStorage implements WishlistStorageAdapter {
  final Map<String, String> db = {};
  @override
  Future<String?> read(String key) async => db[key];
  @override
  Future<void> write(String key, String value) async => db[key] = value;
  @override
  Future<void> delete(String key) async => db.remove(key);
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
}
