import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:teknoycart/core/services/secure_token_service.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';

const String _backendOrdersUrl = 'https://teknoycart-backend.onrender.com/api/orders';

/// Self-contained, robust bottom sheet for inspecting and reconciling reserved holds.
class ReservedOrdersSheet extends StatefulWidget {
  final String variantId;
  final String productName;
  final int initialReservedQty;
  final int stockQty;
  final VoidCallback onInventoryUpdated;

  const ReservedOrdersSheet({
    super.key,
    required this.variantId,
    required this.productName,
    required this.initialReservedQty,
    required this.stockQty,
    required this.onInventoryUpdated,
  });

  @override
  State<ReservedOrdersSheet> createState() => _ReservedOrdersSheetState();
}

class _ReservedOrdersSheetState extends State<ReservedOrdersSheet> {
  late int _reservedCount;
  late int _totalStock;
  bool _isLoading = true;
  bool _isReconciling = false;
  String? _cancellingOrderId;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _reservedCount = widget.initialReservedQty;
    _totalStock = widget.stockQty;
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final res = await SupabaseConfig.client
          .from('orders')
          .select('order_id, quantity, status, created_at, buyer_id, total_amount')
          .eq('variant_id', widget.variantId)
          .inFilter('status', [
            'PLACED', 'ACCEPTED', 'PAYMENT_SUBMITTED', 'PAYMENT_VERIFIED',
            'MEETUP_SCHEDULED', 'NEEDS_REVIEW', 'REFUND_REQUESTED'
          ])
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> enriched = [];
      for (final item in res) {
        final m = Map<String, dynamic>.from(item);
        final buyerId = m['buyer_id']?.toString();
        if (buyerId != null && buyerId.isNotEmpty) {
          try {
            final u = await SupabaseConfig.client
                .from('users')
                .select('full_name, email')
                .eq('user_id', buyerId)
                .maybeSingle();
            m['buyer_name'] = u?['full_name'] ?? 'Buyer';
            m['buyer_email'] = u?['email'] ?? '';
          } catch (_) {
            m['buyer_name'] = 'Buyer';
            m['buyer_email'] = '';
          }
        } else {
          m['buyer_name'] = 'Buyer';
          m['buyer_email'] = '';
        }
        enriched.add(m);
      }

      if (mounted) {
        setState(() {
          _orders = enriched;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reconcile({bool showFeedback = true}) async {
    if (_isReconciling) return;
    setState(() => _isReconciling = true);

    try {
      int actualReserved = 0;
      try {
        final rpcRes = await SupabaseConfig.client.rpc(
          'reconcile_inventory_holds',
          params: {'p_variant_id': widget.variantId},
        );
        if (rpcRes is Map && rpcRes['reserved_qty'] != null) {
          actualReserved = (rpcRes['reserved_qty'] as num).toInt();
          if (rpcRes['stock_qty'] != null) {
            _totalStock = (rpcRes['stock_qty'] as num).toInt();
          }
        }
      } catch (_) {
        // Direct ground-truth active orders sum fallback
        for (final o in _orders) {
          actualReserved += (o['quantity'] as num? ?? 0).toInt();
        }
        await SupabaseConfig.client
            .from('inventory')
            .update({
              'reserved_qty': actualReserved,
              'last_updated': DateTime.now().toIso8601String(),
            })
            .eq('variant_id', widget.variantId);
      }

      if (mounted) {
        setState(() {
          _reservedCount = actualReserved;
        });
      }

      // Notify parent to refresh list silently
      widget.onInventoryUpdated();

      if (showFeedback && mounted) {
        final avail = (_totalStock - actualReserved).clamp(0, 999999);
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Reconciled holds! Reserved is now $actualReserved (Available: $avail).'),
            backgroundColor: TeknoyTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Failed to reconcile: $e'),
            backgroundColor: TeknoyTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isReconciling = false);
      }
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    if (orderId.isEmpty || _cancellingOrderId != null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel In-Flight Order?'),
        content: const Text(
          'Cancelling this order will release its reserved stock hold immediately back to Available inventory.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Keep Order')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Cancel Order', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _cancellingOrderId = orderId);
    try {
      bool cancelled = false;

      // 1. Primary path: Supabase cancel_order_as_seller RPC
      try {
        final rpcRes = await SupabaseConfig.client.rpc(
          'cancel_order_as_seller',
          params: {'p_order_id': orderId, 'p_reason': 'Cancelled by seller from inventory inspector'},
        );
        if (rpcRes is Map && rpcRes['success'] == true) {
          cancelled = true;
        }
      } catch (_) {}

      // 2. Secondary path: Spring Boot backend order endpoint
      if (!cancelled) {
        try {
          final token = await SecureTokenService.getBearerToken();
          final url = Uri.parse('$_backendOrdersUrl/$orderId/cancel');
          final response = await http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'reason': 'Cancelled by seller from inventory inspector'}),
          );
          if (response.statusCode < 400) {
            cancelled = true;
          }
        } catch (_) {}
      }

      if (cancelled) {
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Order cancelled. Reserved hold released back to inventory.'),
              backgroundColor: TeknoyTheme.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        await _reconcile(showFeedback: false);
        await _loadOrders();
      } else {
        throw Exception('Failed to cancel order through available services');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Could not cancel order: $e'),
            backgroundColor: TeknoyTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cancellingOrderId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final available = (_totalStock - _reservedCount).clamp(0, 999999);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: TeknoyTheme.citMaroon, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reserved Orders Inspector',
                        style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        widget.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Quick Stats Pill Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1F26) : const Color(0xFFF4F4F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E2E38) : const Color(0xFFE5E5EB),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('$_totalStock', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      const Text('Total Stock', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
                  Column(
                    children: [
                      Text(
                        '$_reservedCount',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _reservedCount > 0 ? Colors.amber.shade800 : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text('Reserved Hold', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Container(width: 1, height: 24, color: Colors.grey.withValues(alpha: 0.3)),
                  Column(
                    children: [
                      Text(
                        '$available',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: available > 0 ? const Color(0xFF2E7D32) : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text('Available', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Reconcile Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TeknoyTheme.citMaroon.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TeknoyTheme.citMaroon.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sync_problem_rounded, color: TeknoyTheme.citMaroon, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Got orphaned holds? Reconcile syncs reserved count with real active orders.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isReconciling ? null : () => _reconcile(showFeedback: true),
                    icon: _isReconciling
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.auto_fix_high_rounded, size: 14),
                    label: const Text(
                      'Reconcile',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TeknoyTheme.citMaroon,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
                : _orders.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 48,
                                color: Colors.green.shade400,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'No Active Orders Holding Stock',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _reservedCount > 0
                                    ? 'There are $_reservedCount orphaned reservations from test runs. Tap "Reconcile" above to clear them.'
                                    : 'All $_totalStock physical units are available for immediate checkout.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final o = _orders[i];
                          final orderId = o['order_id']?.toString() ?? '';
                          final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
                          final qty = (o['quantity'] as num?)?.toInt() ?? 1;
                          final status = o['status']?.toString() ?? 'PLACED';
                          final buyerName = o['buyer_name']?.toString() ?? 'Buyer';
                          final createdAt = o['created_at'] != null
                              ? DateTime.tryParse(o['created_at'].toString())
                              : null;
                          final dateStr = createdAt != null
                              ? '${createdAt.month}/${createdAt.day} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
                              : '';

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B1B20) : const Color(0xFFFAFAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2B2B34) : const Color(0xFFEEEEF2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade800, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '#$shortId',
                                            style: const TextStyle(
                                              fontFamily: 'Outfit',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              status,
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.amber.shade800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Buyer: $buyerName • $qty unit${qty > 1 ? 's' : ''} held',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                      if (dateStr.isNotEmpty)
                                        Text(
                                          'Placed: $dateStr',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 10,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _cancellingOrderId != null ? null : () => _cancelOrder(orderId),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: _cancellingOrderId == orderId
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                                        )
                                      : const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
