import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/features/chat/services/chat_service.dart';
import 'package:teknoycart/features/chat/views/widgets/chat_negotiation_banner.dart';

void main() {
  group('Stock edit routing', () {
    test('categories without a multi-select template use single stock', () {
      const books = [
        CategoryAttributeTemplate(
          name: 'Subject',
          type: 'text',
          placeholder: 'e.g. Calculus',
        ),
        CategoryAttributeTemplate(
          name: 'Author',
          type: 'text',
          placeholder: 'e.g. James Stewart',
        ),
      ];

      expect(categoryUsesVariantMatrix(books), isFalse);
      expect(categoryUsesVariantMatrix(const []), isFalse);
    });

    test('categories with a multi-select template use the variant matrix', () {
      const clothes = [
        CategoryAttributeTemplate(
          name: 'Size',
          type: 'select',
          placeholder: 'Select size(s)',
          options: ['S', 'M', 'L'],
          isMultiSelect: true,
        ),
      ];

      expect(categoryUsesVariantMatrix(clothes), isTrue);
    });
  });

  group('Offer availability', () {
    test('no variant rows means availability is unknown', () {
      expect(ChatService.availableStockFromVariants(const []), isNull);
    });

    test('subtracts reservations from stock', () {
      final rows = [
        {
          'inventory': [
            {'stock_qty': 4, 'reserved_qty': 1},
          ],
        },
      ];
      expect(ChatService.availableStockFromVariants(rows), 3);
    });

    test('treats a zero-stock variant as sold out', () {
      final rows = [
        {
          'inventory': {'stock_qty': 0, 'reserved_qty': 0},
        },
      ];
      expect(ChatService.availableStockFromVariants(rows), 0);
    });

    test('sums sellable units across variants and clamps negatives', () {
      final rows = [
        {
          'inventory': [
            {'stock_qty': 2, 'reserved_qty': 0},
          ],
        },
        {
          'inventory': {'stock_qty': 1, 'reserved_qty': 5},
        },
        {
          'inventory': {'stock_qty': 3, 'reserved_qty': 0},
        },
      ];
      expect(ChatService.availableStockFromVariants(rows), 5);
    });

    test('missing inventory rows count as zero sellable units', () {
      final rows = [
        {'inventory': null},
        {'inventory': <Map<String, dynamic>>[]},
      ];
      expect(ChatService.availableStockFromVariants(rows), 0);
    });
  });

  group('Chat negotiation banner', () {
    Widget banner({required bool canOffer}) {
      return MaterialApp(
        home: Scaffold(
          body: ChatNegotiationBanner(
            activeState: 'none',
            activeOfferPrice: 0,
            askingPrice: 100,
            isBuyer: true,
            canOffer: canOffer,
            onOfferPrice: () {},
            onCheckout: () {},
          ),
        ),
      );
    }

    testWidgets('offers are hidden when the listing is sold out', (tester) async {
      await tester.pumpWidget(banner(canOffer: false));

      expect(find.text('Offer Price'), findsNothing);
      expect(find.text('Out of Stock'), findsOneWidget);
    });

    testWidgets('offers stay available when stock exists', (tester) async {
      await tester.pumpWidget(banner(canOffer: true));

      expect(find.text('Offer Price'), findsOneWidget);
      expect(find.text('Out of Stock'), findsNothing);
    });
  });
}
