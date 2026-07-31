import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';

/// Orders Hub — unified view for buyers ("My Purchases") and sellers ("Incoming Orders").
/// UX improvements: status filters, urgency pulse, date grouping, shimmer, better empty states.
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

  // Filter chip state
  String _buyerFilter = 'All';
  String _sellerFilter = 'All';
  bool _hasShownRefreshHint = false;

  static const _buyerFilters = ['All', 'Pending', 'Active', 'Completed', 'Cancelled'];
  static const _sellerFilters = ['All', 'Pending', 'Active', 'Completed', 'Cancelled'];

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

  // ─── Data Fetching ────────────────────────────────────────────────────────

  Future<void> _fetchBuyerOrders() async {
    setState(() => _isLoadingBuyer = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) { setState(() => _isLoadingBuyer = false); return; }

      final response = await SupabaseConfig.client
          .from('orders')
          .select('''
            order_id, total_amount, status, quantity, created_at,
            pickup_location, pickup_day, pickup_time, payment_method,
            seller_confirmed_at, buyer_confirmed_at, seller_id,
            product_variants (
              variant_value,
              products ( name, product_images (image_url, is_primary) )
            )
          ''')
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);

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

      if (!mounted) return;
      setState(() {
        _buyerOrders = enriched;
        _isLoadingBuyer = false;
        _hasShownRefreshHint = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load purchases: $e')));
        setState(() => _isLoadingBuyer = false);
      }
    }
  }

  Future<void> _fetchSellerOrders() async {
    if (!mounted) return;
    setState(() => _isLoadingSeller = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        if (mounted) setState(() => _isLoadingSeller = false);
        return;
      }

      final response = await SupabaseConfig.client
          .from('orders')
          .select('''
            order_id, total_amount, status, quantity, created_at,
            pickup_location, pickup_day, pickup_time, payment_method,
            seller_confirmed_at, buyer_confirmed_at, buyer_id,
            product_variants (
              variant_value,
              products ( name, product_images (image_url, is_primary) )
            )
          ''')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

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

      if (!mounted) return;
      setState(() {
        _sellerOrders = enriched;
        _isLoadingSeller = false;
        _hasShownRefreshHint = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load incoming orders: $e')));
        setState(() => _isLoadingSeller = false);
      }
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      await SupabaseConfig.client.from('orders').update({'status': 'APPROVED'}).eq('order_id', orderId);
      await _fetchSellerOrders();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order accepted! The buyer has been notified.'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
    }
  }

  Future<void> _declineOrder(String orderId) async {
    // #13 — Confirmation dialog for destructive decline
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConfirmActionSheet(
        title: 'Decline this order?',
        message: 'The buyer will be notified that their order was declined. This cannot be undone.',
        confirmLabel: 'Yes, Decline',
        confirmColor: Colors.red,
        icon: Icons.cancel_outlined,
      ),
    );
    if (confirmed != true) return;

    try {
      await SupabaseConfig.client.from('orders').update({'status': 'REJECTED'}).eq('order_id', orderId);
      await _fetchSellerOrders();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order declined.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to decline: $e')));
    }
  }

  // ─── Status Helpers ───────────────────────────────────────────────────────

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
      case 'REJECTED':
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
      case 'APPROVED': return 'Accepted';
      case 'PAYMENT_SUBMITTED': return 'Payment Sent';
      case 'PAYMENT_VERIFIED': return 'Payment Verified';
      case 'COMPLETED': return 'Completed';
      case 'DECLINED': return 'Declined';
      case 'REJECTED': return 'Rejected';
      case 'CANCELLED': return 'Cancelled';
      case 'RETURN_REQUESTED': return 'Return Requested';
      case 'RETURN_APPROVED': return 'Return Approved';
      case 'RETURN_DECLINED': return 'Return Declined';
      case 'INQUIRY_SENT': return 'Pending';
      default: return status;
    }
  }

  bool _isPending(String status) =>
      status == 'PENDING_SELLER_ACCEPT' || status == 'INQUIRY_SENT';

  bool _isActive(String status) =>
      status == 'APPROVED' || status == 'SELLER_ACCEPTED' ||
      status == 'PAYMENT_SUBMITTED' || status == 'PAYMENT_VERIFIED';

  bool _isCompleted(String status) =>
      status == 'COMPLETED' || status == 'RETURN_REQUESTED' ||
      status == 'RETURN_APPROVED' || status == 'RETURN_DECLINED';

  bool _isCancelled(String status) =>
      status == 'CANCELLED' || status == 'DECLINED' || status == 'REJECTED';

  bool _matchesFilter(String filter, String status) {
    switch (filter) {
      case 'Pending': return _isPending(status);
      case 'Active': return _isActive(status);
      case 'Completed': return _isCompleted(status);
      case 'Cancelled': return _isCancelled(status);
      default: return true;
    }
  }

  // ─── Date Grouping ────────────────────────────────────────────────────────

  String _dateGroup(String? createdAt) {
    if (createdAt == null) return 'Earlier';
    try {
      final date = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final orderDay = DateTime(date.year, date.month, date.day);
      final diff = today.difference(orderDay).inDays;
      if (diff == 0) return 'Today';
      if (diff <= 7) return 'This Week';
      return 'Earlier';
    } catch (_) {
      return 'Earlier';
    }
  }

  // ─── Image Helper ─────────────────────────────────────────────────────────

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

  int get _pendingSellerCount => _sellerOrders.where((o) => _isPending(o['status'] as String? ?? '')).length;

  // ─── Sorted + Filtered list (seller: pending first) ──────────────────────

  List<Map<String, dynamic>> _filteredSorted(List<Map<String, dynamic>> orders, String filter, {bool sellerMode = false}) {
    var filtered = orders.where((o) => _matchesFilter(filter, o['status'] as String? ?? '')).toList();
    if (sellerMode) {
      // #7: Promote pending orders to top
      filtered.sort((a, b) {
        final aPending = _isPending(a['status'] as String? ?? '') ? 0 : 1;
        final bPending = _isPending(b['status'] as String? ?? '') ? 0 : 1;
        return aPending.compareTo(bPending);
      });
    }
    return filtered;
  }

  // ─── Order Card ───────────────────────────────────────────────────────────

  Widget _buildOrderCard({
    required Map<String, dynamic> order,
    required bool isDark,
    required bool isSeller,
  }) {
    final status = order['status'] as String? ?? '';
    final statusColor = _statusColor(status);
    final imageUrl = _getImageUrl(order);
    final productName = _getProductName(order);
    final isPending = _isPending(status);
    final isUrgent = isPending; // #2 urgency

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
    final rawPayment = order['payment_method'] as String? ?? 'CASH_ON_PICKUP';
    final paymentMethod = (rawPayment == 'GCASH' || rawPayment == 'GCash') ? 'GCash' : 'Cash on Delivery';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => OrderDetailView(order: order, isSeller: isSeller),
          )).then((_) => isSeller ? _fetchSellerOrders() : _fetchBuyerOrders()),
          borderRadius: BorderRadius.circular(18),
          splashColor: TeknoyTheme.citMaroon.withValues(alpha: 0.06),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              // #7: tinted background for seller urgent cards
              color: isUrgent && isSeller
                  ? (isDark ? const Color(0xFF1E1610) : const Color(0xFFFFF8F0))
                  : (isDark ? const Color(0xFF141418) : Colors.white),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUrgent
                    ? Colors.orange.withValues(alpha: 0.5)
                    : (isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF)),
                width: isUrgent ? 1.5 : 1,
              ),
              boxShadow: [BoxShadow(
                color: isUrgent
                    ? Colors.orange.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                blurRadius: isUrgent ? 16 : 12,
                offset: const Offset(0, 4),
              )],
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // #2: Urgency badge
                  if (isUrgent) ...[
                    _UrgencyPulseBadge(isSeller: isSeller),
                    const SizedBox(height: 10),
                  ],

                  // Header row: image + product name + status chip
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // #5: shimmer fallback image
                      _ProductImage(imageUrl: imageUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(productName,
                                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700, fontSize: 15),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text('₱ ${order['total_amount']}',
                                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon, fontSize: 14)),
                          ],
                        ),
                      ),
                      // Status pill with left dot
                      _StatusPill(label: _statusLabel(status), color: statusColor),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Info grid
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF7F7FA),
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

                  // Seller-only: Accept/Decline buttons for pending
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
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF22A559), Color(0xFF16834A)]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => _acceptOrder(order['order_id']),
                              icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                              label: const Text('Accept', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

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
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.black45),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
        Expanded(
          child: Text(value,
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ─── Date-grouped list with section headers ───────────────────────────────

  Widget _buildGroupedList({
    required List<Map<String, dynamic>> orders,
    required bool isDark,
    required bool isSeller,
    required String filter,
    required Future<void> Function() onRefresh,
    required bool isLoading,
    required Widget emptyState,
  }) {
    if (isLoading) return const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon));

    final sorted = _filteredSorted(orders, filter, sellerMode: isSeller);
    if (sorted.isEmpty) return emptyState;

    // #4: Group by date
    final groups = <String, List<Map<String, dynamic>>>{};
    final groupOrder = <String>[];
    for (final o in sorted) {
      final g = _dateGroup(o['created_at'] as String?);
      if (!groups.containsKey(g)) {
        groups[g] = [];
        groupOrder.add(g);
      }
      groups[g]!.add(o);
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _hasShownRefreshHint = true);
        await onRefresh();
      },
      color: TeknoyTheme.citMaroon,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          // #6: Pull-to-refresh hint — fades after first pull
          AnimatedOpacity(
            opacity: _hasShownRefreshHint ? 0 : 1,
            duration: const Duration(milliseconds: 600),
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: isDark ? Colors.white24 : Colors.black26),
                  const SizedBox(width: 4),
                  Text('Pull to refresh', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? Colors.white24 : Colors.black38)),
                ],
              ),
            ),
          ),
          for (final group in groupOrder) ...[
            _DateGroupHeader(label: group, isDark: isDark),
            for (final o in groups[group]!)
              _buildOrderCard(order: o, isDark: isDark, isSeller: isSeller),
          ],
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pendingCount = _pendingSellerCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders Hub', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: TeknoyTheme.citMaroon,
                labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14),
                unselectedLabelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w500, fontSize: 14),
                labelColor: TeknoyTheme.citMaroon,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
                tabs: [
                  // AppBar subtitle with count (#Visual)
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('My Purchases'),
                        if (_buyerOrders.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(10)),
                            child: Text('${_buyerOrders.length}', style: TextStyle(fontFamily: 'Outfit', fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Incoming'),
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
              // #1: Status filter chips
              AnimatedBuilder(
                animation: _tabController,
                builder: (_, __) {
                  final isBuyerTab = _tabController.index == 0;
                  final filters = isBuyerTab ? _buyerFilters : _sellerFilters;
                  final current = isBuyerTab ? _buyerFilter : _sellerFilter;
                  return SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      itemCount: filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final f = filters[i];
                        final selected = f == current;
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (isBuyerTab) _buyerFilter = f;
                            else _sellerFilter = f;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: selected ? TeknoyTheme.citMaroon : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? TeknoyTheme.citMaroon : Colors.transparent),
                            ),
                            child: Text(f,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 12,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                  color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                                )),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Buyer: My Purchases ──
          _buildGroupedList(
            orders: _buyerOrders,
            isDark: isDark,
            isSeller: false,
            filter: _buyerFilter,
            onRefresh: _fetchBuyerOrders,
            isLoading: _isLoadingBuyer,
            emptyState: _EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'No purchases yet',
              subtitle: 'Start shopping on the feed!',
              actionLabel: 'Browse Products',
              isDark: isDark,
              onAction: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ProductDiscoveryFeedView()),
              ),
            ),
          ),
          // ── Seller: Incoming Orders ──
          _buildGroupedList(
            orders: _sellerOrders,
            isDark: isDark,
            isSeller: true,
            filter: _sellerFilter,
            onRefresh: _fetchSellerOrders,
            isLoading: _isLoadingSeller,
            emptyState: _EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No incoming orders',
              subtitle: 'Make sure your listings are live!',
              actionLabel: null,
              isDark: isDark,
              onAction: null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

/// #2: Urgency pulsing badge for pending orders
class _UrgencyPulseBadge extends StatefulWidget {
  final bool isSeller;
  const _UrgencyPulseBadge({required this.isSeller});

  @override
  State<_UrgencyPulseBadge> createState() => _UrgencyPulseBadgeState();
}

class _UrgencyPulseBadgeState extends State<_UrgencyPulseBadge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final msg = widget.isSeller ? '⚡ Action Needed — New Order!' : '⏳ Waiting for seller to accept';
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Opacity(
        opacity: _pulse.value,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(msg, style: const TextStyle(fontFamily: 'Outfit', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
        ),
      ),
    );
  }
}

/// #5: Product image with shimmer fallback
class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  const _ProductImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: imageUrl != null
          ? Image.network(
              imageUrl!,
              width: 56, height: 56, fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : _ShimmerBox(width: 56, height: 56),
              errorBuilder: (_, __, ___) => _FallbackIcon(),
            )
          : _FallbackIcon(),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56, height: 56,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.storefront_rounded, color: Colors.grey, size: 24),
    );
  }
}

class _ShimmerBox extends StatefulWidget {
  final double width, height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        color: Colors.grey.withValues(alpha: _anim.value),
      ),
    );
  }
}

/// Status pill with left-side colored dot (improved design)
class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

/// #4: Date group header
class _DateGroupHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _DateGroupHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white54 : Colors.black45)),
          const SizedBox(width: 8),
          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.black12, height: 1)),
        ],
      ),
    );
  }
}

/// #3: Context-aware empty state with CTA
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final bool isDark;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.isDark,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: isDark ? Colors.white30 : Colors.black26),
            ),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? Colors.white38 : Colors.black38), textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [TeknoyTheme.citMaroon, Color(0xFF8B1A1A)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(actionLabel!, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// #13: Confirmation bottom sheet for destructive actions
class _ConfirmActionSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final IconData icon;

  const _ConfirmActionSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A20) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: confirmColor.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: confirmColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? Colors.white54 : Colors.black54), textAlign: TextAlign.center),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confirmColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(confirmLabel, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
