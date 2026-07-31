import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/checkout/views/checkout_view.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/feed/views/seller_storefront_view.dart';

import 'package:teknoycart/core/supabase_client.dart';

/// Relational Bottom Sheet displaying detailed information about a selected product.
/// Implements standard P2P cash agreements and price negotiation features.
class ProductDetailsSheet extends ConsumerStatefulWidget {
  final Product product;

  const ProductDetailsSheet({
    super.key,
    required this.product,
  });

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
  ConsumerState<ProductDetailsSheet> createState() => _ProductDetailsSheetState();
}

class _ProductDetailsSheetState extends ConsumerState<ProductDetailsSheet> {
  int _quantity = 1;
  Product get product => widget.product;

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
    // Fallback: If product/variant exists but no inventory record is found, default to available stock (e.g., 1)
    return {'stock': 1, 'reserved': 0, 'available': 1};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(authStateProvider).valueOrNull;
    final isMyProduct = currentUser?.id == widget.product.sellerId;
    
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
                                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'CHECKING STOCK...',
                                        style: TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.grey,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    );
                                  }

                                  final inv = snapshot.data ?? {'stock': 0, 'reserved': 0, 'available': 0};
                                  final available = inv['available'] ?? 0;
                                  final isOutOfStock = available <= 0;
                                  
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isOutOfStock
                                          ? Colors.amber.withOpacity(isDark ? 0.2 : 0.12)
                                          : Colors.green.withOpacity(isDark ? 0.15 : 0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isOutOfStock
                                            ? Colors.amber.withOpacity(0.5)
                                            : Colors.green.withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isOutOfStock) ...[
                                          const Icon(Icons.bookmark_add_rounded, size: 12, color: Color(0xFFD97706)),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          isOutOfStock 
                                              ? 'OUT OF STOCK (RESERVABLE)' 
                                              : '$available IN STOCK',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isOutOfStock ? const Color(0xFFD97706) : Colors.green,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Store Name Header (if available)
                          if (product.sellerStoreName != null && product.sellerStoreName!.trim().isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.storefront_rounded, size: 14, color: TeknoyTheme.citMaroon),
                                const SizedBox(width: 4),
                                Text(
                                  product.sellerStoreName!,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: TeknoyTheme.citMaroon,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],

                          // Title & Price Info (State of the art layout)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.product.title,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₱${(widget.product.price * _quantity).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: TeknoyTheme.citMaroon,
                                    ),
                                  ),
                                  if (_quantity > 1)
                                    Text(
                                      '₱${widget.product.price.toStringAsFixed(2)} each',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 11,
                                        color: isDark ? Colors.white54 : Colors.black45,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Quantity Selector Counter Deck
                          FutureBuilder<Map<String, int>>(
                            future: _getInventoryStatus(widget.product.id),
                            builder: (context, snapshot) {
                              final inv = snapshot.data ?? {'stock': 0, 'reserved': 0, 'available': 0};
                              final available = inv['available'] ?? 0;
                              final int maxAllowed = available > 0 ? available : 99;

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF141418) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
                                  ),
                                  boxShadow: TeknoyTheme.kElevationLow,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Select Quantity',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          available > 0 ? 'Max $available units' : 'Pre-order / Reservation',
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11,
                                            color: isDark ? Colors.white54 : Colors.black45,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1F1F26) : const Color(0xFFF4F4F7),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_rounded, size: 18),
                                            color: _quantity > 1 ? TeknoyTheme.citMaroon : Colors.grey,
                                            onPressed: _quantity > 1
                                                ? () => setState(() => _quantity--)
                                                : null,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            padding: EdgeInsets.zero,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                            child: Text(
                                              '$_quantity',
                                              style: const TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_rounded, size: 18),
                                            color: _quantity < maxAllowed ? TeknoyTheme.citMaroon : Colors.grey,
                                            onPressed: _quantity < maxAllowed
                                                ? () => setState(() => _quantity++)
                                                : null,
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
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
                      GestureDetector(
                        onTap: () async {
                          final sellerName = await _getSellerName(product.sellerId);
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SellerStorefrontView(
                                  sellerId: product.sellerId,
                                  sellerName: sellerName,
                                ),
                              ),
                            );
                          }
                        },
                        child: Container(
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
                                    if (product.sellerStoreName != null && product.sellerStoreName!.trim().isNotEmpty) ...[
                                      Text(
                                        product.sellerStoreName!,
                                        style: const TextStyle(
                                          fontFamily: 'Outfit',
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    FutureBuilder<String>(
                                      future: _getSellerName(product.sellerId),
                                      builder: (context, snapshot) {
                                        final sellerName = snapshot.data ?? 'Wildcat Student Seller';
                                        final hasStore = product.sellerStoreName != null && product.sellerStoreName!.trim().isNotEmpty;
                                        return Text(
                                          hasStore ? 'Owner: $sellerName' : sellerName,
                                          style: TextStyle(
                                            fontFamily: hasStore ? 'Inter' : 'Outfit',
                                            fontSize: hasStore ? 12 : 15,
                                            fontWeight: hasStore ? FontWeight.normal : FontWeight.bold,
                                            color: hasStore ? (isDark ? Colors.white70 : Colors.black87) : null,
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
                      ),
                      const SizedBox(height: 18),
                      // Action Button Deck wrapped in FutureBuilder to handle out-of-stock reservation flow dynamical
                      FutureBuilder<Map<String, int>>(
                        future: _getInventoryStatus(widget.product.id),
                        builder: (context, snapshot) {
                          final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;
                          final inv = snapshot.data ?? {'stock': 0, 'reserved': 0, 'available': 0};
                          final available = inv['available'] ?? 0;
                          final isOutOfStock = available <= 0;

                          return Row(
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
<<<<<<< Updated upstream
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
                                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                                ),
                                child: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  ref.read(cartProvider.notifier).addToCart(
                                        widget.product,
                                        quantity: _quantity,
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Added ${widget.product.title} to your cart!'),
                                      backgroundColor: TeknoyTheme.success,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: TeknoyTheme.citGold, width: 1.5),
                                  foregroundColor: TeknoyTheme.citGold,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_shopping_cart_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Add to Cart', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CheckoutView(
                                        product: widget.product,
                                        agreedPrice: widget.product.price,
                                        isDirectBuy: true,
                                        quantity: _quantity,
                                      ),
=======
                                      ],
>>>>>>> Stashed changes
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
                                          const SnackBar(content: Text('Please log in to chat with the seller')),
                                        );
                                        return;
                                      }

                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (_) => const Center(child: CircularProgressIndicator()),
                                      );

                                      try {
                                        final chatService = ref.read(chatServiceProvider);
                                        final roomId = await chatService.getOrCreateChatRoom(
                                          buyerId: buyerId,
                                          sellerId: widget.product.sellerId,
                                          productId: widget.product.id,
                                        );

                                        if (context.mounted) {
                                          Navigator.pop(context); // dismiss loader
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatView(
                                                product: widget.product,
                                                roomId: roomId,
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error starting chat: $e')),
                                          );
                                        }
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: isDark ? Colors.white : Colors.black87,
                                      side: BorderSide(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
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
                                  child: Container(
                                    decoration: (!isLoading && isOutOfStock)
                                        ? BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.amber.withOpacity(0.3),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              )
                                            ],
                                          )
                                        : null,
                                    child: ElevatedButton(
                                      onPressed: isLoading
                                          ? null
                                          : () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => CheckoutView(
                                                    product: widget.product,
                                                    agreedPrice: widget.product.price,
                                                    initialQuantity: _quantity,
                                                    isDirectBuy: true,
                                                    isReservation: isOutOfStock,
                                                  ),
                                                ),
                                              );
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isLoading
                                            ? Colors.grey[400]
                                            : (isOutOfStock ? const Color(0xFFD97706) : TeknoyTheme.citMaroon),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        padding: const EdgeInsets.symmetric(vertical: 18),
                                        elevation: 0,
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              height: 18,
                                              width: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  isOutOfStock ? Icons.bookmark_add_rounded : Icons.shopping_cart_checkout_rounded,
                                                  size: 18,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  isOutOfStock ? 'Reserve Item' : 'Buy Now',
                                                  style: const TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
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
