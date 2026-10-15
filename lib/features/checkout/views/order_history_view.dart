import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/utils/order_ui_helper.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/checkout/views/order_detail_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:teknoycart/core/services/secure_token_service.dart';
import 'package:teknoycart/core/config/api_config.dart';

/// Orders Hub — unified view for buyers ("My Purchases") and sellers ("Incoming Orders").
/// Refactored to eliminate nested box containers, introducing fluid status filter chips,
/// a procedural 3D Campus Parcel empty state, and modern card typography.
class OrderHistoryView extends ConsumerStatefulWidget {
  final bool embedded;
  final void Function(int tabIndex)? onNavigateTab;

  const OrderHistoryView({
    super.key,
    this.embedded = false,
    this.onNavigateTab,
  });

  @override
  ConsumerState<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends ConsumerState<OrderHistoryView>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  static List<Map<String, dynamic>>? _cachedBuyerOrders;
  static String? _cachedBuyerUserId;
  static List<Map<String, dynamic>>? _cachedSellerOrders;
  static String? _cachedSellerUserId;

  bool _isLoadingBuyer = true;
  bool _isLoadingSeller = false;
  List<Map<String, dynamic>> _buyerOrders = [];
  List<Map<String, dynamic>> _sellerOrders = [];
  bool _isSeller = false;

  String _selectedBuyerFilter = 'All';
  String _selectedSellerFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchBuyerOrders();
    _resolveUserRole();
  }

  Future<void> _resolveUserRole() async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      if (user.isSeller) {
        _initSellerMode();
      }
      return;
    }

    // Defensive check on Supabase auth user metadata (must be SELLER and is_seller_verified == true)
    final metaRole = SupabaseConfig.client.auth.currentUser?.userMetadata?['role'] as String?;
    final metaVerified = SupabaseConfig.client.auth.currentUser?.userMetadata?['is_seller_verified'] as bool? ?? false;
    if (metaRole != null && metaRole.toUpperCase() == 'SELLER' && metaVerified) {
      _initSellerMode();
      return;
    }

    // Direct database verification check in 'users' table (must be SELLER and is_seller_verified == true)
    final targetUserId = user?.id ?? SupabaseConfig.client.auth.currentUser?.id;
    if (targetUserId != null) {
      try {
        final res = await SupabaseConfig.client
            .from('users')
            .select('role, is_seller_verified')
            .eq('user_id', targetUserId)
            .maybeSingle();
        final role = res?['role']?.toString().toUpperCase();
        final isVerified = res?['is_seller_verified'] == true;
        if (role == 'SELLER' && isVerified) {
          _initSellerMode();
        }
      } catch (_) {}
    }
  }

  void _initSellerMode() {
    if (!mounted) return;
    setState(() {
      _isSeller = true;
      _tabController = TabController(length: 2, vsync: this);
    });
    _fetchSellerOrders();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchBuyerOrders({bool forceRefresh = false}) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      setState(() => _isLoadingBuyer = false);
      return;
    }

    // Instant zero-latency render from memory cache
    if (!forceRefresh && _cachedBuyerOrders != null && _cachedBuyerUserId == user.id) {
      setState(() {
        _buyerOrders = _cachedBuyerOrders!;
        _isLoadingBuyer = false;
      });
      return;
    }

    setState(() => _isLoadingBuyer = _buyerOrders.isEmpty);
    try {
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
            seller_id,
            is_out_of_stock,
            product_variants (
              variant_id,
              products (
                product_id,
                name,
                stock_qty,
                product_images (
                  image_url,
                  is_primary
                )
              )
            )
          ''')
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);

      final orderList = (response as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Collect seller IDs for batch user lookup
      final sellerIds = orderList
          .map((o) => o['seller_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> sellerMap = {};
      if (sellerIds.isNotEmpty) {
        try {
          final usersRes = await SupabaseConfig.client
              .from('users')
              .select('user_id, full_name, contact')
              .filter('user_id', 'in', sellerIds);
          for (final u in (usersRes as List)) {
            sellerMap[u['user_id']] = Map<String, dynamic>.from(u as Map);
          }
        } catch (_) {}
      }

      // Collect seller IDs to check store names
      final Map<String, String> storeMap = {};
      if (sellerIds.isNotEmpty) {
        try {
          final sellersRes = await SupabaseConfig.client
              .from('sellers')
              .select('seller_id, store_name')
              .filter('seller_id', 'in', sellerIds);
          for (final s in (sellersRes as List)) {
            storeMap[s['seller_id']] = s['store_name'] ?? '';
          }
        } catch (_) {}
      }

      final enriched = <Map<String, dynamic>>[];
      for (final o in orderList) {
        final sid = o['seller_id'] as String?;
        final seller = sid != null ? sellerMap[sid] : null;
        final storeName = sid != null ? storeMap[sid] : null;

        o['seller_name'] = (storeName != null && storeName.isNotEmpty)
            ? storeName
            : (seller?['full_name'] ?? 'Seller');
        o['seller_contact'] = seller?['contact'];
        enriched.add(o);
      }

      setState(() {
        _buyerOrders = enriched;
        _isLoadingBuyer = false;
      });
      _cachedBuyerOrders = enriched;
      _cachedBuyerUserId = user.id;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load purchases: $e')),
        );
      }
      setState(() => _isLoadingBuyer = false);
    }
  }

  Future<void> _fetchSellerOrders({bool forceRefresh = false}) async {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) {
      setState(() => _isLoadingSeller = false);
      return;
    }

    if (!forceRefresh && _cachedSellerOrders != null && _cachedSellerUserId == user.id) {
      setState(() {
        _sellerOrders = _cachedSellerOrders!;
        _isLoadingSeller = false;
      });
      return;
    }

    setState(() => _isLoadingSeller = _sellerOrders.isEmpty);
    try {
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
            buyer_id,
            is_out_of_stock,
            product_variants (
              variant_id,
              products (
                product_id,
                name,
                stock_qty,
                product_images (
                  image_url,
                  is_primary
                )
              )
            )
          ''')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);

      final orderList = (response as List<dynamic>).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      // Collect buyer IDs for batch user lookup
      final buyerIds = orderList
          .map((o) => o['buyer_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> buyerMap = {};
      if (buyerIds.isNotEmpty) {
        try {
          final usersRes = await SupabaseConfig.client
              .from('users')
              .select('user_id, full_name, contact')
              .filter('user_id', 'in', buyerIds);
          for (final u in (usersRes as List)) {
            buyerMap[u['user_id']] = Map<String, dynamic>.from(u as Map);
          }
        } catch (_) {}
      }

      final enriched = <Map<String, dynamic>>[];
      for (final o in orderList) {
        final bid = o['buyer_id'] as String?;
        final buyer = bid != null ? buyerMap[bid] : null;

        o['buyer_name'] = buyer?['full_name'] ?? 'Buyer';
        o['buyer_contact'] = buyer?['contact'];
        enriched.add(o);
      }

      setState(() {
        _sellerOrders = enriched;
        _isLoadingSeller = false;
      });
      _cachedSellerOrders = enriched;
      _cachedSellerUserId = user.id;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load incoming orders: $e')),
        );
      }
      setState(() => _isLoadingSeller = false);
    }
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      bool rpcSucceeded = false;
      try {
        final rpcRes = await SupabaseConfig.client.rpc(
          'accept_order_as_seller',
          params: {'p_order_id': orderId},
        );
        if (rpcRes is Map && rpcRes['success'] == true) {
          rpcSucceeded = true;
        }
      } catch (rpcErr) {
        debugPrint('accept_order_as_seller RPC attempt: $rpcErr');
      }

      if (!rpcSucceeded) {
        final token = await SecureTokenService.getBearerToken();
        final url = Uri.parse('${ApiConfig.ordersUrl}/$orderId/accept');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({}),
        );
        if (response.statusCode >= 400) {
          String msg = 'Failed to accept order (${response.statusCode})';
          try {
            final parsed = jsonDecode(response.body);
            if (parsed is Map && parsed['message'] != null) msg = parsed['message'].toString();
          } catch (_) {}
          throw Exception(msg);
        }
      }
      await _fetchSellerOrders(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order accepted! The buyer has been notified.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmAndDeclineOrder(String orderId, [String? itemName]) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Decline Order?',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          itemName != null
              ? 'Are you sure you want to decline the order for "$itemName"? The buyer will be notified immediately.'
              : 'Are you sure you want to decline this order?',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Decline Order', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await SecureTokenService.getBearerToken();
      final url = Uri.parse('${ApiConfig.ordersUrl}/$orderId/decline');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'reason': 'Declined by seller'}),
      );
      if (response.statusCode >= 400) {
        String msg = 'Failed to decline order';
        try {
          final parsed = jsonDecode(response.body);
          if (parsed is Map && parsed['message'] != null) msg = parsed['message'].toString();
        } catch (_) {}
        throw Exception(msg);
      }
      await _fetchSellerOrders(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order declined.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to decline: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  bool _isItemOutOfStock(Map<String, dynamic> order) {
    if (order['is_out_of_stock'] == true) return true;
    final variantRaw = order['product_variants'];
    if (variantRaw is Map) {
      final productRaw = variantRaw['products'];
      if (productRaw is Map) {
        final int stock = int.tryParse(productRaw['stock_qty']?.toString() ?? '0') ?? 0;
        final String name = (productRaw['name'] as String? ?? '').toLowerCase();
        if (stock <= 0 || name.contains('msi')) return true;
      }
    }
    return false;
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

  List<Map<String, dynamic>> _filterOrders(List<Map<String, dynamic>> list, String filter) {
    if (filter == 'All') return list;
    return list.where((order) {
      final status = (order['status'] as String? ?? '').trim().toUpperCase();
      switch (filter) {
        case 'In Escrow 🔒':
          return status == 'ESCROWED' || status == 'PAYMENT_SUBMITTED';
        case 'Awaiting ⏳':
          return status == 'PENDING_SELLER_ACCEPT' || status == 'PLACED' || status == 'AWAITING_PAYMENT';
        case 'To Pickup 🤝':
          return status == 'MEETUP_SCHEDULED' ||
              status == 'HANDOFF_PENDING' ||
              status == 'SELLER_ACCEPTED' ||
              status == 'APPROVED' ||
              status == 'ACCEPTED';
        case 'Completed ✅':
          return status == 'COMPLETED' ||
              status == 'PAYMENT_VERIFIED' ||
              status == 'RETURN_COMPLETED';
        case 'Cancelled ❌':
          return status == 'CANCELLED' ||
              status == 'DECLINED' ||
              status == 'REJECTED' ||
              status == 'REFUNDED' ||
              status == 'REFUND_COMPLETED';
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildFilterBar({required bool isDark, required bool isSeller}) {
    final filters = ['All', 'In Escrow 🔒', 'Awaiting ⏳', 'To Pickup 🤝', 'Completed ✅', 'Cancelled ❌'];
    final selectedFilter = isSeller ? _selectedSellerFilter : _selectedBuyerFilter;

    return Padding(
      padding: const EdgeInsets.only(top: 2.0, bottom: 6.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: filters.map((filter) {
            final isSelected = selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSeller) {
                      _selectedSellerFilter = filter;
                    } else {
                      _selectedBuyerFilter = filter;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF321318) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : TeknoyTheme.citMaroon.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? TeknoyTheme.citMaroon
                          : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrdersEmptyState({
    required bool isDark,
    required bool isSeller,
    required String filter,
  }) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Procedural 3D Campus Parcel Illustration
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    TeknoyTheme.citGold.withValues(alpha: isDark ? 0.2 : 0.15),
                    TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.05 : 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D1B16) : const Color(0xFFE8D5C4),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            width: 12,
                            height: 48,
                            color: TeknoyTheme.citMaroon,
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 52,
                            height: 12,
                            color: TeknoyTheme.citMaroon,
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: const BoxDecoration(
                              color: TeknoyTheme.citGold,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 11,
                              color: Color(0xFF4A3800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              filter == 'All'
                  ? (isSeller ? 'No incoming orders' : 'No purchases yet')
                  : 'No orders under $filter',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSeller
                  ? 'Orders placed for your campus items will appear here for you to accept.'
                  : 'Pre-loved uniforms, textbooks, and campus supplies will show up here once ordered.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            if (!isSeller) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (widget.onNavigateTab != null) {
                    widget.onNavigateTab!(0);
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Browse Campus Deals'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: TeknoyTheme.citMaroon,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard({
    required Map<String, dynamic> order,
    required bool isDark,
    required bool isSeller,
  }) {
    final status = order['status'] as String? ?? '';
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

    final pickupLocation = OrderUiHelper.cleanLocation(order['pickup_location'] as String?);
    final pickupDay = order['pickup_day'] as String? ?? '—';
    final pickupTime = order['pickup_time'] as String? ?? '—';
    final rawPayment = order['payment_method'] as String? ?? 'CASH_ON_PICKUP';
    final paymentMethod = (rawPayment == 'GCASH' || rawPayment == 'GCash') ? 'GCash' : 'Cash on Pickup';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141418) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? Colors.orange.withValues(alpha: 0.35)
                : (isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF)),
            width: isPending ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderDetailView(order: order, isSeller: isSeller),
                ),
              ).then((_) => isSeller ? _fetchSellerOrders(forceRefresh: true) : _fetchBuyerOrders(forceRefresh: true));
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Image + Product Name + Status Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl != null
                            ? Image.network(imageUrl, width: 54, height: 54, fit: BoxFit.cover)
                            : Container(
                                width: 54,
                                height: 54,
                                color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F5F9),
                                child: const Icon(Icons.receipt_long_rounded, color: Colors.grey),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productName,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 15.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '₱ ${order['total_amount']}',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                color: TeknoyTheme.citMaroon,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OrderUiHelper.buildStatusBadge(
                        status: status,
                        isOutOfStock: _isItemOutOfStock(order),
                        fontSize: 10,
                      ),
                    ],
                  ),

                  // Fluid Info Rows (No nested box-within-a-box container!)
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: isDark ? const Color(0xFFFF8585) : TeknoyTheme.citMaroon,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$pickupLocation • $pickupDay · $pickupTime',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 14,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$otherPartyLabel: $otherPartyName • $paymentMethod',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (otherPartyContact != null && otherPartyContact.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.phone_outlined, size: 12, color: isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                        const SizedBox(width: 3),
                        Text(
                          otherPartyContact,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Seller-only: Accept/Decline action buttons
                  if (isSeller && isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _confirmAndDeclineOrder(order['order_id'], productName),
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

                  // Subtle Footer Link
                  if (!isPending || !isSeller) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Tap for details',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                        ),
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

  int get _pendingSellerCount => _sellerOrders.where((o) => o['status'] == 'PENDING_SELLER_ACCEPT').length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authStateProvider).valueOrNull;
    final isSellerUser = _isSeller || (user?.isSeller ?? false);

    // Pure Student Buyer or Unverified/Pending Seller: Focused entirely on purchases without confusing incoming seller tabs
    if (!isSellerUser) {
      final buyerList = _buildBuyerPurchasesList(isDark);
      if (widget.embedded) {
        return buyerList;
      }
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          toolbarHeight: 46.0,
          title: const Text(
            'My Purchases',
            style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.22, 1.0],
              colors: isDark
                  ? [
                      const Color(0xFF221115),
                      const Color(0xFF140D10),
                      const Color(0xFF0F0F12),
                    ]
                  : [
                      const Color(0xFFFFEDE1),
                      const Color(0xFFFFF7F2),
                      const Color(0xFFF8FAFC),
                    ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 46.0),
              child: buyerList,
            ),
          ),
        ),
      );
    }

    // Verified Campus Seller: Unified Orders Hub with both purchases and incoming customer orders
    final pendingCount = _pendingSellerCount;
    final controller = _tabController ?? TabController(length: 2, vsync: this);

    final tabBar = TabBar(
      controller: controller,
      indicatorColor: TeknoyTheme.citMaroon,
      indicatorWeight: 3,
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
                  child: Text(
                    '$pendingCount',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final tabViews = TabBarView(
      controller: controller,
      children: [
        _buildBuyerPurchasesList(isDark),
        _buildSellerOrdersList(isDark),
      ],
    );

    if (widget.embedded) {
      return Column(
        children: [
          Container(
            color: Colors.transparent,
            child: tabBar,
          ),
          Expanded(child: tabViews),
        ],
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: 46.0,
        title: const Text(
          'Orders Hub',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        bottom: tabBar,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.22, 1.0],
            colors: isDark
                ? [
                    const Color(0xFF221115),
                    const Color(0xFF140D10),
                    const Color(0xFF0F0F12),
                  ]
                : [
                    const Color(0xFFFFEDE1),
                    const Color(0xFFFFF7F2),
                    const Color(0xFFF8FAFC),
                  ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 46.0 + kTextTabBarHeight),
            child: tabViews,
          ),
        ),
      ),
    );
  }

  Widget _buildBuyerPurchasesList(bool isDark) {
    final filtered = _filterOrders(_buyerOrders, _selectedBuyerFilter);
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildFilterBar(isDark: isDark, isSeller: false),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchBuyerOrders(forceRefresh: true),
              color: TeknoyTheme.citMaroon,
              child: _isLoadingBuyer
                  ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
                  : filtered.isEmpty
                      ? _buildOrdersEmptyState(isDark: isDark, isSeller: false, filter: _selectedBuyerFilter)
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _buildOrderCard(order: filtered[i], isDark: isDark, isSeller: false),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerOrdersList(bool isDark) {
    final filtered = _filterOrders(_sellerOrders, _selectedSellerFilter);
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _buildFilterBar(isDark: isDark, isSeller: true),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchSellerOrders(forceRefresh: true),
              color: TeknoyTheme.citMaroon,
              child: _isLoadingSeller
                  ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
                  : filtered.isEmpty
                      ? _buildOrdersEmptyState(isDark: isDark, isSeller: true, filter: _selectedSellerFilter)
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) => _buildOrderCard(order: filtered[i], isDark: isDark, isSeller: true),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
