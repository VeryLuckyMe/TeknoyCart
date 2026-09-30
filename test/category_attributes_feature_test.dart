import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/product_details_sheet.dart';
import 'package:teknoycart/features/feed/views/widgets/feed_product_card.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:flutter/services.dart';
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

  group('Category Templates & Categories Provider Tests', () {
    test('sellCategoriesProvider contains all expanded categories including Clothes', () {
      final container = ProviderContainer();
      final categories = container.read(sellCategoriesProvider);
      expect(categories, contains('Books'));
      expect(categories, contains('Drawing Tools'));
      expect(categories, contains('Uniforms'));
      expect(categories, contains('Clothes'));
      expect(categories, contains('Electronics'));
      expect(categories, contains('Food & Beverages'));
      expect(categories, contains('School Supplies'));
      expect(categories, contains('Services'));
      expect(categories, contains('Others'));
      expect(categories.length, 9);
    });

    test('categoriesProvider contains All plus all categories for browsing', () {
      final container = ProviderContainer();
      final categories = container.read(categoriesProvider);
      expect(categories.first, 'All');
      expect(categories.length, 10);
      expect(categories, contains('Clothes'));
      expect(categories, contains('Uniforms'));
      expect(categories, contains('Food & Beverages'));
      expect(categories, contains('School Supplies'));
    });

    test('Uniforms template has Size and Uniform Type without Color', () async {
      final container = ProviderContainer();
      final templatesMap = await container.read(categoryAttributeTemplatesProvider.future);

      expect(templatesMap.containsKey('Uniforms'), isTrue);
      final uniformTemplates = templatesMap['Uniforms']!;
      final uniformNames = uniformTemplates.map((t) => t.name).toList();
      expect(uniformNames, contains('Size'));
      expect(uniformNames, contains('Uniform Type'));
      expect(uniformNames, contains('Gender'));
      // Verify color was removed from uniforms
      expect(uniformNames.contains('Color'), isFalse);

      final sizeTemplate = uniformTemplates.firstWhere((t) => t.name == 'Size');
      expect(sizeTemplate.type, 'select');
      expect(sizeTemplate.options, containsAll(['XS', 'S', 'M', 'L', 'XL', '32', '34']));

      final typeTemplate = uniformTemplates.firstWhere((t) => t.name == 'Uniform Type');
      expect(typeTemplate.type, 'select');
      expect(typeTemplate.options, containsAll(['PE Uniform', 'School Uniform']));
    });

    test('Clothes template supports T-Shirt, Shorts, Jorts, Size with numeric waist sizes (33, 34), Color, and Fit', () async {
      final container = ProviderContainer();
      final templatesMap = await container.read(categoryAttributeTemplatesProvider.future);

      expect(templatesMap.containsKey('Clothes'), isTrue);
      final clothesTemplates = templatesMap['Clothes']!;
      final clothesNames = clothesTemplates.map((t) => t.name).toList();
      expect(clothesNames, contains('Clothing Type'));
      expect(clothesNames, contains('Size'));
      expect(clothesNames, contains('Color'));
      expect(clothesNames, contains('Gender / Fit'));
      expect(clothesNames, contains('Brand'));

      final typeTemplate = clothesTemplates.firstWhere((t) => t.name == 'Clothing Type');
      expect(typeTemplate.type, 'select');
      expect(typeTemplate.options, contains('T-Shirt'));
      expect(typeTemplate.options, contains('Shorts'));
      expect(typeTemplate.options, contains('Jorts'));

      final sizeTemplate = clothesTemplates.firstWhere((t) => t.name == 'Size');
      expect(sizeTemplate.options, containsAll(['XS', 'S', 'M', 'L', 'XL', '33', '34', '36']));
    });

    test('Electronics, Food, and School Supplies have complete attribute templates', () async {
      final container = ProviderContainer();
      final templatesMap = await container.read(categoryAttributeTemplatesProvider.future);

      // Verify Electronics templates: Brand, Model, Specs, Warranty
      expect(templatesMap.containsKey('Electronics'), isTrue);
      final electronicsTemplates = templatesMap['Electronics']!;
      final electronicNames = electronicsTemplates.map((t) => t.name).toList();
      expect(electronicNames, contains('Brand'));
      expect(electronicNames, contains('Model'));
      expect(electronicNames, contains('Specs'));
      expect(electronicNames, contains('Warranty'));

      // Verify Food & Beverages templates: Type, Flavor/Variant, Allergens, Expiry Date
      expect(templatesMap.containsKey('Food & Beverages'), isTrue);
      final foodTemplates = templatesMap['Food & Beverages']!;
      final foodNames = foodTemplates.map((t) => t.name).toList();
      expect(foodNames, contains('Type'));
      expect(foodNames, contains('Flavor/Variant'));
      expect(foodNames, contains('Allergens'));

      // Verify School Supplies templates: Type, Brand, Size/Specification, Pack Quantity
      expect(templatesMap.containsKey('School Supplies'), isTrue);
      final schoolTemplates = templatesMap['School Supplies']!;
      final schoolNames = schoolTemplates.map((t) => t.name).toList();
      expect(schoolNames, contains('Type'));
      expect(schoolNames, contains('Brand'));
      expect(schoolNames, contains('Pack Quantity'));
    });
  });

  group('Category Attributes UI Rendering Tests', () {
    testWidgets('FeedProductCard displays Size and Uniform Type for Uniforms (no color)', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final uniformProduct = Product(
        id: 'prod-uniform-test',
        title: 'CIT-U PE Uniform Shirt',
        description: 'Clean PE shirt',
        price: 250.0,
        category: 'Uniforms',
        condition: 'Like New',
        sellerId: 'seller-1',
        sellerStoreName: 'Wildcat Threads',
        createdAt: DateTime.now(),
        categoryAttributes: const [
          ProductAttribute(name: 'Size', value: 'M'),
          ProductAttribute(name: 'Uniform Type', value: 'PE Uniform'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 360,
                child: FeedProductCard(
                  product: uniformProduct,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CIT-U PE Uniform Shirt'), findsOneWidget);
      expect(find.text('Size: M'), findsOneWidget);
      expect(find.text('Uniform Type: PE Uniform'), findsOneWidget);
      expect(find.text('₱250'), findsOneWidget);
    });

    testWidgets('FeedProductCard displays Clothing Type: Jorts for Clothes category', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final jortsProduct = Product(
        id: 'prod-jorts-test',
        title: 'Baggy Denim Jorts',
        description: 'Cool vintage wash jorts',
        price: 320.0,
        category: 'Clothes',
        condition: 'New',
        sellerId: 'seller-clothes-1',
        createdAt: DateTime.now(),
        categoryAttributes: const [
          ProductAttribute(name: 'Clothing Type', value: 'Jorts'),
          ProductAttribute(name: 'Size', value: 'L'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 360,
                child: FeedProductCard(
                  product: jortsProduct,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Baggy Denim Jorts'), findsOneWidget);
      expect(find.text('Clothing Type: Jorts'), findsOneWidget);
      expect(find.text('Size: L'), findsOneWidget);
      expect(find.text('₱320'), findsOneWidget);
    });

    testWidgets('ProductDetailsSheet displays Specifications section with category attributes', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final electronicsProduct = Product(
        id: 'prod-elec-test',
        title: 'Casio Scientific Calculator',
        description: 'Great for calculus exams',
        price: 350.0,
        category: 'Electronics',
        condition: 'Good',
        sellerId: 'seller-2',
        createdAt: DateTime.now(),
        categoryAttributes: const [
          ProductAttribute(name: 'Brand', value: 'Casio'),
          ProductAttribute(name: 'Model', value: 'fx-991ES Plus'),
          ProductAttribute(name: 'Warranty', value: '6 Months'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProductDetailsSheet(product: electronicsProduct),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Specifications heading is shown
      expect(find.text('Specifications'), findsOneWidget);
      // Check attribute labels and values
      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Casio'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('fx-991ES Plus'), findsOneWidget);
      expect(find.text('Warranty'), findsOneWidget);
      expect(find.text('6 Months'), findsOneWidget);
    });

    testWidgets('Product without categoryAttributes does not show Specifications section', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final simpleProduct = Product(
        id: 'prod-simple-test',
        title: 'Simple Note Pad',
        description: 'Standard plain paper notebook.',
        price: 50.0,
        category: 'School Supplies',
        condition: 'New',
        sellerId: 'seller-3',
        createdAt: DateTime.now(),
        categoryAttributes: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProductDetailsSheet(product: simpleProduct),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Specifications'), findsNothing);
    });

    testWidgets('Product with multiple sizes renders interactive variant selector and allows selecting size', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final multiVariantProduct = Product(
        id: 'prod-multi-variant',
        title: 'CIT-U College Polo Uniform',
        description: 'Official uniform polo with embroidery.',
        price: 450.0,
        category: 'Uniforms',
        condition: 'New',
        sellerId: 'seller-uniform-1',
        createdAt: DateTime.now(),
        categoryAttributes: const [
          ProductAttribute(name: 'Uniform Type', value: 'School Uniform'),
          ProductAttribute(name: 'Size', value: 'S, M, L, XL'),
          ProductAttribute(name: 'Gender', value: 'Male'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProductDetailsSheet(product: multiVariantProduct),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check variant selector exists
      expect(find.text('Select Size'), findsOneWidget);
      expect(find.text('Chosen: S'), findsOneWidget);
      expect(find.text('S'), findsWidgets);
      expect(find.text('M'), findsWidgets);
      expect(find.text('L'), findsWidgets);
      expect(find.text('XL'), findsWidgets);

      // Tap on 'M'
      await tester.tap(find.text('M').first);
      await tester.pumpAndSettle();

      // Verify choice changed to M
      expect(find.text('Chosen: M'), findsOneWidget);
    });

    test('primaryCategoryAttributeNames and primaryAttributeQuickSuggestions are properly configured', () {
      // Books
      expect(primaryCategoryAttributeNames['Books'], contains('Subject'));
      expect(primaryAttributeQuickSuggestions['Books']?['Subject'], containsAll(['Calculus', 'Physics', 'Eng. Math', 'CS / IT']));

      // Clothes
      expect(primaryCategoryAttributeNames['Clothes'], containsAll(['Size', 'Clothing Type']));

      // Uniforms
      expect(primaryCategoryAttributeNames['Uniforms'], containsAll(['Size', 'Uniform Type']));

      // Electronics
      expect(primaryCategoryAttributeNames['Electronics'], contains('Brand'));
      expect(primaryAttributeQuickSuggestions['Electronics']?['Brand'], containsAll(['Casio', 'Apple', 'Canon']));

      // Drawing Tools
      expect(primaryCategoryAttributeNames['Drawing Tools'], contains('Type'));

      // Food & Beverages
      expect(primaryCategoryAttributeNames['Food & Beverages'], containsAll(['Type', 'Flavor/Variant']));
    });

    testWidgets('Tapping attribute chip on FeedProductCard opens SearchResultsView', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testProduct = Product(
        id: 'prod-search-test',
        title: 'Engineering Mathematics Vol 1',
        description: 'Complete book',
        price: 300.0,
        category: 'Books',
        condition: 'Good',
        sellerId: 'seller-book-1',
        createdAt: DateTime.now(),
        categoryAttributes: const [
          ProductAttribute(name: 'Subject', value: 'Calculus'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 360,
                child: FeedProductCard(product: testProduct),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Subject: Calculus'), findsOneWidget);

      // Tap the attribute chip
      await tester.tap(find.text('Subject: Calculus'));
      await tester.pumpAndSettle();

      // Verify SearchResultsView is pushed with 'Calculus' query
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Matching Stores'), findsOneWidget);
    });

    testWidgets('Sell tab renders professional 2x2 condition card grid without emojis or vibe-coded badges', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final verifiedSellerUser = Profile(
        id: 'seller-test-id',
        username: 'Test Seller',
        email: 'seller@cit.edu',
        role: 'SELLER',
        isSellerVerified: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => Stream.value(verifiedSellerUser)),
          ],
          child: const MaterialApp(
            home: ProductDiscoveryFeedView(initialTab: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify clean header exists
      expect(find.text('Item Condition *'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);

      // Verify no vibe-coded badges or emoji strings exist
      expect(find.text('1-Tap Choice'), findsNothing);
      expect(find.textContaining('✨'), findsNothing);
      expect(find.textContaining('💎'), findsNothing);
      expect(find.textContaining('👍'), findsNothing);

      // Verify professional cards exist with titles and sub-descriptions
      expect(find.text('Brand New'), findsOneWidget);
      expect(find.text('Unopened or never used'), findsOneWidget);
      expect(find.text('Like New'), findsOneWidget);
      expect(find.text('Flawless, barely used'), findsOneWidget);
      expect(find.text('Gently Used'), findsOneWidget);
      expect(find.text('Minor wear, fully works'), findsOneWidget);
      expect(find.text('Well Used'), findsOneWidget);
      expect(find.text('Visible wear, discounted'), findsOneWidget);

      // Tap 'Like New' card and verify selection
      await tester.tap(find.text('Like New'));
      await tester.pumpAndSettle();
    });
  });
}

