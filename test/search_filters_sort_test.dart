import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';

Product _product({
  required String id,
  required String title,
  double price = 100,
  String category = 'Books',
  String condition = 'New',
  String description = '',
  String? storeName,
  DateTime? createdAt,
  List<ProductAttribute> attributes = const [],
}) {
  return Product(
    id: id,
    title: title,
    description: description,
    price: price,
    category: category,
    condition: condition,
    sellerId: 'seller-1',
    sellerStoreName: storeName,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    categoryAttributes: attributes,
  );
}

List<Product> _baseCatalog() => [
      _product(
        id: 'a',
        title: 'Calculus Textbook',
        price: 300,
        category: 'Books',
        condition: 'Gently Used',
        description: 'Stewart 8th edition',
        createdAt: DateTime(2026, 3, 1),
      ),
      _product(
        id: 'b',
        title: 'Engineering Uniform',
        price: 150,
        category: 'Uniforms',
        condition: 'Like New',
        storeName: 'Wildcat Threads',
        createdAt: DateTime(2026, 1, 15),
      ),
      _product(
        id: 'c',
        title: 'Scientific Calculator',
        price: 850,
        category: 'Electronics',
        condition: 'New',
        createdAt: DateTime(2026, 2, 10),
        attributes: const [
          ProductAttribute(name: 'Brand', value: 'Casio'),
        ],
      ),
    ];

List<Product> _apply(
  List<Product> items, {
  String search = '',
  String category = 'All',
  String condition = 'All',
  double? minPrice,
  double? maxPrice,
  ProductSortOption sort = ProductSortOption.recommended,
}) {
  return applyProductFilters(
    items,
    search: search,
    category: category,
    condition: condition,
    minPrice: minPrice,
    maxPrice: maxPrice,
    sort: sort,
  );
}

void main() {
  group('Search filtering & sorting pipeline', () {
    test('recommended sort keeps the natural catalog order', () {
      final result = _apply(_baseCatalog());
      expect(result.map((p) => p.id).toList(), ['a', 'b', 'c']);
    });

    test('sorts by price low-high and high-low', () {
      final low = _apply(_baseCatalog(), sort: ProductSortOption.priceLowHigh);
      expect(low.map((p) => p.id).toList(), ['b', 'a', 'c']);

      final high =
          _apply(_baseCatalog(), sort: ProductSortOption.priceHighLow);
      expect(high.map((p) => p.id).toList(), ['c', 'a', 'b']);
    });

    test('sorts by newest first', () {
      final newest = _apply(_baseCatalog(), sort: ProductSortOption.newest);
      expect(newest.map((p) => p.id).toList(), ['a', 'c', 'b']);
    });

    test('matches search across title, description, category, store and attributes',
        () {
      expect(_apply(_baseCatalog(), search: 'calculus').single.id, 'a');
      expect(_apply(_baseCatalog(), search: 'stewart').single.id, 'a');
      expect(_apply(_baseCatalog(), search: 'electronics').single.id, 'c');
      expect(_apply(_baseCatalog(), search: 'wildcat').single.id, 'b');
      expect(_apply(_baseCatalog(), search: 'casio').single.id, 'c');
    });

    test('filters by category, condition and price range together', () {
      expect(_apply(_baseCatalog(), category: 'Uniforms').single.id, 'b');

      // Condition matching is case-insensitive and exact
      expect(_apply(_baseCatalog(), condition: 'new').single.id, 'c');

      final range = _apply(_baseCatalog(), minPrice: 200, maxPrice: 900);
      expect(range.map((p) => p.id).toList(), ['a', 'c']);

      // Impossible combination yields an empty result (no fake fallback)
      expect(
        _apply(_baseCatalog(), category: 'Books', condition: 'New'),
        isEmpty,
      );
    });

    test('combines search + filters + sort in one pass', () {
      final result = _apply(
        _baseCatalog(),
        search: 'engineering',
        condition: 'Like New',
        minPrice: 100,
        maxPrice: 200,
        sort: ProductSortOption.priceHighLow,
      );
      expect(result.map((p) => p.id).toList(), ['b']);
    });
  });
}
