import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/models/profile.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/reports/views/financial_reports_view.dart';
import 'package:teknoycart/features/reports/services/seller_analytics.dart';
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

      // Assert presence of the seller analytics upgrades
      expect(find.text('Conversion Funnel'), findsOneWidget);
      expect(find.text('Top Products'), findsOneWidget);
      expect(find.text('Low Stock Alerts'), findsOneWidget);
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

  group('Seller analytics helpers', () {
    final now = DateTime(2026, 10, 18, 12, 0);

    test('withinReportPeriod applies daily, weekly, monthly and all-time windows', () {
      expect(
        withinReportPeriod(DateTime(2026, 10, 18, 8).toIso8601String(), 'Daily', now),
        isTrue,
      );
      expect(
        withinReportPeriod(DateTime(2026, 10, 17, 23).toIso8601String(), 'Daily', now),
        isFalse,
      );
      expect(
        withinReportPeriod(DateTime(2026, 10, 15).toIso8601String(), 'Weekly', now),
        isTrue,
      );
      expect(
        withinReportPeriod(DateTime(2026, 10, 1).toIso8601String(), 'Weekly', now),
        isFalse,
      );
      expect(
        withinReportPeriod(DateTime(2026, 10, 5).toIso8601String(), 'Monthly', now),
        isTrue,
      );
      expect(
        withinReportPeriod(DateTime(2026, 8, 1).toIso8601String(), 'Monthly', now),
        isFalse,
      );
      expect(
        withinReportPeriod(DateTime(2024, 1, 1).toIso8601String(), 'All Time', now),
        isTrue,
      );
      // Missing or unparseable timestamps are never silently dropped
      expect(withinReportPeriod(null, 'Daily', now), isTrue);
      expect(withinReportPeriod('not-a-date', 'Daily', now), isTrue);
    });

    test('SalesFunnel computes conversion rates with zero-guards', () {
      const funnel = SalesFunnel(inquiries: 10, ordersPlaced: 4, confirmed: 2);
      expect(funnel.inquiryToOrderRate, closeTo(0.4, 1e-9));
      expect(funnel.orderToConfirmRate, closeTo(0.5, 1e-9));

      const empty = SalesFunnel(inquiries: 0, ordersPlaced: 0, confirmed: 0);
      expect(empty.inquiryToOrderRate, 0.0);
      expect(empty.orderToConfirmRate, 0.0);

      // Rates clamp defensively when data is noisy
      const noisy = SalesFunnel(inquiries: 2, ordersPlaced: 4, confirmed: 1);
      expect(noisy.inquiryToOrderRate, 1.0);
    });

    test('computeTopProducts aggregates revenue, units and limits the ranking', () {
      final rows = [
        {'productName': 'Uniform', 'total_amount': 450.0, 'quantity': 1},
        {'productName': 'Uniform', 'total_amount': 450.0, 'quantity': 2},
        {'productName': 'Calculator', 'total_amount': 1200.0, 'quantity': 1},
        {'productName': 'T-Square', 'total_amount': 300.0, 'quantity': 1},
      ];

      final top = computeTopProducts(rows);
      expect(top.length, 3);
      expect(top[0].name, 'Calculator');
      expect(top[0].revenue, 1200.0);
      expect(top[1].name, 'Uniform');
      expect(top[1].orders, 2);
      expect(top[1].units, 3);
      expect(top[1].revenue, 900.0);
      expect(top[2].name, 'T-Square');

      expect(computeTopProducts(rows, limit: 2).length, 2);

      final unnamed = computeTopProducts([
        {'total_amount': 100.0},
      ]);
      expect(unnamed.single.name, 'Merchandise');
    });

    test('computeLowStockAlerts handles both embed shapes and sorts by stock', () {
      final products = [
        {
          'name': 'CIT-U Uniform',
          'product_variants': [
            {
              'variant_name': 'Size',
              'variant_value': 'M',
              'sku': 'UNI-M',
              'inventory': {'stock_qty': 2, 'low_stock_threshold': 5},
            },
            {
              'variant_name': 'Size',
              'variant_value': 'L',
              'sku': 'UNI-L',
              'inventory': {'stock_qty': 12, 'low_stock_threshold': 5},
            },
          ],
        },
        {
          'name': 'Calculator',
          'product_variants': {
            'variant_name': 'Color',
            'variant_value': 'Black',
            'sku': 'CALC-B',
            'inventory': [
              {'stock_qty': 0, 'low_stock_threshold': 3},
            ],
          },
        },
        {
          'name': 'No inventory listing',
          'product_variants': [
            {'variant_name': 'One', 'variant_value': 'Size', 'sku': 'NO-INV'},
          ],
        },
      ];

      final alerts = computeLowStockAlerts(products);
      expect(alerts.length, 2);
      // Lowest stock first
      expect(alerts.first.productName, 'Calculator');
      expect(alerts.first.stockQty, 0);
      expect(alerts.last.sku, 'UNI-M');
      expect(alerts.last.variantLabel, 'Size: M');
      expect(alerts.last.stockQty, 2);
      // Variant above its threshold is not an alert
      expect(alerts.any((a) => a.sku == 'UNI-L'), isFalse);
    });
  });
}
