import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/providers/seller_type_provider.dart';
import 'package:teknoycart/features/feed/views/widgets/product_purchase_bar.dart';

Widget _bar({required bool showMakeOffer, bool isOwnListing = false, VoidCallback? onManage}) => MaterialApp(
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
          isOwnListing: isOwnListing,
          onManageListingPressed: onManage,
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

  group('ProductPurchaseBar on own listing', () {
    testWidgets('hides every buyer action and shows the seller bar', (tester) async {
      var managed = 0;
      await tester.pumpWidget(_bar(showMakeOffer: true, isOwnListing: true, onManage: () => managed++));
      expect(find.text('This is your listing'), findsOneWidget);
      expect(find.text('Buy Now'), findsNothing);
      expect(find.text('Make Offer'), findsNothing);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
      await tester.tap(find.text('Manage Listing'));
      expect(managed, 1);
    });
  });
}
