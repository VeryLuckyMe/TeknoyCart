import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';

class ManageListingsView extends ConsumerStatefulWidget {
  const ManageListingsView({super.key});

  @override
  ConsumerState<ManageListingsView> createState() => _ManageListingsViewState();
}

class _ManageListingsViewState extends ConsumerState<ManageListingsView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _listings = [];

  @override
  void initState() {
    super.initState();
    _fetchListings();
  }

  Future<void> _fetchListings() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      
      final response = await SupabaseConfig.client
          .from('products')
          .select('''
            product_id,
            name,
            base_price,
            status,
            is_preorder_enabled,
            category_id,
            product_images (image_url, is_primary),
            product_variants (
              variant_id,
              inventory (
                stock_qty,
                reserved_qty
              )
            )
          ''')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);
          
      setState(() {
        _listings = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load listings: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _toggleStatus(String productId, String currentStatus) async {
    final newStatus = currentStatus == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await SupabaseConfig.client
          .from('products')
          .update({'status': newStatus})
          .eq('product_id', productId);
      _fetchListings();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _togglePreorder(String productId, bool currentPreorder) async {
    try {
      await SupabaseConfig.client
          .from('products')
          .update({'is_preorder_enabled': !currentPreorder})
          .eq('product_id', productId);
      _fetchListings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(!currentPreorder ? 'Pre-orders enabled for this listing' : 'Pre-orders disabled'),
            backgroundColor: TeknoyTheme.citMaroon,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update pre-order settings: $e')),
        );
      }
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      )
    ) ?? false;

    if (!confirm) return;

    try {
      await SupabaseConfig.client
          .from('products')
          .delete()
          .eq('product_id', productId);
      _fetchListings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product deleted successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete product: $e')));
      }
    }
  }

  Future<void> _addStock(String? variantId, int currentStock) async {
    if (variantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product variant not found. Cannot add stock.')),
      );
      return;
    }

    final controller = TextEditingController();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Stock'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Amount to add (Current: $currentStock)', border: const OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Add')
          ),
        ],
      )
    ) ?? false;

    if (!confirm) return;
    
    final amountToAdd = int.tryParse(controller.text.trim());
    if (amountToAdd == null || amountToAdd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount to add.')),
      );
      return;
    }

    try {
      final newStock = currentStock + amountToAdd;
      await SupabaseConfig.client
          .from('inventory')
          .update({'stock_qty': newStock})
          .eq('variant_id', variantId);
      _fetchListings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock added successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add stock: $e')));
      }
    }
  }

  Future<void> _showReservedOrdersSheet({
    required BuildContext context,
    required String variantId,
    required String productName,
    required int initialReservedQty,
    required int stockQty,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        int reservedCount = initialReservedQty;
        int totalStock = stockQty;
        bool isLoading = true;
        bool isReconciling = false;
        List<Map<String, dynamic>> orders = [];

        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> loadOrders() async {
              try {
                final res = await SupabaseConfig.client
                    .from('orders')
                    .select('order_id, quantity, status, created_at, buyer_id, total_amount')
                    .eq('variant_id', variantId)
                    .inFilter('status', [
                      'PLACED', 'ACCEPTED', 'PAYMENT_SUBMITTED', 'PAYMENT_VERIFIED',
                      'MEETUP_SCHEDULED', 'NEEDS_REVIEW', 'REFUND_REQUESTED'
                    ])
                    .order('created_at', ascending: false);

                final List<Map<String, dynamic>> enriched = [];
                for (final item in (res as List)) {
                  final m = Map<String, dynamic>.from(item);
                  try {
                    final u = await SupabaseConfig.client
                        .from('users')
                        .select('full_name, email')
                        .eq('user_id', m['buyer_id'])
                        .maybeSingle();
                    m['buyer_name'] = u?['full_name'] ?? 'Buyer';
                    m['buyer_email'] = u?['email'] ?? '';
                  } catch (_) {
                    m['buyer_name'] = 'Buyer';
                    m['buyer_email'] = '';
                  }
                  enriched.add(m);
                }

                if (sheetContext.mounted) {
                  setSheetState(() {
                    orders = enriched;
                    isLoading = false;
                  });
                }
              } catch (_) {
                if (sheetContext.mounted) {
                  setSheetState(() => isLoading = false);
                }
              }
            }

            if (isLoading && orders.isEmpty) {
              loadOrders();
            }

            Future<void> reconcile() async {
              setSheetState(() => isReconciling = true);
              try {
                int actualReserved = 0;
                try {
                  final rpcRes = await SupabaseConfig.client.rpc(
                    'reconcile_inventory_holds',
                    params: {'p_variant_id': variantId},
                  );
                  if (rpcRes is Map && rpcRes['reserved_qty'] != null) {
                    actualReserved = (rpcRes['reserved_qty'] as num).toInt();
                    if (rpcRes['stock_qty'] != null) {
                      totalStock = (rpcRes['stock_qty'] as num).toInt();
                    }
                  }
                } catch (_) {
                  // Direct ground-truth active orders sum fallback
                  for (final o in orders) {
                    actualReserved += (o['quantity'] as num? ?? 0).toInt();
                  }
                  await SupabaseConfig.client
                      .from('inventory')
                      .update({
                        'reserved_qty': actualReserved,
                        'last_updated': DateTime.now().toIso8601String(),
                      })
                      .eq('variant_id', variantId);
                }

                reservedCount = actualReserved;
                await _fetchListings();
                if (sheetContext.mounted) {
                  setSheetState(() => isReconciling = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reconciled holds! Reserved is now $actualReserved (Available: ${(totalStock - actualReserved).clamp(0, 999999)}).'),
                      backgroundColor: TeknoyTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (sheetContext.mounted) {
                  setSheetState(() => isReconciling = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to reconcile: $e'), backgroundColor: TeknoyTheme.error),
                  );
                }
              }
            }

            Future<void> cancelOrder(String orderId) async {
              final confirm = await showDialog<bool>(
                context: sheetContext,
                builder: (dCtx) => AlertDialog(
                  title: const Text('Cancel In-Flight Order?'),
                  content: const Text(
                    'Cancelling this order will release its reserved stock hold immediately back to Available inventory.',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Keep Order')),
                    TextButton(
                      onPressed: () => Navigator.pop(dCtx, true),
                      child: const Text('Cancel Order', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm != true) return;

              try {
                await SupabaseConfig.client
                    .from('orders')
                    .update({'status': 'CANCELLED'})
                    .eq('order_id', orderId);

                await loadOrders();
                await reconcile();
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Order cancelled and reserved hold released.')),
                  );
                }
              } catch (e) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to cancel order: $e')),
                  );
                }
              }
            }

            final available = (totalStock - reservedCount).clamp(0, 999999);

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141418) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reserved Stock Inspector',
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C22) : const Color(0xFFF6F6F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C2C35) : const Color(0xFFE5E5EA),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMetricColumn('Available', '$available', Colors.green, isDark),
                          Container(width: 1, height: 28, color: isDark ? Colors.white12 : Colors.black12),
                          _buildMetricColumn('Reserved', '$reservedCount', Colors.amber.shade800, isDark),
                          Container(width: 1, height: 28, color: isDark ? Colors.white12 : Colors.black12),
                          _buildMetricColumn('Total Stock', '$totalStock', isDark ? Colors.white70 : Colors.black87, isDark),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TeknoyTheme.citMaroon.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: TeknoyTheme.citMaroon.withOpacity(0.15)),
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
                            onPressed: isReconciling ? null : reconcile,
                            icon: isReconciling
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
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
                        : orders.isEmpty
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
                                        reservedCount > 0
                                            ? 'There are $reservedCount orphaned reservations from test runs. Tap "Reconcile" above to clear them.'
                                            : 'All $totalStock physical units are available for immediate checkout.',
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
                                itemCount: orders.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (context, i) {
                                  final o = orders[i];
                                  final orderId = o['order_id']?.toString() ?? '';
                                  final shortId = orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId;
                                  final qty = o['quantity'] ?? 1;
                                  final status = o['status'] ?? 'PLACED';
                                  final buyerName = o['buyer_name'] ?? 'Buyer';
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
                                            color: Colors.amber.shade700.withOpacity(0.12),
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
                                                      color: Colors.amber.withOpacity(0.15),
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
                                          onPressed: () => cancelOrder(orderId),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.red,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
          },
        );
      },
    );
  }

  static Widget _buildMetricColumn(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage My Listings', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF0F0A0A) : Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
          : _listings.isEmpty
              ? const Center(child: Text('You have no listings yet.', style: TextStyle(fontFamily: 'Inter')))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _listings.length,
                  itemBuilder: (context, index) {
                    final item = _listings[index];
                    final images = item['product_images'] as List<dynamic>? ?? [];
                    final imageUrl = images.isNotEmpty 
                        ? (images.firstWhere((img) => img['is_primary'] == true, orElse: () => images[0])['image_url'] as String? ?? '')
                        : '';
                        
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 16 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141418) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          leading: imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(imageUrl, width: 64, height: 64, fit: BoxFit.cover),
                                )
                              : Container(
                                  width: 64, height: 64, 
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1), 
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  child: Icon(Icons.image_not_supported, color: isDark ? Colors.white30 : Colors.grey),
                                ),
                          title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Outfit', fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text('₱ ${item['base_price']}', style: const TextStyle(color: TeknoyTheme.citMaroon, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final variants = item['product_variants'] as List<dynamic>? ?? [];
                                  int stockQty = 0;
                                  int reservedQty = 0;
                                  String? variantId;
                                  if (variants.isNotEmpty) {
                                    variantId = variants[0]['variant_id']?.toString();
                                    final inv = variants[0]['inventory'];
                                    if (inv is List && inv.isNotEmpty) {
                                      stockQty = inv[0]['stock_qty'] ?? 0;
                                      reservedQty = inv[0]['reserved_qty'] ?? 0;
                                    } else if (inv is Map) {
                                      stockQty = inv['stock_qty'] ?? 0;
                                      reservedQty = inv['reserved_qty'] ?? 0;
                                    }
                                  }
                                  final int available = (stockQty - reservedQty).clamp(0, 999999);
                                  final bool isPreorder = item['is_preorder_enabled'] == true;

                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      // 1. Status Pill (ACTIVE / INACTIVE)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: item['status'] == 'ACTIVE' 
                                              ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1)) 
                                              : (isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.withOpacity(0.1)),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: item['status'] == 'ACTIVE' 
                                                ? Colors.green.withOpacity(0.3) 
                                                : Colors.orange.withOpacity(0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          item['status'] ?? 'PENDING',
                                          style: TextStyle(
                                            fontSize: 9, 
                                            fontWeight: FontWeight.w800, 
                                            letterSpacing: 0.5, 
                                            color: item['status'] == 'ACTIVE' ? Colors.green : Colors.orange
                                          ),
                                        ),
                                      ),

                                      // 2. Available Stock Split Pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: available > 0 
                                              ? (isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9))
                                              : (isDark ? const Color(0xFF38231B) : const Color(0xFFFFEBEE)),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: available > 0 ? const Color(0xFF2E7D32).withOpacity(0.4) : Colors.red.withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              available > 0 ? Icons.check_circle_outline_rounded : Icons.cancel_outlined, 
                                              size: 11, 
                                              color: available > 0 ? const Color(0xFF2E7D32) : Colors.red
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$available Available',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Inter',
                                                color: available > 0 ? const Color(0xFF2E7D32) : Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // 3. Interactive Reserved Pill (Clickable to inspect holds & reconcile)
                                      if (reservedQty > 0)
                                        InkWell(
                                          onTap: variantId != null
                                              ? () => _showReservedOrdersSheet(
                                                    context: context,
                                                    variantId: variantId!,
                                                    productName: item['name'] ?? 'Product',
                                                    initialReservedQty: reservedQty,
                                                    stockQty: stockQty,
                                                  )
                                              : null,
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF362810) : const Color(0xFFFFF8E1),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.amber.shade700.withOpacity(0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.hourglass_top_rounded, size: 11, color: Colors.amber.shade900),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$reservedQty Reserved',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    fontFamily: 'Inter',
                                                    color: Colors.amber.shade900,
                                                  ),
                                                ),
                                                const SizedBox(width: 3),
                                                Icon(Icons.info_outline_rounded, size: 11, color: Colors.amber.shade900),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // 4. Total Physical Stock Pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white.withOpacity(0.06) : Colors.grey.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark ? Colors.white12 : Colors.black12,
                                          ),
                                        ),
                                        child: Text(
                                          '$stockQty Total',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                            color: isDark ? Colors.white60 : Colors.black87,
                                          ),
                                        ),
                                      ),

                                      // 5. Pre-Order Tag
                                      if (isPreorder)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF231B38) : const Color(0xFFEDE7F6),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: Colors.deepPurple.shade300),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.bolt_rounded, size: 12, color: Colors.deepPurple.shade700),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Pre-Order',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily: 'Inter',
                                                  color: Colors.deepPurple.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
                          onSelected: (value) {
                            if (value == 'toggle') {
                              _toggleStatus(item['product_id'], item['status']);
                            } else if (value == 'preorder') {
                              _togglePreorder(item['product_id'], item['is_preorder_enabled'] == true);
                            } else if (value == 'stock') {
                              final variants = item['product_variants'] as List<dynamic>? ?? [];
                              int stock = 0;
                              String? variantId;
                              if (variants.isNotEmpty) {
                                variantId = variants[0]['variant_id'];
                                final inv = variants[0]['inventory'];
                                if (inv is List && inv.isNotEmpty) {
                                  stock = inv[0]['stock_qty'] ?? 0;
                                } else if (inv is Map) {
                                  stock = inv['stock_qty'] ?? 0;
                                }
                              }
                              _addStock(variantId, stock);
                            } else if (value == 'inspect') {
                              final variants = item['product_variants'] as List<dynamic>? ?? [];
                              if (variants.isNotEmpty) {
                                final vId = variants[0]['variant_id']?.toString() ?? '';
                                int stock = 0;
                                int reserved = 0;
                                final inv = variants[0]['inventory'];
                                if (inv is List && inv.isNotEmpty) {
                                  stock = inv[0]['stock_qty'] ?? 0;
                                  reserved = inv[0]['reserved_qty'] ?? 0;
                                } else if (inv is Map) {
                                  stock = inv['stock_qty'] ?? 0;
                                  reserved = inv['reserved_qty'] ?? 0;
                                }
                                _showReservedOrdersSheet(
                                  context: context,
                                  variantId: vId,
                                  productName: item['name'] ?? 'Product',
                                  initialReservedQty: reserved,
                                  stockQty: stock,
                                );
                              }
                            } else if (value == 'delete') {
                              _deleteProduct(item['product_id']);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'toggle',
                              child: Row(
                                children: [
                                  Icon(item['status'] == 'ACTIVE' ? Icons.visibility_off : Icons.visibility, size: 20),
                                  const SizedBox(width: 8),
                                  Text(item['status'] == 'ACTIVE' ? 'Hide Listing' : 'Make Active'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'preorder',
                              child: Row(
                                children: [
                                  Icon(
                                    item['is_preorder_enabled'] == true ? Icons.layers_clear_outlined : Icons.layers_outlined, 
                                    size: 20, 
                                    color: Colors.deepPurple
                                  ),
                                  const SizedBox(width: 8),
                                  Text(item['is_preorder_enabled'] == true ? 'Disable Pre-Orders' : 'Enable Pre-Orders'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'stock',
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text('Add Stock'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'inspect',
                              child: Row(
                                children: [
                                  Icon(Icons.manage_search_rounded, size: 20, color: Colors.amber),
                                  SizedBox(width: 8),
                                  Text('Inspect Reservations'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete Listing', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductDiscoveryFeedView(initialTab: 2),
            ),
            (route) => false,
          );
        },
        backgroundColor: TeknoyTheme.citMaroon,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Product', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
