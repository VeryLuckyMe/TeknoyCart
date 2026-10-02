import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/tabs/browse_tab.dart';
import 'package:teknoycart/core/models/product.dart';

void main() {
  testWidgets('BrowseTab renders interactive Spotlight Hero and suppresses redundant banner', (WidgetTester tester) async {
    final mockProduct = Product(
      id: 'test-prd-1',
      title: 'T-Square Drafting Tool',
      price: 250.0,
      description: 'Used drafting tool',
      sellerId: 'seller-1',
      sellerStoreName: 'Wildcat Senior',
      category: 'Drawing Tools',
      condition: 'Like New',
      imageUrl: '',
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsListNotifierProvider.overrideWith((ref) => MockProductListNotifier([mockProduct])),
        ],
        child: MaterialApp(
          theme: TeknoyTheme.darkTheme,
          home: const Scaffold(
            body: BrowseTab(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Wildcat Campus Spotlight Hero is rendered
    expect(find.text('CAMPUS SPOTLIGHT'), findsOneWidget);
    expect(find.text('Save 50% on Engineering Drawing Boards'), findsOneWidget);
    expect(find.byIcon(Icons.architecture_rounded), findsOneWidget);

    // 2. Verify redundant FeedTrendingBanner with external picsum image is NOT present
    expect(find.text('Pre-Loved\nEngineering Books'), findsNothing);
    expect(find.text('🔥 EXCLUSIVE OFFER'), findsNothing);

    // 3. Tap Spotlight Hero and verify interactive category filter trigger
    final heroFinder = find.text('Save 50% on Engineering Drawing Boards');
    await tester.tap(heroFinder);
    await tester.pumpAndSettle();

    // 4. Verify category filtering state reflects interaction
    expect(find.text('Showing verified Drawing Tools • Tap to view all'), findsOneWidget);
  });
}

class MockProductListNotifier extends StateNotifier<AsyncValue<List<Product>>> implements ProductListNotifier {
  final List<Product> _mockData;
  MockProductListNotifier(this._mockData) : super(AsyncValue.data(_mockData));

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(_mockData);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
