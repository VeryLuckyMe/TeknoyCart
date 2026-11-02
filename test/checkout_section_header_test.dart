import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/checkout/views/widgets/checkout_section_header.dart';

void main() {
  group('CheckoutSectionHeader Widget Tests', () {
    testWidgets('renders title, icon, and optional subtitle correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CheckoutSectionHeader(
              icon: Icons.local_shipping,
              title: 'Meetup Location',
              subtitle: 'Select an official campus pickup zone',
            ),
          ),
        ),
      );

      expect(find.text('Meetup Location'), findsOneWidget);
      expect(find.text('Select an official campus pickup zone'), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping), findsOneWidget);
    });

    testWidgets('adapts smoothly to dark mode without subtitle', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: CheckoutSectionHeader(
              icon: Icons.payment,
              title: 'Payment Details',
              isDark: true,
            ),
          ),
        ),
      );

      expect(find.text('Payment Details'), findsOneWidget);
      expect(find.byIcon(Icons.payment), findsOneWidget);
    });

    testWidgets('omits the subtitle when it is not provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CheckoutSectionHeader(
              icon: Icons.location_on,
              title: 'Pickup',
            ),
          ),
        ),
      );

      expect(find.text('Pickup'), findsOneWidget);
      expect(find.text('Select an official campus pickup zone'), findsNothing);
    });
  });
}
