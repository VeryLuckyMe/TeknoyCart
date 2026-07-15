import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';

class OrderHistoryView extends ConsumerStatefulWidget {
  const OrderHistoryView({super.key});

  @override
  ConsumerState<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends ConsumerState<OrderHistoryView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final response = await SupabaseConfig.client
          .from('orders')
          .select('''
            order_id,
            total_amount,
            status,
            quantity,
            created_at,
            product_variants (
              variant_value,
              products (
                name,
                product_images (image_url, is_primary)
              )
            )
          ''')
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);
          
      setState(() {
        _orders = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load order history: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
      case 'PAYMENT_VERIFIED':
        return Colors.green;
      case 'APPROVED':
      case 'READY_FOR_PICKUP':
        return Colors.blue;
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.red;
      case 'INQUIRY_SENT':
      case 'PAYMENT_SUBMITTED':
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF0F0A0A) : Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
          : _orders.isEmpty
              ? const Center(child: Text('You have no past orders.', style: TextStyle(fontFamily: 'Inter')))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final variant = order['product_variants'] as Map<String, dynamic>?;
                    final product = variant != null ? (variant['products'] as Map<String, dynamic>?) : null;
                    final images = product != null ? (product['product_images'] as List<dynamic>? ?? []) : [];
                    
                    final imageUrl = images.isNotEmpty 
                        ? (images.firstWhere((img) => img['is_primary'] == true, orElse: () => images[0])['image_url'] as String? ?? '')
                        : '';
                        
                    final statusColor = _getStatusColor(order['status'] ?? '');
                        
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover),
                              )
                            : Container(
                                width: 60, height: 60, 
                                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.receipt, color: Colors.grey),
                              ),
                        title: Text(product?['name'] ?? 'Unknown Product', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Qty: ${order['quantity']} • ₱ ${order['total_amount']}', style: const TextStyle(color: TeknoyTheme.citMaroon, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                order['status'] ?? 'PENDING',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          // Could navigate to order details page
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
