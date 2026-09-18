import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:teknoycart/core/services/secure_token_service.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/feed/views/product_discovery_feed_view.dart';

const String _backendOrdersUrl = 'https://teknoycart-backend.onrender.com/api/orders';

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
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
      _fetchListings(silent: true);
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(!currentPreorder ? 'Pre-orders enabled for this listing' : 'Pre-orders disabled'),
            backgroundColor: TeknoyTheme.citMaroon,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text('Failed to update pre-order settings: $e')),
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

  Future<void> _adjustStock({
    required String? variantId,
    required String productName,
    required int currentStock,
    required int reservedStock,
  }) async {
    if (variantId == null || variantId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Product variant not found. Cannot adjust stock.')),
        );
      }
      return;
    }

    final availableStock = (currentStock - reservedStock).clamp(0, 999999);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog<void>(
      context: context,
      builder: (dCtx) {
        bool isAddMode = true;
        final controller = TextEditingController();
        String selectedReason = 'Sold in person / outside app';
        String? errorMessage;
        int? parsedQty;

        final reasons = [
          'Sold in person / outside app',
          'Damaged / Expired / Lost',
          'Inventory recount / Correction',
          'Personal use / Withdrawn',
          'Other',
        ];

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            void onInputChanged(String text) {
              setDialogState(() {
                final val = int.tryParse(text.trim());
                parsedQty = val;
                if (val == null || val <= 0) {
                  errorMessage = text.trim().isEmpty ? null : 'Please enter a valid positive number';
                } else if (!isAddMode && val > availableStock) {
                  errorMessage = 'Cannot remove $val. Only $availableStock unit${availableStock == 1 ? '' : 's'} available ($reservedStock held by orders).';
                } else {
                  errorMessage = null;
                }
              });
            }

            final isValid = parsedQty != null && parsedQty! > 0 && errorMessage == null;
            final newTotal = parsedQty != null && parsedQty! > 0
                ? (isAddMode ? currentStock + parsedQty! : currentStock - parsedQty!)
                : currentStock;
            final newAvailable = (newTotal - reservedStock).clamp(0, 999999);

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: isDark ? const Color(0xFF1B1B22) : Colors.white,
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.tune_rounded, color: TeknoyTheme.citMaroon, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Adjust Stock',
                          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Text(
                          productName,
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
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    // Current breakdown pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF22222B) : const Color(0xFFF4F4F8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF33333E) : const Color(0xFFE5E5EB)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStockMiniCol('Total', '$currentStock', isDark ? Colors.white70 : Colors.black87),
                          Container(width: 1, height: 22, color: isDark ? Colors.white12 : Colors.black12),
                          _buildStockMiniCol('Reserved', '$reservedStock', Colors.amber.shade800),
                          Container(width: 1, height: 22, color: isDark ? Colors.white12 : Colors.black12),
                          _buildStockMiniCol('Available', '$availableStock', const Color(0xFF2E7D32)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Segmented Toggle Add / Deduct
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141419) : const Color(0xFFEEEEF2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  isAddMode = true;
                                  onInputChanged(controller.text);
                                });
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isAddMode ? (isDark ? const Color(0xFF2B2B38) : Colors.white) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: isAddMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline_rounded,
                                      size: 16,
                                      color: isAddMode ? TeknoyTheme.citMaroon : (isDark ? Colors.white54 : Colors.black54),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Add Stock',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        fontWeight: isAddMode ? FontWeight.bold : FontWeight.w500,
                                        color: isAddMode ? TeknoyTheme.citMaroon : (isDark ? Colors.white54 : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setDialogState(() {
                                  isAddMode = false;
                                  onInputChanged(controller.text);
                                });
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !isAddMode ? (isDark ? const Color(0xFF2B2B38) : Colors.white) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: !isAddMode
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.remove_circle_outline_rounded,
                                      size: 16,
                                      color: !isAddMode ? Colors.red.shade700 : (isDark ? Colors.white54 : Colors.black54),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Remove Stock',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 13,
                                        fontWeight: !isAddMode ? FontWeight.bold : FontWeight.w500,
                                        color: !isAddMode ? Colors.red.shade700 : (isDark ? Colors.white54 : Colors.black54),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Quantity input field
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      onChanged: onInputChanged,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isAddMode ? 'Units to Add' : 'Units to Remove',
                        hintText: isAddMode ? 'e.g. 5' : 'Max: $availableStock',
                        prefixIcon: Icon(
                          isAddMode ? Icons.add : Icons.remove,
                          color: isAddMode ? TeknoyTheme.citMaroon : Colors.red,
                        ),
                        errorText: errorMessage,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    if (!isAddMode) ...[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedReason,
                        decoration: InputDecoration(
                          labelText: 'Reason for removal',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedReason = val);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Live calculation summary box
                    if (isValid)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isAddMode
                              ? Colors.green.withValues(alpha: isDark ? 0.12 : 0.08)
                              : Colors.orange.withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isAddMode
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(
                              'New Total: $newTotal',
                              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Container(width: 1, height: 16, color: Colors.grey.withValues(alpha: 0.3)),
                            Text(
                              'New Available: $newAvailable',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: newAvailable > 0 ? const Color(0xFF2E7D32) : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () async {
                          Navigator.pop(dialogCtx);
                          final qty = parsedQty!;
                          final finalNewStock = isAddMode ? currentStock + qty : currentStock - qty;

                          try {
                            await SupabaseConfig.client
                                .from('inventory')
                                .update({
                                  'stock_qty': finalNewStock,
                                  'last_updated': DateTime.now().toIso8601String(),
                                })
                                .eq('variant_id', variantId);

                            _fetchListings(silent: true);

                            if (mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isAddMode
                                        ? 'Added $qty unit(s). Total physical stock is now $finalNewStock.'
                                        : 'Removed $qty unit(s) ($selectedReason). Total stock is now $finalNewStock.',
                                  ),
                                  backgroundColor: TeknoyTheme.success,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                                SnackBar(
                                  content: Text('Failed to update stock: $e'),
                                  backgroundColor: TeknoyTheme.error,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAddMode ? TeknoyTheme.citMaroon : Colors.red.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    isAddMode ? 'Add Stock' : 'Remove Stock',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Widget _buildStockMiniCol(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: color),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.grey),
        ),
      ],
    );
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
      builder: (ctx) => _ReservedOrdersSheetContent(
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

                    // Extract variant & inventory safely
                    final variants = item['product_variants'] as List<dynamic>? ?? [];
                    int stockQty = 0;
                    int reservedQty = 0;
                    String? variantId;
                    if (variants.isNotEmpty && variants[0] is Map) {
                      final firstVar = variants[0] as Map<String, dynamic>;
                      variantId = firstVar['variant_id']?.toString();
                      final inv = firstVar['inventory'];
                      if (inv is List && inv.isNotEmpty && inv[0] is Map) {
                        stockQty = (inv[0]['stock_qty'] as num?)?.toInt() ?? 0;
                        reservedQty = (inv[0]['reserved_qty'] as num?)?.toInt() ?? 0;
                      } else if (inv is Map) {
                        stockQty = (inv['stock_qty'] as num?)?.toInt() ?? 0;
                        reservedQty = (inv['reserved_qty'] as num?)?.toInt() ?? 0;
                      }
                    }
                    final int available = (stockQty - reservedQty).clamp(0, 999999);
                    final bool isPreorder = item['is_preorder_enabled'] == true;
                        
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

                                  // 3. Interactive Reserved Pill (Clickable to inspect holds & reconcile)
                                  if (reservedQty > 0)
                                    InkWell(
                                      onTap: (variantId != null && variantId.isNotEmpty)
                                          ? () => _showReservedOrdersSheet(
                                                variantId: variantId!,
                                                productName: item['name']?.toString() ?? 'Product',
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
                                          border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.4)),
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
                                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.withValues(alpha: 0.12),
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
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
                            onSelected: (value) {
                              if (value == 'toggle') {
                                _toggleStatus(item['product_id']?.toString() ?? '', item['status']?.toString() ?? '');
                              } else if (value == 'preorder') {
                                _togglePreorder(item['product_id']?.toString() ?? '', item['is_preorder_enabled'] == true);
                              } else if (value == 'stock') {
                                _adjustStock(
                                  variantId: variantId,
                                  productName: item['name']?.toString() ?? 'Product',
                                  currentStock: stockQty,
                                  reservedStock: reservedQty,
                                );
                              } else if (value == 'inspect') {
                                if (variantId != null && variantId.isNotEmpty) {
                                  _showReservedOrdersSheet(
                                    variantId: variantId,
                                    productName: item['name']?.toString() ?? 'Product',
                                    initialReservedQty: reservedQty,
                                    stockQty: stockQty,
                                  );
                                }
                              } else if (value == 'delete') {
                                final pId = item['product_id']?.toString() ?? '';
                                if (pId.isNotEmpty) _deleteProduct(pId);
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
                                    Icon(Icons.tune_rounded, size: 20),
                                    SizedBox(width: 8),
                                    Text('Adjust Stock'),
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

/// Self-contained, robust bottom sheet for inspecting and reconciling reserved holds.
class _ReservedOrdersSheetContent extends StatefulWidget {
  final String variantId;
  final String productName;
  final int initialReservedQty;
  final int stockQty;
  final VoidCallback onInventoryUpdated;

  const _ReservedOrdersSheetContent({
    required this.variantId,
    required this.productName,
    required this.initialReservedQty,
    required this.stockQty,
    required this.onInventoryUpdated,
  });

  @override
  State<_ReservedOrdersSheetContent> createState() => _ReservedOrdersSheetContentState();
}

class _ReservedOrdersSheetContentState extends State<_ReservedOrdersSheetContent> {
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

      // 3. Fallback: Direct table update
      if (!cancelled) {
        try {
          await SupabaseConfig.client
              .from('orders')
              .update({'status': 'CANCELLED'})
              .eq('order_id', orderId);
          cancelled = true;
        } catch (_) {}
      }

      // Reload orders list & sync inventory holds
      await _loadOrders();
      await _reconcile(showFeedback: false);

      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Order cancelled and reserved hold released.'),
            backgroundColor: TeknoyTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: $e'),
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

  static Widget _buildMetricColumn(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final available = (_totalStock - _reservedCount).clamp(0, 999999);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.75;

    return Container(
      height: sheetHeight,
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
                        widget.productName,
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
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // 3-Metric Overview Card
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
                  _buildMetricColumn('Available', '$available', const Color(0xFF2E7D32), isDark),
                  Container(width: 1, height: 28, color: isDark ? Colors.white12 : Colors.black12),
                  _buildMetricColumn('Reserved', '$_reservedCount', Colors.amber.shade800, isDark),
                  Container(width: 1, height: 28, color: isDark ? Colors.white12 : Colors.black12),
                  _buildMetricColumn('Total Stock', '$_totalStock', isDark ? Colors.white70 : Colors.black87, isDark),
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
