import 'dart:convert';
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
import 'package:teknoycart/features/reports/services/sales_report_pdf.dart';
import 'mock_http_client.dart';

void main() {
  setUpAll(() async {
    HttpOverrides.global = _countingHttpOverrides;
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

    testWidgets('switching the report period reuses the hoisted analytics future (no refetch)', (WidgetTester tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sales Summary'), findsOneWidget);
      final requestsAfterLoad = _countingHttpOverrides.requestCount;
      expect(requestsAfterLoad, greaterThan(0), reason: 'the initial load must fetch analytics');

      await tester.tap(find.text('Monthly Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Weekly Report').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        _countingHttpOverrides.requestCount,
        requestsAfterLoad,
        reason: 'switching the reporting period must not re-run network queries',
      );
      expect(find.text('Sales Summary'), findsOneWidget);
      expect(find.text('Weekly Report'), findsOneWidget);
    });

    testWidgets('switching the report period re-filters the displayed metrics client-side',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      // The Supabase test client caches its HttpClient for the whole file, so
      // re-target the shared mock's body instead of swapping the global
      // override (a cached client would ignore the new override).
      _countingHttpOverrides.supabaseBody = jsonEncode([
        {
          'order_id': 'aaaa1111-recent',
          'total_amount': '450.00',
          'quantity': 1,
          'status': 'COMPLETED',
          'created_at':
              now.subtract(const Duration(hours: 2)).toIso8601String(),
          'product_variants': {
            'products': {'name': 'CIT-U Uniform', 'category_id': 3},
          },
        },
        {
          'order_id': 'bbbb2222-old',
          'total_amount': '300.00',
          'quantity': 1,
          'status': 'COMPLETED',
          'created_at':
              now.subtract(const Duration(days: 60)).toIso8601String(),
          'product_variants': {
            'products': {'name': 'T-Square', 'category_id': 2},
          },
        },
      ]);
      addTearDown(() => _countingHttpOverrides.supabaseBody = null);

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Default period is Monthly — the 60-day-old order is out of the window
      expect(find.text('₱450.00'), findsWidgets);
      expect(find.text('₱750.00'), findsNothing);
      expect(find.text('₱300.00'), findsNothing);
      final requestsBeforeSwitch = _countingHttpOverrides.requestCount;

      await tester.tap(find.text('Monthly Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('All Time Report').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // All Time must now include the older order — with no refetch
      expect(find.text('₱750.00'), findsOneWidget);
      expect(find.text('₱300.00'), findsWidgets);
      expect(find.text('All Time Report'), findsOneWidget);
      expect(_countingHttpOverrides.requestCount, requestsBeforeSwitch);
    });

    testWidgets('SalesReportErrorState surfaces failure copy and wires the retry action', (WidgetTester tester) async {
      var retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesReportErrorState(onRetry: () => retried = true),
          ),
        ),
      );

      // Honest failure messaging instead of zeroed metrics presented as data
      expect(find.text('Couldn\'t load sales analytics'), findsOneWidget);
      expect(find.textContaining('couldn\'t reach the server'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
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

  group('Sales report PDF export', () {
    late Profile mockSeller;

    setUp(() {
      mockSeller = Profile(
        id: 'seller-abc-123',
        username: 'wildcat_vendor',
        email: 'seller@cit.edu',
        createdAt: DateTime.now(),
      );
    });

    Map<String, dynamic> fullSummary() => {
          'revenue': 1250.00,
          'count': 3,
          'books': 800.00,
          'drawing': 300.00,
          'uniforms': 450.00,
          'electronics': 0.0,
          'others': 0.0,
          'inquiries': 12,
          'ordersPlaced': 5,
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
          ],
          'topProducts': [
            const TopProductStat(
              name: 'CIT-U Uniform',
              orders: 2,
              units: 3,
              revenue: 900.0,
            ),
          ],
          'lowStock': [
            const LowStockAlert(
              productName: 'CIT-U Uniform',
              variantLabel: 'Size: S',
              sku: 'UNI-S',
              stockQty: 1,
              threshold: 5,
            ),
          ],
        };

    test('buildSalesReportPdf emits a real PDF document', () async {
      final bytes = await buildSalesReportPdf(
        sellerName: 'wildcat_vendor',
        period: 'Monthly Report',
        summary: fullSummary(),
        generatedAt: DateTime(2026, 10, 19, 14, 5),
      );

      expect(bytes.length, greaterThan(1500));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('generator survives empty data and non-Latin listing names', () async {
      final empty = await buildSalesReportPdf(
        sellerName: '',
        period: 'All Time Report',
        summary: const <String, dynamic>{},
        generatedAt: DateTime(2026, 10, 19),
      );
      expect(String.fromCharCodes(empty.take(5)), '%PDF-');

      // PDF base fonts are Latin-1 only — emoji/CJK must be replaced, not crash
      final exotic = await buildSalesReportPdf(
        sellerName: 'Núñez 📚',
        period: 'Daily Report',
        summary: {
          'revenue': 99.5,
          'count': 1,
          'txns': [
            {
              'id': 'TXN-0001',
              'item': 'Reviewer 復習会 📖',
              'amount': 99.5,
              'date': '2026-10-19',
              'status': 'PAYMENT_VERIFIED',
            },
          ],
          'topProducts': [
            const TopProductStat(
              name: '📘 Reviewer',
              orders: 1,
              units: 1,
              revenue: 99.5,
            ),
          ],
          'lowStock': [
            const LowStockAlert(
              productName: '復習 Book',
              variantLabel: 'Edition: 2nd',
              sku: 'RVW-2',
              stockQty: 0,
              threshold: 3,
            ),
          ],
        },
        generatedAt: DateTime(2026, 10, 19),
      );
      expect(String.fromCharCodes(exotic.take(5)), '%PDF-');
    });

    test('formatters keep money and statuses human-readable in the PDF', () {
      expect(formatPdfMoney(1234.5), 'PHP 1,234.50');
      expect(formatPdfMoney(0), 'PHP 0.00');
      expect(formatPdfMoney(999999.99), 'PHP 999,999.99');
      expect(formatPdfMoney(-12.3), 'PHP -12.30');
      expect(humanizeOrderStatus('PAYMENT_VERIFIED'), 'Payment Verified');
      expect(humanizeOrderStatus('COMPLETED'), 'Completed');
      expect(humanizeOrderStatus(''), '');
    });

    testWidgets('export menu builds the PDF and delivers it through the sharer seam',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Uint8List? capturedBytes;
      String? capturedFilename;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith((ref) => AsyncValue.data(mockSeller)),
            salesReportPdfSharerProvider
                .overrideWithValue((bytes, filename) async {
              capturedBytes = bytes;
              capturedFilename = filename;
              return true;
            }),
          ],
          child: const MaterialApp(
            home: FinancialReportsView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Export as PDF'), findsOneWidget);
      expect(find.textContaining('coming soon'), findsNothing);

      await tester.tap(find.text('Export as PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(capturedBytes, isNotNull);
      expect(String.fromCharCodes(capturedBytes!.take(5)), '%PDF-');
      expect(
        capturedFilename,
        matches(RegExp(r'^teknoycart_sales_report_\d{4}-\d{2}-\d{2}\.pdf$')),
      );
      expect(find.text('Sales Report PDF exported!'), findsOneWidget);
    });

    testWidgets('sharer failures surface honest copy instead of fake success',
        (WidgetTester tester) async {
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
            salesReportPdfSharerProvider
                .overrideWithValue((bytes, filename) async {
              throw Exception('share channel unavailable');
            }),
          ],
          child: const MaterialApp(
            home: FinancialReportsView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.share_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export as PDF'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.text('Couldn\'t export the PDF — please try again.'),
        findsOneWidget,
      );
      expect(find.text('Sales Report PDF exported!'), findsNothing);
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

    test('computeSalesSummary re-filters revenue, categories, txns and the funnel by period', () {
      final now = DateTime(2026, 10, 19, 12, 0);
      Map<String, dynamic> order({
        required String id,
        required double amount,
        required String status,
        required DateTime createdAt,
        int categoryId = 3,
      }) =>
          {
            'order_id': id,
            'total_amount': amount.toString(),
            'quantity': 1,
            'status': status,
            'created_at': createdAt.toIso8601String(),
            'product_variants': {
              'products': {'name': 'Item $id', 'category_id': categoryId},
            },
          };

      final orders = [
        order(
          id: 'aaaa1111',
          amount: 450.0,
          status: 'COMPLETED',
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
        order(
          id: 'bbbb2222',
          amount: 300.0,
          status: 'COMPLETED',
          createdAt: now.subtract(const Duration(days: 60)),
          categoryId: 2,
        ),
        order(
          id: 'cccc3333',
          amount: 999.0,
          status: 'CANCELLED',
          createdAt: now.subtract(const Duration(days: 60)),
        ),
        order(
          id: 'dddd4444',
          amount: 100.0,
          status: 'PENDING',
          createdAt: now.subtract(const Duration(hours: 1)),
        ),
      ];
      final inquiries = [
        {'created_at': now.subtract(const Duration(hours: 1)).toIso8601String()},
        {'created_at': now.subtract(const Duration(days: 60)).toIso8601String()},
      ];

      final monthly = computeSalesSummary(
        orders: orders,
        inquiries: inquiries,
        products: const [],
        period: 'Monthly',
        now: now,
      );
      expect(monthly['revenue'], 450.0);
      expect(monthly['count'], 1);
      expect(monthly['txns'], hasLength(2)); // today's completed + pending
      expect(monthly['ordersPlaced'], 2);
      expect(monthly['inquiries'], 1);
      expect(monthly['uniforms'], 450.0); // categoryId 3
      expect(monthly['drawing'], 0.0); // 60-day-old order out of window
      expect(
        (monthly['topProducts'] as List<TopProductStat>).single.revenue,
        450.0,
      );

      final allTime = computeSalesSummary(
        orders: orders,
        inquiries: inquiries,
        products: const [],
        period: 'All Time',
        now: now,
      );
      expect(allTime['revenue'], 750.0);
      expect(allTime['count'], 2);
      expect(allTime['txns'], hasLength(4));
      expect(allTime['ordersPlaced'], 3); // cancelled order never counts
      expect(allTime['inquiries'], 2);
      expect(allTime['uniforms'], 450.0);
      expect(allTime['drawing'], 300.0); // categoryId 2
      expect(allTime['topProducts'] as List<TopProductStat>, hasLength(2));
    });
  });
}

/// Counts every Supabase HTTP request made during a test so screens can be
/// held to "fetch once, reuse until retry" behavior.
final _countingHttpOverrides = _CountingHttpOverrides();

class _CountingHttpOverrides extends MockHttpOverrides {
  int requestCount = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _CountingHttpClient(
      super.createHttpClient(context),
      () => requestCount++,
    );
  }
}

class _CountingHttpClient implements HttpClient {
  _CountingHttpClient(this._inner, this._onRequest);

  final HttpClient _inner;
  final void Function() _onRequest;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    _onRequest();
    return _inner.openUrl(method, url);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    _onRequest();
    return _inner.getUrl(url);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
