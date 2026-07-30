import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';

/// Orders Hub — unified view for buyers ("My Purchases") and sellers ("Incoming Orders").
/// Shows full order details including buyer/seller name, pickup schedule, payment method, and action buttons.
class OrderHistoryView extends ConsumerStatefulWidget {
  const OrderHistoryView({super.key});

  @override
  ConsumerState<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends ConsumerState<OrderHistoryView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingBuyer = true;
  bool _isLoadingSeller = true;
  List<Map<String, dynamic>> _buyerOrders = [];
  List<Map<String, dynamic>> _sellerOrders = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchBuyerOrders();
    _fetchSellerOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchBuyerOrders() async {
    setState(() => _isLoadingBuyer = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) { setState(() => _isLoadingBuyer = false); return; }

      final response = await SupabaseConfig.client
          .from('orders')
          .select('''
            order_id,
            total_amount,
            status,
            quantity,
            created_at,
            pickup_location,
            pickup_day,
            pickup_time,
            payment_method,
            seller_confirmed_at,
            buyer_confirmed_at,
            seller_id,
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

      // Enrich each order with seller info
      final List<Map<String, dynamic>> enriched = [];
      for (final order in (response as List)) {
        final o = Map<String, dynamic>.from(order);
        try {
          final sellerRes = await SupabaseConfig.client
              .from('users')
              .select('full_name, contact, gcash_number')
              .eq('user_id', o['seller_id'])
              .maybeSingle();
          o['seller_name'] = sellerRes?['full_name'] ?? 'Seller';
          o['seller_contact'] = sellerRes?['contact'];
          o['seller_gcash'] = sellerRes?['gcash_number'];
        } catch (_) {}
        enriched.add(o);
      }

      setState(() {
        _buyerOrders = enriched;
        _isLoadingBuyer = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load purchases: $e')));
      setState(() => _isLoadingBuyer = false);
    }
  }

  Future<void> _fetchSellerOrders() async {
    setState(() => _isLoadingSeller = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) { setState(() => _isLoadingSeller = false); return; }

      final response = await SupabaseConfig.client
          .from('orders')
          .select('''
            order_id,
            total_amount,
            status,
            quantity,
            created_at,
            pickup_location,
            pickup_day,
            pickup_time,
            payment_method,
            seller_confirmed_at,
            buyer_confirmed_at,
            buyer_id,
            product_variants (
              variant_value,
              products (
                name,
                product_images (image_url, is_primary)
              )
            )
          ''')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      // Enrich each order with buyer info
      final List<Map<String, dynamic>> enriched = [];
      for (final order in (response as List)) {
        final o = Map<String, dynamic>.from(order);
        try {
          final buyerRes = await SupabaseConfig.client
              .from('users')
              .select('full_name, contact')
              .eq('user_id', o['buyer_id'])
              .maybeSingle();
          o['buyer_name'] = buyerRes?['full_name'] ?? 'Buyer';
          o['buyer_contact'] = buyerRes?['contact'];
        } catch (_) {}
        enriched.add(o);
      }

      setState(() {
        _sellerOrders = enriched;
        _isLoadingSeller = false;
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load incoming orders: $e')));
      setState(() => _isLoadingSeller = false);
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await SupabaseConfig.client
          .from('orders')
          .update({'status': 'APPROVED'})
          .eq('order_id', orderId);
      await _fetchSellerOrders();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order accepted! The buyer has been notified.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
    }
  }

  Future<void> _declineOrder(String orderId) async {
    try {
      await SupabaseConfig.client
          .from('orders')
          .update({'status': 'REJECTED'})
          .eq('order_id', orderId);
      await _fetchSellerOrders();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order declined.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED': return Colors.green;
      case 'PAYMENT_VERIFIED':
      case 'SELLER_ACCEPTED': return Colors.blue;
      case 'PAYMENT_SUBMITTED': return Colors.indigo;
      case 'RETURN_REQUESTED': return Colors.orange;
      case 'RETURN_APPROVED': return Colors.teal;
      case 'RETURN_DECLINED':
      case 'DECLINED':
      case 'CANCELLED': return Colors.red;
      case 'PENDING_SELLER_ACCEPT':
      case 'INQUIRY_SENT':
      default: return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING_SELLER_ACCEPT': return 'Awaiting Seller';
      case 'SELLER_ACCEPTED': return 'Accepted';
      case 'PAYMENT_SUBMITTED': return 'Payment Sent';
      case 'PAYMENT_VERIFIED': return 'Payment Verified';
      case 'COMPLETED': return 'Completed';
      case 'DECLINED': return 'Declined';
      case 'CANCELLED': return 'Cancelled';
      case 'RETURN_REQUESTED': return 'Return Requested';
      case 'RETURN_APPROVED': return 'Return Approved';
      case 'RETURN_DECLINED': return 'Return Declined';
      case 'INQUIRY_SENT': return 'Pending';
      default: return status;
    }
  }

  String? _getImageUrl(Map<String, dynamic> order) {
    final variant = order['product_variants'] as Map<String, dynamic>?;
    final product = variant?['products'] as Map<String, dynamic>?;
    final images = product?['product_images'] as List<dynamic>? ?? [];
    if (images.isEmpty) return null;
    return (images.firstWhere((img) => img['is_primary'] == true, orElse: () => images[0])['image_url'] as String?);
  }

  String _getProductName(Map<String, dynamic> order) {
    final variant = order['product_variants'] as Map<String, dynamic>?;
    final product = variant?['products'] as Map<String, dynamic>?;
    return product?['name'] ?? 'Unknown Product';
  }

  Widget _buildOrderCard({
    required Map<String, dynamic> order,
    required bool isDark,
    required bool isSeller,
  }) {
    final status = order['status'] as String? ?? '';
    final statusColor = _statusColor(status);
    final imageUrl = _getImageUrl(order);
    final productName = _getProductName(order);
    final isPending = status == 'PENDING_SELLER_ACCEPT';

    final otherPartyName = isSeller
        ? (order['buyer_name'] as String? ?? 'Buyer')
        : (order['seller_name'] as String? ?? 'Seller');
    final otherPartyLabel = isSeller ? 'Buyer' : 'Seller';
    final otherPartyContact = isSeller
        ? (order['buyer_contact'] as String?)
        : (order['seller_contact'] as String?);

    final pickupLocation = order['pickup_location'] as String? ?? '—';
    final pickupDay = order['pickup_day'] as String? ?? '—';
    final pickupTime = order['pickup_time'] as String? ?? '—';
    final paymentMethod = order['payment_method'] as String? ?? 'Cash on Delivery';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: child)),
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => OrderDetailView(order: order, isSeller: isSeller),
        )).then((_) => isSeller ? _fetchSellerOrders() : _fetchBuyerOrders()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141418) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isPending
                  ? Colors.orange.withOpacity(0.4)
                  : (isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF)),
              width: isPending ? 1.5 : 1,
            ),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: image + product name + status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl != null
                          ? Image.network(imageUrl, width: 56, height: 56, fit: BoxFit.cover)
                          : Container(width: 56, height: 56, color: Colors.grey.withOpacity(0.15), child: const Icon(Icons.receipt_long_rounded, color: Colors.grey)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(productName, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('₱ ${order['total_amount']}', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon, fontSize: 14)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.3)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info grid
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF7F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.person_outline_rounded, otherPartyLabel, otherPartyName, isDark),
                      if (otherPartyContact != null) ...[
                        const SizedBox(height: 6),
                        _infoRow(Icons.phone_outlined, 'Contact', otherPartyContact, isDark),
                      ],
                      const SizedBox(height: 6),
                      _infoRow(Icons.location_on_outlined, 'Pickup', pickupLocation, isDark),
                      const SizedBox(height: 6),
                      _infoRow(Icons.schedule_rounded, 'Schedule', '$pickupDay · $pickupTime', isDark),
                      const SizedBox(height: 6),
                      _infoRow(Icons.account_balance_wallet_outlined, 'Payment', paymentMethod, isDark),
                    ],
                  ),
                ),
                // Seller-only: Accept/Decline buttons
                if (isSeller && isPending) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _declineOrder(order['order_id']),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Decline', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _acceptOrder(order['order_id']),
                          icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                          label: const Text('Accept', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                // "Tap for details" hint
                if (!isPending || !isSeller) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Tap for details', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? Colors.white30 : Colors.black38)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 10, color: isDark ? Colors.white30 : Colors.black38),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
        Expanded(
          child: Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  int get _pendingSellerCount => _sellerOrders.where((o) => o['status'] == 'PENDING_SELLER_ACCEPT').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingCount = _pendingSellerCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders Hub', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TeknoyTheme.citMaroon,
          labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14),
          labelColor: TeknoyTheme.citMaroon,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          tabs: [
            const Tab(text: 'My Purchases'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Incoming Orders'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                      child: Text('$pendingCount', style: const TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Buyer: My Purchases ──
          RefreshIndicator(
            onRefresh: _fetchBuyerOrders,
            color: TeknoyTheme.citMaroon,
            child: _isLoadingBuyer
                ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
                : _buyerOrders.isEmpty
                    ? Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 56, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 12),
                          Text('No purchases yet', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _buyerOrders.length,
                        itemBuilder: (context, i) => _buildOrderCard(order: _buyerOrders[i], isDark: isDark, isSeller: false),
                      ),
          ),
          // ── Seller: Incoming Orders ──
          RefreshIndicator(
            onRefresh: _fetchSellerOrders,
            color: TeknoyTheme.citMaroon,
            child: _isLoadingSeller
                ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
                : _sellerOrders.isEmpty
                    ? Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_outlined, size: 56, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 12),
                          Text('No incoming orders', style: TextStyle(fontFamily: 'Outfit', fontSize: 16, color: isDark ? Colors.white54 : Colors.black54)),
                        ],
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sellerOrders.length,
                        itemBuilder: (context, i) => _buildOrderCard(order: _sellerOrders[i], isDark: isDark, isSeller: true),
                      ),
          ),
        ],
      ),
    );
  }
}
