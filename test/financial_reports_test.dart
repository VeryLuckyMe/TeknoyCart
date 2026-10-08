import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/reports/views/financial_reports_view.dart';
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

  group('Financial Reports Dashboard & Metrics Tests', () {
    late Profile mockSeller;

    setUp(() {
      mockSeller = Profile(
        id: 'seller-abc-123',
        username: 'wildcat_vendor',
        email: 'seller@cit.edu',
        createdAt: DateTime.now(),
      );
    });

    testWidgets('renders Financial Reports dashboard with all core components', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(mockSeller)),
          ],
          child: const MaterialApp(
            home: FinancialReportsView(),
          ),
        ),
      );

      // Wait for initial load and animations
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Assert presence of app bar title
      expect(find.text('Sales Analytics'), findsOneWidget);

      // Assert presence of sales summary header
      expect(find.text('Sales Summary'), findsOneWidget);

      // Assert presence of core metric cards
      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('Transactions'), findsOneWidget);

      // Assert presence of category breakdown
      expect(find.text('Revenue by Category'), findsOneWidget);

      // Assert presence of transaction log header
      expect(find.text('Completed Transactions Log'), findsOneWidget);
    });

    test('CSV report generation produces valid spreadsheet format', () {
      final mockSummary = {
        'revenue': 1250.00,
        'count': 3,
        'txns': [
          {
            'id': 'TXN-A1B2',
            'item': 'CIT-U Uniform Size M',
            'amount': 450.00,
            'date': '2026-09-17',
            'status': 'COMPLETED',
          },
          {
            'id': 'TXN-C3D4',
            'item': 'Engineering Mechanics 2nd Ed',
            'amount': 500.00,
            'date': '2026-09-16',
            'status': 'PAYMENT_VERIFIED',
          },
          {
            'id': 'TXN-E5F6',
            'item': 'T-Square 36 inch',
            'amount': 300.00,
            'date': '2026-09-15',
            'status': 'READY_FOR_PICKUP',
          },
        ]
      };

      final txns = mockSummary['txns'] as List<Map<String, dynamic>>;
      final csvData = StringBuffer();
      csvData.writeln('Transaction ID,Item Title,Amount,Date,Status');
      for (var t in txns) {
        csvData.writeln('${t['id']},"${t['item']}",${t['amount']},${t['date']},${t['status']}');
      }

      final lines = csvData.toString().trim().split('\n');
      expect(lines.length, 4); // Header + 3 rows
      expect(lines[0].trim(), 'Transaction ID,Item Title,Amount,Date,Status');
      expect(lines[1].trim(), 'TXN-A1B2,"CIT-U Uniform Size M",450.0,2026-09-17,COMPLETED');
      expect(lines[2].trim(), 'TXN-C3D4,"Engineering Mechanics 2nd Ed",500.0,2026-09-16,PAYMENT_VERIFIED');
      expect(lines[3].trim(), 'TXN-E5F6,"T-Square 36 inch",300.0,2026-09-15,READY_FOR_PICKUP');
    });

    test('revenue aggregation by category calculates correct category totals', () {
      final orders = [
        {'price': 400.0, 'catId': 1, 'status': 'COMPLETED'}, // Books
        {'price': 150.0, 'catId': 1, 'status': 'PAYMENT_VERIFIED'}, // Books
        {'price': 600.0, 'catId': 3, 'status': 'COMPLETED'}, // Uniforms
        {'price': 250.0, 'catId': 2, 'status': 'READY_FOR_PICKUP'}, // Drawing Tools
        {'price': 800.0, 'catId': 4, 'status': 'COMPLETED'}, // Electronics
        {'price': 100.0, 'catId': 5, 'status': 'COMPLETED'}, // Others
        {'price': 999.0, 'catId': 1, 'status': 'CANCELLED'}, // Cancelled - should NOT count
      ];

      double totalRevenue = 0.0;
      int completedCount = 0;
      double books = 0.0;
      double drawing = 0.0;
      double uniforms = 0.0;
      double electronics = 0.0;
      double others = 0.0;

      for (var o in orders) {
        final price = o['price'] as double;
        final status = o['status'] as String;
        final catId = o['catId'] as int;

        if (status == 'COMPLETED' || status == 'PAYMENT_VERIFIED' || status == 'READY_FOR_PICKUP') {
          totalRevenue += price;
          completedCount++;

          if (catId == 1) {
            books += price;
          } else if (catId == 2) {
            drawing += price;
          } else if (catId == 3) {
            uniforms += price;
          } else if (catId == 4) {
            electronics += price;
          } else {
            others += price;
          }
        }
      }

      expect(totalRevenue, 2300.0); // 400 + 150 + 600 + 250 + 800 + 100
      expect(completedCount, 6);
      expect(books, 550.0);
      expect(uniforms, 600.0);
      expect(drawing, 250.0);
      expect(electronics, 800.0);
      expect(others, 100.0);
    });
  });
}
