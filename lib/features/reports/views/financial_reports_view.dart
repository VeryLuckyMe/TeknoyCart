import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

/// Financial Reports and Sales Summary dashboard matching SRS Module 7 (FR-20 / FR-21).
/// Enables sellers/vendors to track their campus merchandise sales and export reports.
class FinancialReportsView extends StatefulWidget {
  const FinancialReportsView({super.key});

  @override
  State<FinancialReportsView> createState() => _FinancialReportsViewState();
}

class _FinancialReportsViewState extends State<FinancialReportsView> {
  String _selectedPeriod = 'Monthly';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly'];

  // Mock transaction logs for CIT-U students (anonymized names per RA 10173 regulations)
  final List<Map<String, dynamic>> _transactions = [
    {
      'id': 'TXN-9082',
      'item': 'Official CIT-U College Polo',
      'variant': 'Medium',
      'qty': 1,
      'amount': 450.00,
      'buyer': 'Kirsten B.',
      'method': 'GCash',
      'date': 'May 25, 2026'
    },
    {
      'id': 'TXN-9079',
      'item': 'Engineering Drawing Board',
      'variant': 'Standard',
      'qty': 1,
      'amount': 400.00,
      'buyer': 'Jusfer O.',
      'method': 'GCash',
      'date': 'May 24, 2026'
    },
    {
      'id': 'TXN-9065',
      'item': 'Intramural Gold shirt',
      'variant': 'Large',
      'qty': 2,
      'amount': 500.00,
      'buyer': 'Clarence M.',
      'method': 'Cash',
      'date': 'May 22, 2026'
    },
    {
      'id': 'TXN-9051',
      'item': 'PE Uniform Pants',
      'variant': 'Small',
      'qty': 1,
      'amount': 250.00,
      'buyer': 'Mikel N.',
      'method': 'Cash',
      'date': 'May 20, 2026'
    },
  ];

  void _simulateDownload(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.download_done_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text('Generated and saved sales report as $format!'),
          ],
        ),
        backgroundColor: TeknoyTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Financial Reports',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.share_outlined),
            onSelected: _simulateDownload,
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
            // Period Selector Banner
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

            // Sales Metrics Grid (FR-20)
            Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    title: 'Total Revenue',
                    value: '₱1,600.00',
                    icon: Icons.payments_rounded,
                    color: TeknoyTheme.citMaroon,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricCard(
                    title: 'Transactions',
                    value: '5 Completed',
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
                    _buildChartRow('Uniforms', '₱700.00', 0.7, TeknoyTheme.citMaroon),
                    const SizedBox(height: 12),
                    _buildChartRow('Drawing Tools', '₱400.00', 0.4, TeknoyTheme.citGold),
                    const SizedBox(height: 12),
                    _buildChartRow('Merchandise', '₱500.00', 0.5, Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Chronological Transaction Log (FR-21)
            const Text(
              'Completed Transactions Log',
              style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final txn = _transactions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: txn['method'] == 'GCash' ? Colors.blue.shade50 : Colors.green.shade50,
                      child: Icon(
                        txn['method'] == 'GCash' ? Icons.account_balance_wallet_rounded : Icons.payments_rounded,
                        color: txn['method'] == 'GCash' ? Colors.blue : Colors.green,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      txn['item'],
                      style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'Buyer: ${txn['buyer']}  |  ${txn['date']}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₱${txn['amount'].toStringAsFixed(2)}',
                          style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14, color: TeknoyTheme.citMaroon),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'COMPLETED',
                            style: TextStyle(fontFamily: 'Outfit', fontSize: 8, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
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
