import 'package:flutter/material.dart';
import 'package:teknoycart/features/reports/views/download_helper.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';

/// Financial Reports and Sales Summary dashboard matching SRS Module 7 (FR-20 / FR-21).
/// Enables sellers/vendors to track their campus merchandise sales and export reports.
class FinancialReportsView extends ConsumerStatefulWidget {
  const FinancialReportsView({super.key});

  @override
  ConsumerState<FinancialReportsView> createState() => _FinancialReportsViewState();
}

class _FinancialReportsViewState extends ConsumerState<FinancialReportsView> {
  String _selectedPeriod = 'Monthly';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly'];

  Future<Map<String, dynamic>> _getFinancialSummary(String userId) async {
    try {
      final res = await SupabaseConfig.client
          .from('orders')
          .select('''
            order_id,
            negotiated_price,
            status,
            created_at,
            products (
              name,
              category_id,
              seller_id
            )
          ''')
          .eq('products.seller_id', userId);

      final List<dynamic> orders = res as List<dynamic>;

      double totalRevenue = 0.0;
      int completedTransactions = 0;
      double uniformsRevenue = 0.0;
      double booksRevenue = 0.0;
      double drawingRevenue = 0.0;
      double electronicsRevenue = 0.0;
      double othersRevenue = 0.0;

      final List<Map<String, dynamic>> txns = [];

      for (var o in orders) {
        final double price = double.tryParse(o['negotiated_price'].toString()) ?? 0;
        final product = o['products'] as Map<String, dynamic>?;
        if (product == null) continue;

        final status = o['status'] as String? ?? '';
        final catId = product['category_id'] as int? ?? 5;
        
        if (status == 'COMPLETED' || status == 'PAYMENT_VERIFIED' || status == 'READY_FOR_PICKUP') {
          totalRevenue += price;
          completedTransactions++;

          if (catId == 1) booksRevenue += price;
          else if (catId == 2) drawingRevenue += price;
          else if (catId == 3) uniformsRevenue += price;
          else if (catId == 4) electronicsRevenue += price;
          else othersRevenue += price;
        }

        txns.add({
          'id': 'TXN-${o['order_id'].toString().substring(0, 4).toUpperCase()}',
          'item': product['name'] ?? 'Merchandise',
          'amount': price,
          'date': o['created_at'].toString().substring(0, 10),
          'status': status,
        });
      }

      return {
        'revenue': totalRevenue,
        'count': completedTransactions,
        'books': booksRevenue,
        'drawing': drawingRevenue,
        'uniforms': uniformsRevenue,
        'electronics': electronicsRevenue,
        'others': othersRevenue,
        'txns': txns,
      };
    } catch (e) {
      return {
        'revenue': 0.0,
        'count': 0,
        'books': 0.0,
        'drawing': 0.0,
        'uniforms': 0.0,
        'electronics': 0.0,
        'others': 0.0,
        'txns': [],
      };
    }
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Sales Report exported as CSV successfully!'),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider).valueOrNull;

    if (authState == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view reports.')),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _getFinancialSummary(authState.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon)),
          );
        }

        final summary = snapshot.data ?? {
          'revenue': 0.0,
          'count': 0,
          'books': 0.0,
          'drawing': 0.0,
          'uniforms': 0.0,
          'electronics': 0.0,
          'others': 0.0,
          'txns': [],
        };

        final double totalRevenue = summary['revenue'] as double? ?? 0.0;
        final int completedCount = summary['count'] as int? ?? 0;
        final double books = summary['books'] as double? ?? 0.0;
        final double drawing = summary['drawing'] as double? ?? 0.0;
        final double uniforms = summary['uniforms'] as double? ?? 0.0;
        final double electronics = summary['electronics'] as double? ?? 0.0;
        final double others = summary['others'] as double? ?? 0.0;
        final txns = summary['txns'] as List<dynamic>? ?? [];

        final double maxCatRev = [books, drawing, uniforms, electronics, others].reduce((a, b) => a > b ? a : b);
        final double booksPercent = maxCatRev > 0 ? books / maxCatRev : 0.0;
        final double drawingPercent = maxCatRev > 0 ? drawing / maxCatRev : 0.0;
        final double uniformsPercent = maxCatRev > 0 ? uniforms / maxCatRev : 0.0;
        final double electronicsPercent = maxCatRev > 0 ? electronics / maxCatRev : 0.0;
        final double othersPercent = maxCatRev > 0 ? others / maxCatRev : 0.0;

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Financial Reports',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.share_outlined),
                onSelected: (format) {
                  if (format == 'CSV') {
                    _downloadCSVReport(summary);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Simulated: Generated PDF Document successfully.')),
                    );
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
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: txns.length,
                    itemBuilder: (context, index) {
                      final txn = txns[index];
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
                            'Date: ${txn['date']}  |  Status: ${txn['status']}',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey),
                          ),
                          trailing: Text(
                            '₱${txn['amount'].toStringAsFixed(2)}',
                            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: TeknoyTheme.citMaroon),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
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
