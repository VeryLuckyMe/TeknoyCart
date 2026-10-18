import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:teknoycart/features/reports/views/download_helper.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/utils/order_ui_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/reports/services/seller_analytics.dart';
import 'package:teknoycart/features/reports/services/sales_report_pdf.dart';

/// Financial Reports and Sales Summary dashboard matching SRS Module 7 (FR-20 / FR-21).
/// Enables sellers/vendors to track their campus merchandise sales and export reports.
class FinancialReportsView extends ConsumerStatefulWidget {
  const FinancialReportsView({super.key});

  @override
  ConsumerState<FinancialReportsView> createState() => _FinancialReportsViewState();
}

class _FinancialReportsViewState extends ConsumerState<FinancialReportsView> {
  String _selectedPeriod = 'Monthly';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'All Time'];

  // The raw fetch is hoisted out of build() so period switches and other
  // rebuilds never re-run a query; it refreshes only when the signed-in user
  // changes or via an explicit retry. Period filtering/aggregation lives in
  // computeSalesSummary and runs at render time, so the numbers always track
  // the selected period without any network round-trips.
  String? _summaryUserId;
  Future<Map<String, dynamic>>? _summaryFuture;

  /// Fetches the raw, period-independent report data for [userId].
  Future<Map<String, dynamic>> _fetchReportData(String userId) async {
    try {
      final res = await SupabaseConfig.client
          .from('orders')
          .select('''
            order_id,
            total_amount,
            quantity,
            status,
            created_at,
            product_variants (
              products (
                name,
                category_id
              )
            )
          ''')
          .eq('seller_id', userId)
          .order('created_at', ascending: false);

      final orders = <Map<String, dynamic>>[
        for (final row in res as List<dynamic>)
          if (row is Map) Map<String, dynamic>.from(row),
      ];

      // ── Seller analytics: inquiry funnel + low-stock radar ──
      var inquiries = <Map<String, dynamic>>[];
      try {
        final inqRes = await SupabaseConfig.client
            .from('inquiries')
            .select('inquiry_id, created_at, products!inner(seller_id)')
            .eq('products.seller_id', userId);
        inquiries = <Map<String, dynamic>>[
          for (final row in inqRes as List<dynamic>)
            if (row is Map) Map<String, dynamic>.from(row),
        ];
      } catch (e) {
        debugPrint('SELLER_ANALYTICS_INQUIRY_QUERY_ERROR: $e');
      }

      var products = <Map<String, dynamic>>[];
      try {
        final inventoryRes = await SupabaseConfig.client
            .from('products')
            .select(
                'name, product_variants ( variant_name, variant_value, sku, inventory ( stock_qty, low_stock_threshold ) )')
            .eq('seller_id', userId);
        products = <Map<String, dynamic>>[
          for (final row in inventoryRes as List<dynamic>)
            if (row is Map) Map<String, dynamic>.from(row),
        ];
      } catch (e) {
        debugPrint('SELLER_ANALYTICS_LOW_STOCK_QUERY_ERROR: $e');
      }

      return {
        'orders': orders,
        'inquiries': inquiries,
        'products': products,
      };
    } catch (e) {
      // Rethrow so the FutureBuilder can show an explicit error + retry state
      // instead of presenting zeroed metrics as if they were real sales data.
      debugPrint('FINANCIAL_REPORTS_QUERY_ERROR: $e');
      rethrow;
    }
  }

  /// Explicit retry — the only path that refetches without a user change.
  void _retrySummary() {
    final userId = _summaryUserId;
    if (userId == null) return;
    setState(() {
      _summaryFuture = _fetchReportData(userId);
    });
  }

  void _downloadCSVReport(Map<String, dynamic> summary) {
    try {
      final txns = summary['txns'] as List<dynamic>;
      final csvData = StringBuffer();
      csvData.writeln('Transaction ID,Item Title,Amount,Date,Status');
      for (var t in txns) {
        csvData.writeln('${t['id']},"${t['item']}",${t['amount']},${t['date']},${t['status']}');
      }
      
      downloadCsvWeb(csvData.toString(), 'teknoycart_sales_report.csv');
      Clipboard.setData(ClipboardData(text: csvData.toString()));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sales Report exported & copied to clipboard!'),
          backgroundColor: TeknoyTheme.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${e.toString()}'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
    }
  }

  /// Builds the full report PDF from the same summary the dashboard renders
  /// and hands it to the platform share/download seam.
  Future<void> _exportPdfReport(Map<String, dynamic> summary) async {
    final sellerName =
        ref.read(authStateProvider).valueOrNull?.username ?? 'Seller';
    final generatedAt = DateTime.now();
    final filename =
        'teknoycart_sales_report_${generatedAt.toIso8601String().substring(0, 10)}.pdf';
    try {
      final bytes = await buildSalesReportPdf(
        sellerName: sellerName,
        period: '$_selectedPeriod Report',
        summary: summary,
        generatedAt: generatedAt,
      );
      final delivered =
          await ref.read(salesReportPdfSharerProvider)(bytes, filename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            delivered ? 'Sales Report PDF exported!' : 'PDF export cancelled.',
          ),
          backgroundColor: delivered ? TeknoyTheme.success : null,
        ),
      );
    } catch (e) {
      debugPrint('SALES_REPORT_PDF_EXPORT_ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Couldn\'t export the PDF — please try again.'),
          backgroundColor: TeknoyTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider).valueOrNull;

    if (authState == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view reports.')),
      );
    }

    if (_summaryFuture == null || _summaryUserId != authState.id) {
      _summaryUserId = authState.id;
      _summaryFuture = _fetchReportData(authState.id);
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon)),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                'Sales Analytics',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ),
            body: SalesReportErrorState(onRetry: _retrySummary),
          );
        }

        final rawData = snapshot.data ?? const <String, dynamic>{};
        final summary = computeSalesSummary(
          orders: rawData['orders'] as List<Map<String, dynamic>>? ?? const [],
          inquiries:
              rawData['inquiries'] as List<Map<String, dynamic>>? ?? const [],
          products:
              rawData['products'] as List<Map<String, dynamic>>? ?? const [],
          period: _selectedPeriod,
        );

        final double totalRevenue = summary['revenue'] as double? ?? 0.0;
        final int completedCount = summary['count'] as int? ?? 0;
        final double books = summary['books'] as double? ?? 0.0;
        final double drawing = summary['drawing'] as double? ?? 0.0;
        final double uniforms = summary['uniforms'] as double? ?? 0.0;
        final double electronics = summary['electronics'] as double? ?? 0.0;
        final double others = summary['others'] as double? ?? 0.0;
        final txns = summary['txns'] as List<dynamic>? ?? [];

        final SalesFunnel funnel = SalesFunnel(
          inquiries: summary['inquiries'] as int? ?? 0,
          ordersPlaced: summary['ordersPlaced'] as int? ?? 0,
          confirmed: completedCount,
        );
        final List<TopProductStat> topProducts =
            (summary['topProducts'] as List<dynamic>?)
                    ?.whereType<TopProductStat>()
                    .toList() ??
                const <TopProductStat>[];
        final List<LowStockAlert> lowStockAlerts =
            (summary['lowStock'] as List<dynamic>?)
                    ?.whereType<LowStockAlert>()
                    .toList() ??
                const <LowStockAlert>[];

        final double maxCatRev = [books, drawing, uniforms, electronics, others].reduce((a, b) => a > b ? a : b);
        final double booksPercent = maxCatRev > 0 ? books / maxCatRev : 0.0;
        final double drawingPercent = maxCatRev > 0 ? drawing / maxCatRev : 0.0;
        final double uniformsPercent = maxCatRev > 0 ? uniforms / maxCatRev : 0.0;
        final double electronicsPercent = maxCatRev > 0 ? electronics / maxCatRev : 0.0;
        final double othersPercent = maxCatRev > 0 ? others / maxCatRev : 0.0;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Sales Analytics',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.share_outlined),
                onSelected: (format) {
                  if (format == 'CSV') {
                    _downloadCSVReport(summary);
                  } else {
                    _exportPdfReport(summary);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'PDF',
                    child: Row(
                      children: [
                        Icon(Icons.picture_as_pdf_outlined, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Export as PDF'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'CSV',
                    child: Row(
                      children: [
                        Icon(Icons.grid_on_outlined, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('Export as CSV'),
                      ],
                    ),
                  ),
                ],
              )
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sales Summary',
                      style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: _selectedPeriod,
                      underline: const SizedBox(),
                      items: _periods.map((p) {
                        return DropdownMenuItem(
                          value: p,
                          child: Text('$p Report', style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: TeknoyTheme.citMaroon)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedPeriod = val);
                        }
                      },
                    )
                  ],
                ),
                const SizedBox(height: 12),

                // Sales Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Total Revenue',
                        value: '₱${totalRevenue.toStringAsFixed(2)}',
                        icon: Icons.payments_rounded,
                        color: TeknoyTheme.citMaroon,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'Transactions',
                        value: '$completedCount Completed',
                        icon: Icons.assignment_turned_in_rounded,
                        color: TeknoyTheme.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Conversion funnel: inquiries -> orders -> confirmed sales
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Conversion Funnel',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Inquiry → Order ${(funnel.inquiryToOrderRate * 100).toStringAsFixed(0)}%  •  Order → Confirmed ${(funnel.orderToConfirmRate * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildFunnelStage(
                              label: 'Inquiries',
                              value: funnel.inquiries,
                              icon: Icons.forum_outlined,
                              color: Colors.blue,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                            ),
                            _buildFunnelStage(
                              label: 'Orders Placed',
                              value: funnel.ordersPlaced,
                              icon: Icons.receipt_long_outlined,
                              color: TeknoyTheme.citGold,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                            ),
                            _buildFunnelStage(
                              label: 'Confirmed',
                              value: funnel.confirmed,
                              icon: Icons.verified_rounded,
                              color: TeknoyTheme.success,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Revenue breakdown by Category Chart
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Revenue by Category',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (uniforms > 0) ...[
                          _buildChartRow('Uniforms', '₱${uniforms.toStringAsFixed(2)}', uniformsPercent, TeknoyTheme.citMaroon),
                          const SizedBox(height: 12),
                        ],
                        if (drawing > 0) ...[
                          _buildChartRow('Drawing Tools', '₱${drawing.toStringAsFixed(2)}', drawingPercent, TeknoyTheme.citGold),
                          const SizedBox(height: 12),
                        ],
                        if (books > 0) ...[
                          _buildChartRow('Books', '₱${books.toStringAsFixed(2)}', booksPercent, Colors.blue),
                          const SizedBox(height: 12),
                        ],
                        if (electronics > 0) ...[
                          _buildChartRow('Electronics', '₱${electronics.toStringAsFixed(2)}', electronicsPercent, Colors.orange),
                          const SizedBox(height: 12),
                        ],
                        if (others > 0) ...[
                          _buildChartRow('Others', '₱${others.toStringAsFixed(2)}', othersPercent, Colors.purple),
                        ],
                        if (totalRevenue == 0)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.0),
                              child: Text('No verified sales revenues recorded yet.', style: TextStyle(fontFamily: 'Inter', color: Colors.grey, fontSize: 13)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Top products by confirmed revenue
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top Products',
                          style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        if (topProducts.isEmpty)
                          _buildEmptyHint('No confirmed sales yet — top sellers appear after your first completed order.')
                        else
                          ...List.generate(topProducts.length, (index) {
                            final product = topProducts[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: index == 0
                                          ? TeknoyTheme.citGold.withValues(alpha: 0.2)
                                          : Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: index == 0 ? TeknoyTheme.citMaroon : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          '${product.orders} order${product.orders == 1 ? '' : 's'} • ${product.units} unit${product.units == 1 ? '' : 's'} sold',
                                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₱${product.revenue.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: TeknoyTheme.citMaroon,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Low stock radar across the seller's listings
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.inventory_2_rounded,
                              size: 17,
                              color: lowStockAlerts.isEmpty ? TeknoyTheme.success : Colors.orange.shade700,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Low Stock Alerts',
                              style: TextStyle(fontFamily: 'Outfit', fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (lowStockAlerts.isEmpty)
                          _buildEmptyHint('All listings are above their low-stock thresholds.')
                        else
                          ...lowStockAlerts.map((alert) {
                            final isOut = alert.stockQty == 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Icon(
                                    isOut ? Icons.error_rounded : Icons.warning_amber_rounded,
                                    size: 18,
                                    color: isOut ? TeknoyTheme.error : Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          alert.productName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        Text(
                                          alert.variantLabel.isEmpty
                                              ? 'SKU: ${alert.sku}'
                                              : '${alert.variantLabel} • SKU: ${alert.sku}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isOut ? TeknoyTheme.error : Colors.orange).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isOut ? 'Out of stock' : '${alert.stockQty} left',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isOut ? TeknoyTheme.error : Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Chronological Transaction Log
                const Text(
                  'Completed Transactions Log',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (txns.isEmpty)
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'No transaction logs compiled yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Inter', color: Colors.grey),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (final txn in txns) _buildTransactionCard(txn),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(dynamic txn) {
    final isCompleted = txn['status'] == 'COMPLETED';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.green.shade50 : Colors.blue.shade50,
          child: Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
            color: isCompleted ? Colors.green : Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          txn['item'],
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'Date: ${OrderUiHelper.formatDate(txn['date'])}  |  Status: ${OrderUiHelper.formatStatus(txn['status'])}',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey),
        ),
        trailing: Text(
          '₱${txn['amount'].toStringAsFixed(2)}',
          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: TeknoyTheme.citMaroon),
        ),
      ),
    );
  }

  Widget _buildFunnelStage({
    required String label,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHint(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Inter', color: Colors.grey, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildMetricCard({required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 12),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartRow(String label, String value, double percent, Color barColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
            Text(value, style: const TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 8,
            color: Colors.grey.shade200,
            child: Row(
              children: [
                Expanded(
                  flex: (percent * 100).toInt(),
                  child: Container(color: barColor),
                ),
                Expanded(
                  flex: ((1.0 - percent) * 100).toInt(),
                  child: const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Error state for the Sales Analytics dashboard. Shown when the orders
/// query fails so sellers see an explicit failure + retry affordance
/// instead of silently zeroed metrics presented as real data.
class SalesReportErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const SalesReportErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: TeknoyTheme.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color: TeknoyTheme.error,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Couldn\'t load sales analytics',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your records are safe — this screen just couldn\'t reach the server. Check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
