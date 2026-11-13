import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/providers/seller_type_provider.dart';
import 'package:teknoycart/features/feed/views/widgets/product_purchase_bar.dart';

Widget _bar({required bool showMakeOffer}) => MaterialApp(
      home: Scaffold(
        body: ProductPurchaseBar(
          isDark: false,
          cartCount: 0,
          isInitializingChat: false,
          availableStock: 5,
          isPreorderEnabled: false,
          isLoadingInventory: false,
          onChatPressed: () {},
          onAddToCartPressed: () {},
          onMakeOfferPressed: () {},
          onBuyNowPressed: () {},
          showMakeOffer: showMakeOffer,
        ),
      ),
    );

void main() {
  group('sellerAcceptsPriceOffers', () {
    test('organisation / official stores do not accept haggling', () {
      expect(sellerAcceptsPriceOffers('ORG'), isFalse);
      expect(sellerAcceptsPriceOffers('org'), isFalse);
    });

    test('student sellers and unknown types accept offers', () {
      expect(sellerAcceptsPriceOffers('STUDENT'), isTrue);
      expect(sellerAcceptsPriceOffers(null), isTrue);
    });
  });

  group('ProductPurchaseBar', () {
    testWidgets('shows Make Offer for student sellers', (tester) async {
      await tester.pumpWidget(_bar(showMakeOffer: true));
      expect(find.text('Make Offer'), findsOneWidget);
      expect(find.text('Buy Now'), findsOneWidget);
    });

    testWidgets('hides Make Offer for official / org stores', (tester) async {
      await tester.pumpWidget(_bar(showMakeOffer: false));
      expect(find.text('Make Offer'), findsNothing);
      expect(find.text('Buy Now'), findsOneWidget);
    });
  });
}
