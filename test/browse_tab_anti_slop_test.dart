import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/tabs/browse_tab.dart';
import 'package:teknoycart/core/models/product.dart';

void main() {
  testWidgets('BrowseTab renders 3-slide interactive Spotlight Carousel and auto-collapses during search',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockProducts = [
      Product(
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
      ),
      Product(
        id: 'test-prd-2',
        title: 'Engineering Calculus Book',
        price: 350.0,
        description: 'Clean textbook',
        sellerId: 'seller-2',
        sellerStoreName: 'CEA Grad',
        category: 'Books',
        condition: 'Good',
        imageUrl: '',
        createdAt: DateTime.now(),
      ),
      Product(
        id: 'test-prd-3',
        title: 'CIT-U PE Uniform Medium',
        price: 300.0,
        description: 'Official PE shirt',
        sellerId: 'seller-3',
        sellerStoreName: 'CCS Student',
        category: 'Uniforms',
        condition: 'New',
        imageUrl: '',
        createdAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsListNotifierProvider.overrideWith(
            (ref) => MockProductListNotifier(mockProducts),
          ),
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

    // 1. Verify Slide 0 (Drawing Tools Spotlight) is rendered
    expect(find.text('CAMPUS SPOTLIGHT'), findsOneWidget);
    expect(find.text('Save 50% on Engineering Drawing Boards'), findsOneWidget);
    expect(find.byIcon(Icons.architecture_rounded), findsOneWidget);

    // Tap Slide 0 and verify category filtering state reflects interaction
    await tester.tap(find.text('Save 50% on Engineering Drawing Boards'));
    await tester.pumpAndSettle();
    expect(find.text('Showing verified Drawing Tools • Tap to view all'), findsOneWidget);

    // 2. Swipe left to Slide 1 (Textbook Deals) and tap to filter Books
    await tester.drag(find.byKey(const Key('browse_spotlight_pageview')), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('TEXTBOOK DEALS'), findsOneWidget);
    expect(find.text('Up to 40% Off Senior Engineering Books'), findsOneWidget);

    await tester.tap(find.text('Up to 40% Off Senior Engineering Books'));
    await tester.pumpAndSettle();
    expect(find.text('Showing verified Books • Tap to view all'), findsOneWidget);

    // 3. Swipe left to Slide 2 (Wildcat Essentials) and tap to filter Uniforms
    await tester.drag(find.byKey(const Key('browse_spotlight_pageview')), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('WILDCAT ESSENTIALS'), findsOneWidget);
    expect(find.text('Official CIT-U Uniforms & Lanyards'), findsOneWidget);

    await tester.tap(find.text('Official CIT-U Uniforms & Lanyards'));
    await tester.pumpAndSettle();
    expect(find.text('Showing verified Uniforms • Tap to view all'), findsOneWidget);

    // 4. Typing a search query auto-collapses the Spotlight banner
    await tester.enterText(find.byType(TextField), 'Calculus');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('browse_spotlight_pageview')), findsNothing);
  });
}

class MockProductListNotifier extends StateNotifier<AsyncValue<List<Product>>>
    implements ProductListNotifier {
  final List<Product> _mockData;
  MockProductListNotifier(this._mockData) : super(AsyncValue.data(_mockData));

  @override
  Future<void> refresh() async {
    state = AsyncValue.data(_mockData);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
