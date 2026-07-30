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
            category_id,
            product_images (image_url, is_primary),
            product_variants (
              variant_id,
              inventory (
                stock_qty
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
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item['status'] == 'ACTIVE' 
                                          ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1)) 
                                          : (isDark ? Colors.orange.withOpacity(0.15) : Colors.orange.withOpacity(0.1)),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: item['status'] == 'ACTIVE' 
                                            ? Colors.green.withOpacity(0.3) 
                                            : Colors.orange.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      item['status'] ?? 'PENDING',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: item['status'] == 'ACTIVE' ? Colors.green : Colors.orange),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Builder(
                                    builder: (context) {
                                      final variants = item['product_variants'] as List<dynamic>? ?? [];
                                      int stock = 0;
                                      if (variants.isNotEmpty) {
                                        final inv = variants[0]['inventory'];
                                        if (inv is List && inv.isNotEmpty) {
                                          stock = inv[0]['stock_qty'] ?? 0;
                                        } else if (inv is Map) {
                                          stock = inv['stock_qty'] ?? 0;
                                        }
                                      }
                                      return Row(
                                        children: [
                                          Icon(Icons.inventory_2_outlined, size: 14, color: isDark ? Colors.white54 : Colors.black54),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$stock in stock', 
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87)
                                          ),
                                        ],
                                      );
                                    }
                                  ),
                                ],
                              ),
                            ],
                          ),
                        trailing: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
                          onSelected: (value) {
                            if (value == 'toggle') {
                              _toggleStatus(item['product_id'], item['status']);
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
