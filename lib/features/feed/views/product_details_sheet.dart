import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/checkout/views/checkout_view.dart';

import 'package:teknoycart/core/supabase_client.dart';

/// Relational Bottom Sheet displaying detailed information about a selected product.
/// Implements standard P2P cash agreements and price negotiation features.
class ProductDetailsSheet extends ConsumerWidget {
  final Product product;

  const ProductDetailsSheet({
    super.key,
    required this.product,
  });

  /// Helper to fetch real seller name dynamically from the users table
  Future<String> _getSellerName(String sellerId) async {
    try {
      final res = await SupabaseConfig.client
          .from('users')
          .select('full_name')
          .eq('user_id', sellerId)
          .single();
      return res['full_name'] as String? ?? 'Wildcat Student Seller';
    } catch (e) {
      return 'Wildcat Student Seller';
    }
  }

  /// Helper to fetch available stock info
  Future<Map<String, int>> _getInventoryStatus(String productId) async {
    try {
      final client = SupabaseConfig.client;
      final variants = await client
          .from('product_variants')
          .select('variant_id')
          .eq('product_id', productId)
          .limit(1);

      if ((variants as List).isEmpty) {
        return {'stock': 0, 'reserved': 0, 'available': 0};
      }

      final String variantId = variants[0]['variant_id'] as String;

      final inventoryRecord = await client
          .from('inventory')
          .select('stock_qty, reserved_qty')
          .eq('variant_id', variantId)
          .maybeSingle();

      if (inventoryRecord != null) {
        final int stock = inventoryRecord['stock_qty'] as int? ?? 0;
        final int reserved = inventoryRecord['reserved_qty'] as int? ?? 0;
        return {
          'stock': stock,
          'reserved': reserved,
          'available': stock - reserved,
        };
      }
    } catch (e) {
      // ignore
    }
    return {'stock': 0, 'reserved': 0, 'available': 0};
  }

  /// Displays the sheet programmatically with a modern modal design
  static void show(BuildContext context, Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ProductDetailsSheet(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isMyProduct = currentUser?.id == product.sellerId;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F12) : const Color(0xFFF9F9FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Indicator Bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 14, bottom: 10),
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2D2D36) : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),

          // Product Image & Exit Button with Hero Transition
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: 'product_image_${product.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(product.imageUrl ?? ''),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                // Soft elegant overlay gradient on image
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.55),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Detailed Specifications & Dynamic Actions
          Expanded(
            flex: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Scrollable Product Information
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category & Condition Tags
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: TeknoyTheme.citMaroon.withOpacity(isDark ? 0.15 : 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: TeknoyTheme.citMaroon.withOpacity(0.2)),
                                ),
                                child: Text(
                                  product.category.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: TeknoyTheme.citMaroon,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: TeknoyTheme.citGold.withOpacity(isDark ? 0.15 : 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: TeknoyTheme.citGold.withOpacity(0.2)),
                                ),
                                child: Text(
                                  product.condition.toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: TeknoyTheme.citGold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              FutureBuilder<Map<String, int>>(
                                future: _getInventoryStatus(product.id),
                                builder: (context, snapshot) {
                                  final inv = snapshot.data ?? {'stock': 0, 'reserved': 0, 'available': 0};
                                  final available = inv['available'] ?? 0;
                                  final isOutOfStock = available <= 0;
                                  
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock 
                                          ? Colors.red.withOpacity(isDark ? 0.15 : 0.08)
                                          : Colors.green.withOpacity(isDark ? 0.15 : 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isOutOfStock
                                            ? Colors.red.withOpacity(0.3)
                                            : Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      isOutOfStock 
                                          ? 'OUT OF STOCK (RESERVABLE)' 
                                          : '$available IN STOCK',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isOutOfStock ? Colors.red : Colors.green,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Title & Price Info (State of the art layout)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product.title,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '₱${product.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: TeknoyTheme.citMaroon,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Product Description
                          Text(
                            product.description,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),

                  // 2. Sticky Action & Seller Info Deck (Sticky at bottom)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // P2P Seller Card details with high-trust indicators
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141418) : Colors.white,
                          border: Border.all(
                            color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: TeknoyTheme.kElevationLow,
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: TeknoyTheme.citMaroon,
                              radius: 20,
                              child: Icon(Icons.person_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FutureBuilder<String>(
                                    future: _getSellerName(product.sellerId),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.data ?? 'Wildcat Student Seller',
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                                  ),
                                  const Text(
                                    'Verified Student Account',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.verified_user_rounded, color: Colors.green, size: 12),
                                  SizedBox(width: 4),
                                  Text(
                                    '98% TRUST',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Action Button Deck
                      Row(
                        children: [
                          if (isMyProduct)
                            Expanded(
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: TeknoyTheme.citMaroon.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: TeknoyTheme.citMaroon.withOpacity(0.15)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.info_outline_rounded, color: TeknoyTheme.citMaroon, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      'This is your own product listing.',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold,
                                        color: TeknoyTheme.citMaroon,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final buyerId = ref.read(authStateProvider).valueOrNull?.id;
                                  if (buyerId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please log in to negotiate with the seller.')),
                                    );
                                    return;
                                  }

                                  if (buyerId == product.sellerId) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('You cannot start a negotiation chat on your own product.')),
                                    );
                                    return;
                                  }

                                  // Show micro-loading dialog
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => const Center(
                                      child: CircularProgressIndicator(color: TeknoyTheme.citMaroon),
                                    ),
                                  );

                                  try {
                                    final chatService = ref.read(chatServiceProvider);
                                    final roomId = await chatService.getOrCreateChatRoom(
                                      buyerId: buyerId,
                                      sellerId: product.sellerId,
                                      productId: product.id,
                                    );

                                    Navigator.pop(context); // close loader
                                    Navigator.pop(context); // close sheet

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ChatView(
                                          product: product,
                                          roomId: roomId,
                                        ),
                                      ),
                                    );
                                  } catch (e) {
                                    Navigator.pop(context); // close loader
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to initialize chat: $e')),
                                    );
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: TeknoyTheme.citMaroon, width: 1.5),
                                  foregroundColor: TeknoyTheme.citMaroon,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, size: 18),
                                    SizedBox(width: 8),
                                    Text('Chat Seller', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutView(
                                        product: product,
                                        agreedPrice: product.price,
                                        isDirectBuy: true,
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: TeknoyTheme.citMaroon,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  elevation: 0,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_cart_checkout_rounded, size: 18, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text('Buy Now', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
