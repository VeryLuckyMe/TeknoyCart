import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/providers/product_provider.dart';
import 'package:teknoycart/features/feed/views/edit_product_view.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';
import 'widgets/reserved_orders_sheet.dart';

class ManageListingsView extends ConsumerStatefulWidget {
  final bool embedded;
  const ManageListingsView({super.key, this.embedded = false});

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

  Future<void> _fetchListings({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      
      final response = await SupabaseConfig.client
          .from('products')
          .select('''
            product_id,
            name,
            description,
            base_price,
            status,
            is_preorder_enabled,
            category_id,
            category_attributes,
            product_images (image_url, is_primary),
            product_variants (
              variant_id,
              variant_name,
              variant_value,
              inventory (
                stock_qty,
                reserved_qty
              )
            )
          ''')
          .eq('seller_id', user.id)
          .order('created_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _listings = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Failed to load listings: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _toggleStatus(String productId, String currentStatus) async {
    final newStatus = currentStatus == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE';
    try {
      await SupabaseConfig.client
          .from('products')
          .update({'status': newStatus})
          .eq('product_id', productId);
      _fetchListings(silent: true);
      ref.read(productsListNotifierProvider.notifier).refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dCtx, true), 
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
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
      ref.read(productsListNotifierProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Product deleted successfully'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Failed to delete product: $e')),
        );
      }
    }
  }

  Future<void> _showEditProductSheet(Map<String, dynamic> item) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductView(productItem: item),
      ),
    );
    if (updated == true) {
      _fetchListings(silent: true);
    }
  }

  void _showReservedOrdersSheet({
    required String variantId,
    required String productName,
    required int initialReservedQty,
    required int stockQty,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReservedOrdersSheet(
        variantId: variantId,
        productName: productName,
        initialReservedQty: initialReservedQty,
        stockQty: stockQty,
        onInventoryUpdated: () => _fetchListings(silent: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
        : _listings.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'You have no listings yet.',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'List items to see them here and manage your campus inventory.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                color: TeknoyTheme.citMaroon,
                onRefresh: () => _fetchListings(silent: true),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _listings.length,
                  itemBuilder: (context, index) {
                    final item = _listings[index];
                    final images = item['product_images'] as List<dynamic>? ?? [];
                    final String imageUrl;
                    if (images.isNotEmpty) {
                      final primary = images.firstWhere(
                        (img) => img is Map && img['is_primary'] == true,
                        orElse: () => images.first,
                      );
                      imageUrl = primary is Map ? (primary['image_url']?.toString() ?? '') : '';
                    } else {
                      imageUrl = '';
                    }

                    // Extract variants & aggregate inventory
                    final variants = item['product_variants'] as List<dynamic>? ?? [];
                    int totalStockQty = 0;
                    int totalReservedQty = 0;
                    String? primaryVariantId;
                    if (variants.isNotEmpty && variants[0] is Map) {
                      primaryVariantId = (variants[0] as Map<String, dynamic>)['variant_id']?.toString();
                    }
                    for (final v in variants) {
                      if (v is Map) {
                        final inv = v['inventory'];
                        if (inv is List && inv.isNotEmpty && inv[0] is Map) {
                          totalStockQty += (inv[0]['stock_qty'] as num?)?.toInt() ?? 0;
                          totalReservedQty += (inv[0]['reserved_qty'] as num?)?.toInt() ?? 0;
                        } else if (inv is Map) {
                          totalStockQty += (inv['stock_qty'] as num?)?.toInt() ?? 0;
                          totalReservedQty += (inv['reserved_qty'] as num?)?.toInt() ?? 0;
                        }
                      }
                    }
                    final int available = (totalStockQty - totalReservedQty).clamp(0, 999999);
                    final bool isPreorder = item['is_preorder_enabled'] == true;
                    final bool hasMultipleVariants = variants.length > 1;
                        
                    return TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 500)),
                      curve: Curves.easeOutCubic,
                      tween: Tween<double>(begin: 0, end: 1),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 16 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child ?? const SizedBox.shrink(),
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
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(
                            color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            onTap: () => _showEditProductSheet(item),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          leading: imageUrl.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(imageUrl, width: 64, height: 64, fit: BoxFit.cover),
                                )
                              : Container(
                                  width: 64, height: 64, 
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1), 
                                    borderRadius: BorderRadius.circular(10)
                                  ),
                                  child: Icon(Icons.image_not_supported, color: isDark ? Colors.white30 : Colors.grey),
                                ),
                          title: Text(item['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Outfit', fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text('₱ ${item['base_price']}', style: const TextStyle(color: TeknoyTheme.citMaroon, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  // 1. Status Pill (ACTIVE / INACTIVE)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: item['status'] == 'ACTIVE' 
                                          ? (isDark ? Colors.green.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.1)) 
                                          : (isDark ? Colors.orange.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.1)),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: item['status'] == 'ACTIVE' 
                                            ? Colors.green.withValues(alpha: 0.3) 
                                            : Colors.orange.withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      item['status']?.toString() ?? 'PENDING',
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
                                        color: available > 0 ? const Color(0xFF2E7D32).withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.3),
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

                                  // 3. Total Physical Stock Pill
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isDark ? Colors.white12 : Colors.black12,
                                      ),
                                    ),
                                    child: Text(
                                      '$totalStockQty Total',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter',
                                        color: isDark ? Colors.white60 : Colors.black87,
                                      ),
                                    ),
                                  ),

                                  // 4. Multiple Variants Pill (Clickable to inspect / adjust variants)
                                  if (hasMultipleVariants)
                                    InkWell(
                                      onTap: () => _showEditProductSheet(item),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFEEF2F6),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark ? Colors.blueGrey.shade700 : Colors.blueGrey.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.tune_rounded, size: 11, color: isDark ? Colors.lightBlueAccent : Colors.blueGrey.shade800),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${variants.length} Variants',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Inter',
                                                color: isDark ? Colors.lightBlueAccent : Colors.blueGrey.shade800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  // 5. Interactive Reserved Pill (Clickable to inspect holds & reconcile)
                                  if (totalReservedQty > 0)
                                    InkWell(
                                      onTap: (primaryVariantId != null && primaryVariantId.isNotEmpty)
                                          ? () => _showReservedOrdersSheet(
                                                variantId: primaryVariantId!,
                                                productName: item['name']?.toString() ?? 'Product',
                                                initialReservedQty: totalReservedQty,
                                                stockQty: totalStockQty,
                                              )
                                          : null,
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF362810) : const Color(0xFFFFF8E1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.hourglass_top_rounded, size: 11, color: Colors.amber.shade900),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$totalReservedQty Reserved',
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

                                  // 6. Pre-Order Tag
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
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditProductSheet(item);
                              } else if (value == 'toggle') {
                                _toggleStatus(item['product_id']?.toString() ?? '', item['status']?.toString() ?? '');
                              } else if (value == 'delete') {
                                final pId = item['product_id']?.toString() ?? '';
                                if (pId.isNotEmpty) _deleteProduct(pId);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_note_rounded, color: TeknoyTheme.citMaroon, size: 20),
                                    SizedBox(width: 8),
                                    Text('Edit Product Details', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'toggle',
                                child: Row(
                                  children: [
                                    Icon(item['status'] == 'ACTIVE' ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                    const SizedBox(width: 8),
                                    Text(item['status'] == 'ACTIVE' ? 'Hide Listing' : 'Make Active'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('Delete Listing', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  },
                ),
              );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage My Listings', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: isDark ? const Color(0xFF0F0A0A) : Colors.white,
        centerTitle: true,
      ),
      body: content,
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
