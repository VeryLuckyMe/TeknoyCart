import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/models/product.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';
import 'package:teknoycart/features/checkout/models/checkout_item.dart';
import 'package:teknoycart/features/checkout/models/campus_landmark.dart';
import 'package:teknoycart/features/checkout/views/widgets/checkout_section_header.dart';
import 'package:teknoycart/features/checkout/views/widgets/checkout_success_dialog.dart';

/// Transactional Checkout and Verification page representing Phase 4.
/// Confirms the agreed price and coordinates campus pickup locations.
class CheckoutView extends ConsumerStatefulWidget {
  final Product? product;
  final bool isDirectBuy;
  final double? agreedPrice;
  final String? roomId;
  final int quantity;
  final List<CheckoutItem>? items;
  final bool isReservation;
  final bool isPreorder;

  const CheckoutView({
    super.key,
    this.product,
    this.isDirectBuy = false,
    this.agreedPrice,
    this.roomId,
    this.quantity = 1,
    this.items,
    this.isReservation = false,
    this.isPreorder = false,
  });

  @override
  ConsumerState<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends ConsumerState<CheckoutView> {
  final _formKey = GlobalKey<FormState>();

  String _selectedLocation = 'Library Lobby';
  String _selectedDay = 'Today';
  String _selectedTimeSlot = '12:00 PM - 01:30 PM';

  // FIX #3: Renamed from 'Cash on Delivery' to 'Cash on Pickup' to match campus meetup model.
  String _selectedPaymentMethod = 'Cash on Pickup';

  String? _sellerGcashNumber;
  bool _isLoadingSellerGcash = false;

  // FIX #1: Per-item reservation map. Key = product.id, Value = isReservation.
  final Map<String, bool> _itemReservationMap = {};
  // FIX #1: Track resolved variant IDs per product to avoid re-querying on submit.
  final Map<String, String> _resolvedVariantIds = {};
  bool _isLoadingInventory = true;

  List<CheckoutItem> get _checkoutItems {
    if (widget.isDirectBuy) {
      return [
        CheckoutItem(
          product: widget.product!,
          price: widget.agreedPrice!,
          quantity: widget.quantity,
          variantId: _resolvedVariantIds[widget.product!.id],
        )
      ];
    }
    return widget.items ?? [];
  }

  // FIX #1: Reservation is true only if ANY item in the checkout is out of stock.
  bool get _isAnyItemReservation =>
      _itemReservationMap.values.any((isReserved) => isReserved);

  double get _totalPrice {
    return _checkoutItems.fold<double>(0.0, (sum, item) => sum + (item.price * item.quantity));
  }

  final List<CampusLandmark> _landmarks = const [
    CampusLandmark(
      name: 'Library Lobby',
      description: 'CIT-U Main Library first floor entrance',
      icon: Icons.local_library_rounded,
    ),
    CampusLandmark(
      name: 'Canteen Area',
      description: 'Student center food court dining tables',
      icon: Icons.fastfood_rounded,
    ),
    CampusLandmark(
      name: 'Science Building Lobby',
      description: 'Science building ground floor lobby',
      icon: Icons.science_rounded,
    ),
    CampusLandmark(
      name: 'Admin Building Vestibule',
      description: 'Main administration building entrance',
      icon: Icons.business_rounded,
    ),
    CampusLandmark(
      name: 'Wildcat Circle',
      description: 'Main campus entrance rotary & fountain',
      icon: Icons.star_rounded,
    ),
  ];

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.isPreorder) {
      _selectedDay = 'When Batch Ready (Est. 3-7 Days)';
    }
    _fetchSellerGcash();
    _fetchAllInventoryStatuses();
  }

  Future<void> _fetchSellerGcash() async {
    if (_checkoutItems.isEmpty) return;
    setState(() => _isLoadingSellerGcash = true);
    try {
      final res = await SupabaseConfig.client
          .from('users')
          .select('gcash_number')
          .eq('user_id', _checkoutItems.first.product.sellerId)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _sellerGcashNumber = res['gcash_number'] as String?;
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoadingSellerGcash = false);
    }
  }

  // FIX #1 & #7: Fetches inventory for ALL items concurrently using Future.wait()
  // instead of checking only the first item sequentially.
  Future<void> _fetchAllInventoryStatuses() async {
    if (_checkoutItems.isEmpty) {
      if (mounted) setState(() => _isLoadingInventory = false);
      return;
    }

    try {
      final client = SupabaseConfig.client;

      // FIX #7: Run all inventory checks in parallel.
      final futures = _checkoutItems.map((item) async {
        try {
          // Resolve variant ID if not already provided.
          String variantId = item.variantId ?? '00000000-0000-0000-0000-000000000000';
          if (item.variantId == null) {
            final variants = await client
                .from('product_variants')
                .select('variant_id')
                .eq('product_id', item.product.id)
                .limit(1);
            if ((variants as List).isNotEmpty) {
              variantId = variants[0]['variant_id'] as String;
            }
          }
          _resolvedVariantIds[item.product.id] = variantId;

          final inventoryRecord = await client
              .from('inventory')
              .select('stock_qty, reserved_qty')
              .eq('variant_id', variantId)
              .maybeSingle();

          bool isReservation = false;
          if (inventoryRecord != null) {
            final int stockQty = inventoryRecord['stock_qty'] as int? ?? 0;
            final int reservedQty = inventoryRecord['reserved_qty'] as int? ?? 0;
            isReservation = (stockQty - reservedQty) <= 0;
          }
          return MapEntry(item.product.id, isReservation);
        } catch (_) {
          return MapEntry(item.product.id, false);
        }
      }).toList();

      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          for (final entry in results) {
            _itemReservationMap[entry.key] = entry.value;
          }
          _isLoadingInventory = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingInventory = false);
    }
  }


  Future<void> _submitCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    // FIX #2: Block GCash checkout if seller hasn't configured their GCash number.
    if (_selectedPaymentMethod == 'GCash' &&
        (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The seller has not set up GCash. Please choose "Cash on Pickup" or contact the seller via chat.',
          ),
          backgroundColor: TeknoyTheme.warning,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authState = ref.read(authStateProvider).valueOrNull;
    final buyerId = authState?.id;

    if (buyerId != null) {
      try {
        final client = SupabaseConfig.client;

        for (final item in _checkoutItems) {
          // FIX #7: Use pre-resolved variant IDs from the parallel fetch done in initState.
          String itemVariantId = _resolvedVariantIds[item.product.id]
              ?? item.variantId
              ?? '00000000-0000-0000-0000-000000000000';

          // If still unresolved (edge-case), fetch it now.
          if (!_resolvedVariantIds.containsKey(item.product.id) && item.variantId == null) {
            try {
              final variants = await client
                  .from('product_variants')
                  .select('variant_id')
                  .eq('product_id', item.product.id)
                  .limit(1);
              if ((variants as List).isNotEmpty) {
                itemVariantId = variants[0]['variant_id'] as String;
              }
            } catch (_) {}
          }

          // Find or create matching inquiry row.
          final existingInquiries = await client
              .from('inquiries')
              .select('inquiry_id')
              .eq('buyer_id', buyerId)
              .eq('product_id', item.product.id)
              .limit(1);

          String inquiryId;
          if ((existingInquiries as List).isNotEmpty) {
            inquiryId = existingInquiries[0]['inquiry_id'] as String;
          } else {
            final insertedInquiry = await client.from('inquiries').insert({
              'buyer_id': buyerId,
              'product_id': item.product.id,
              'variant_id': itemVariantId,
              'quantity': item.quantity,
              'inquiry_type': 'AVAILABILITY',
              'message': 'Initiated checkout for ${item.product.title}',
            }).select().single();
            inquiryId = insertedInquiry['inquiry_id'] as String;
          }

          // FIX #3: DB enum uses 'CASH_ON_PICKUP' and 'GCASH'.
          final String dbPaymentMethod =
              _selectedPaymentMethod == 'GCash' ? 'GCASH' : 'CASH_ON_PICKUP';

          // ATOMIC DB-LEVEL INVENTORY LOCK (Prevents race conditions / double-booking)
          if (itemVariantId.isNotEmpty) {
            try {
              final rpcRes = await client.rpc('reserve_inventory_atomic', params: {
                'p_variant_id': itemVariantId,
                'p_quantity': item.quantity,
                'p_allow_preorder': widget.isPreorder || item.product.isPreorderEnabled,
              });
              if (rpcRes is Map && rpcRes['success'] == false) {
                final err = rpcRes['error']?.toString();
                String errorMsg = 'Failed to reserve stock.';
                if (err == 'INSUFFICIENT_STOCK') {
                  errorMsg = 'Sorry, "${item.product.title}" was just claimed by another student!';
                } else if (err == 'PRODUCT_NOT_ACTIVE') {
                  errorMsg = 'This listing is no longer active.';
                } else if (err == 'CANNOT_RESERVE_OWN_PRODUCT') {
                  errorMsg = 'You cannot purchase your own product listing.';
                }
                if (mounted) {
                  setState(() => _isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(errorMsg), backgroundColor: TeknoyTheme.error),
                  );
                }
                return;
              }
            } catch (rpcErr) {
              debugPrint("RPC reserve_inventory_atomic fallback: $rpcErr");
            }
          }

          // Insert into orders with explicit is_preorder snapshot and safe expiration
          await client.from('orders').insert({
            'inquiry_id': inquiryId,
            'buyer_id': buyerId,
            'seller_id': item.product.sellerId,
            'variant_id': itemVariantId,
            'quantity': item.quantity,
            'unit_price': item.price,
            'total_amount': item.price * item.quantity,
            'status': 'PLACED',
            'pickup_location': widget.isPreorder ? '[PRE-ORDER] $_selectedLocation' : _selectedLocation,
            'pickup_day': widget.isPreorder ? 'When Batch Ready (Est. 3-7 Days)' : _selectedDay,
            'pickup_time': _selectedTimeSlot,
            'payment_method': dbPaymentMethod,
            'is_preorder': widget.isPreorder,
            'reservation_expires_at': widget.isPreorder ? null : DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
          });

          // Send handshake message to chat room (ensuring chat room exists)
          try {
            final chatService = ref.read(chatServiceProvider);
            final activeRoomId = widget.roomId ?? await chatService.getOrCreateChatRoom(
              buyerId: buyerId,
              sellerId: item.product.sellerId,
              productId: item.product.id,
            );

            final handshakeMessage = widget.isPreorder
                ? '📦 [PRE-ORDER PLACED]\nHello! I placed a pre-order for ${item.product.title} (Qty: ${item.quantity}).\nEstimated lead time: 3-7 business days.\nPreferred campus availability: $_selectedTimeSlot at $_selectedLocation.\nPlease message me here once the batch arrives on campus!'
                : '🤝 Handshake Deal Confirmed! Meetup requested for $_selectedDay ($_selectedTimeSlot) at $_selectedLocation.';

            await ref.read(chatControllerProvider.notifier).postMessage(
              senderId: buyerId,
              receiverId: item.product.sellerId,
              content: handshakeMessage,
              roomId: activeRoomId,
              product: item.product,
            );
          } catch (e) {
            debugPrint("CHAT_CHECKOUT_MESSAGE_POST_ERROR: $e");
          }

          // Remove from cart if not direct buy.
          if (!widget.isDirectBuy) {
            ref.read(cartProvider.notifier).removeFromCart(item.product.id, item.variantId);
          }
        }

        if (mounted) {
          setState(() => _isSubmitting = false);
          _showSuccessDialog();
        }
      } catch (e) {
        debugPrint("CHECKOUT_SUBMIT_ERROR: $e");
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Checkout failed: $e'),
              backgroundColor: TeknoyTheme.error,
            ),
          );
        }
      }
    } else {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog() {
    CheckoutSuccessDialog.show(
      context,
      isPreorder: widget.isPreorder,
      totalPrice: _totalPrice,
    );
  }


  Widget _buildPreorderHeroBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E0A0E), TeknoyTheme.darkSurface]
              : [const Color(0xFFFFFBF5), const Color(0xFFFFF5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: TeknoyTheme.citGold.withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.hourglass_top_rounded, color: TeknoyTheme.citGold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: TeknoyTheme.citGold.withValues(alpha: isDark ? 0.2 : 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: TeknoyTheme.citGold.withValues(alpha: 0.5), width: 0.8),
                  ),
                  child: const Text(
                    'EST. 3–7 BUSINESS DAYS',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: TeknoyTheme.citGold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Made-to-Order / Batch Production',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : TeknoyTheme.citMaroonDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This item is prepared on demand. Campus pickup will not take place today or tomorrow. Please specify your availability hours below so the seller can coordinate with your schedule when the batch arrives.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.white70 : TeknoyTheme.citMaroonDark.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSpotlightCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _checkoutItems.length == 1
          ? Row(
              children: [
                Container(
                  width: 85,
                  height: 85,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: TeknoyTheme.citGold.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    image: DecorationImage(
                      image: NetworkImage(_checkoutItems.first.product.imageUrl ?? ''),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _checkoutItems.first.product.title,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Quantity: ${_checkoutItems.first.quantity} | Category: ${_checkoutItems.first.product.category}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF251C12)
                                  : TeknoyTheme.citGold.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: TeknoyTheme.citGold.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              _checkoutItems.first.product.condition.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 10,
                                color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroonDark,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // High-contrast WCAG AAA price display:
                          // citGold in dark mode (9.77:1), citMaroon in light mode (10.95:1)
                          Text(
                            '₱${_checkoutItems.first.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cart Items (${_checkoutItems.length})',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : TeknoyTheme.citMaroonDark,
                  ),
                ),
                const SizedBox(height: 10),
                Divider(color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder),
                const SizedBox(height: 8),
                ..._checkoutItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: TeknoyTheme.citGold.withValues(alpha: 0.25),
                              width: 1,
                            ),
                            image: DecorationImage(
                              image: NetworkImage(item.product.imageUrl ?? ''),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.title,
                                style: TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: ${item.quantity} | ₱${item.price.toStringAsFixed(2)} each',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱${(item.price * item.quantity).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildLandmarkCard(CampusLandmark landmark, bool isSelected, bool isDark) {
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLocation = landmark.name);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 175,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? TeknoyTheme.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? TeknoyTheme.citGold
                : (isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  landmark.icon,
                  color: isSelected
                      ? TeknoyTheme.citGold
                      : (isDark ? Colors.white70 : TeknoyTheme.citMaroon),
                  size: 26,
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: TeknoyTheme.citGold,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  landmark.name,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  landmark.description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : (isDark ? Colors.white54 : Colors.black54),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreorderScheduleClarification(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: TeknoyTheme.citGold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: TeknoyTheme.citGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Select your preferred weekly campus time window below. The seller will use this to schedule your pickup once the batch arrives on campus.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChips(bool isDark) {
    final days = ['Today', 'Tomorrow', 'Next Day'];
    return Row(
      children: days.map((day) {
        final isSelected = _selectedDay == day;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedDay = day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark ? TeknoyTheme.darkSurface : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? TeknoyTheme.citGold
                        : (isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder),
                    width: isSelected ? 1.8 : 1.2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: TeknoyTheme.citMaroon.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimeSlotGrid(bool isDark) {
    final slots = [
      '09:00 AM - 10:30 AM',
      '12:00 PM - 01:30 PM',
      '03:00 PM - 04:30 PM',
      '05:00 PM - 06:30 PM',
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.8,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isSelected = _selectedTimeSlot == slot;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedTimeSlot = slot);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected
                  ? null
                  : (isDark ? TeknoyTheme.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? TeknoyTheme.citGold
                    : (isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: TeknoyTheme.citMaroon.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: isSelected
                      ? TeknoyTheme.citGold
                      : (isDark ? Colors.white38 : Colors.black38),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodSelector(bool isDark) {
    final isCash = _selectedPaymentMethod == 'Cash on Pickup';
    final isGcash = _selectedPaymentMethod == 'GCash';

    return Column(
      children: [
        // Cash on Pickup Card
        GestureDetector(
          onTap: () => setState(() => _selectedPaymentMethod = 'Cash on Pickup'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isCash
                  ? (isDark ? const Color(0xFF1F0F12) : const Color(0xFFFFF8F7))
                  : (isDark ? TeknoyTheme.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCash
                    ? (isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon)
                    : (isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder),
                width: isCash ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isCash
                      ? TeknoyTheme.citMaroon.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isCash
                        ? const LinearGradient(
                            colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isCash
                        ? null
                        : (isDark ? TeknoyTheme.darkBorder : const Color(0xFFF1F1F4)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    color: isCash ? TeknoyTheme.citGold : (isDark ? Colors.white70 : Colors.black87),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Cash on Pickup',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Legible, high-contrast Recommended Badge
                          // Light: citMaroonDark text on gold fill (8.22:1 AAA)
                          // Dark: citGold text on dark warm fill (8.5:1 AAA)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF251C12)
                                  : TeknoyTheme.citGold.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: TeknoyTheme.citGold.withValues(alpha: 0.45),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'RECOMMENDED',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroonDark,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Pay with exact physical cash upon verifying goods at the campus landmark.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCash
                        ? (isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon)
                        : Colors.transparent,
                    border: Border.all(
                      color: isCash
                          ? (isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon)
                          : (isDark ? Colors.white38 : Colors.black26),
                      width: 2,
                    ),
                  ),
                  child: isCash
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: isDark ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // GCash Card
        GestureDetector(
          onTap: () => setState(() => _selectedPaymentMethod = 'GCash'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isGcash
                  ? (isDark ? const Color(0xFF1F0F12) : const Color(0xFFFFF8F7))
                  : (isDark ? TeknoyTheme.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isGcash
                    ? (isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon)
                    : (isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder),
                width: isGcash ? 1.8 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isGcash
                      ? TeknoyTheme.citMaroon.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isGcash
                        ? const LinearGradient(
                            colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isGcash
                        ? null
                        : (isDark ? TeknoyTheme.darkBorder : const Color(0xFFF1F1F4)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: isGcash ? TeknoyTheme.citGold : (isDark ? Colors.white70 : Colors.black87),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GCash Transfer',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Direct e-wallet payment. Seller verification and reference receipt required.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isGcash
                        ? (isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon)
                        : Colors.transparent,
                    border: Border.all(
                      color: isGcash
                          ? (isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon)
                          : (isDark ? Colors.white38 : Colors.black26),
                      width: 2,
                    ),
                  ),
                  child: isGcash
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: isDark ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),

        // GCash Warning / Info Drawer
        if (isGcash) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                  ? TeknoyTheme.warning.withValues(alpha: 0.1)
                  : (isDark ? const Color(0xFF251C12) : TeknoyTheme.citGold.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                    ? TeknoyTheme.warning.withValues(alpha: 0.4)
                    : TeknoyTheme.citGold.withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                      ? Icons.warning_amber_rounded
                      : Icons.verified_user_rounded,
                  color: (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                      ? TeknoyTheme.warning
                      : TeknoyTheme.citGold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isLoadingSellerGcash
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: TeknoyTheme.citGold),
                          ),
                        )
                      : Text(
                          _sellerGcashNumber != null && _sellerGcashNumber!.isNotEmpty
                              ? 'Transfer GCash to Seller: $_sellerGcashNumber'
                              : 'GCash Unavailable — Seller has not configured their GCash number. Please switch to Cash on Pickup.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                                ? TeknoyTheme.warning
                                : (isDark ? Colors.white : TeknoyTheme.citMaroonDark),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceFinalizer(bool isDark) {
    final int totalUnits = _checkoutItems.fold<int>(0, (sum, item) => sum + item.quantity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: TeknoyTheme.citGold.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Payable',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : TeknoyTheme.citMaroonDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalUnits ${totalUnits == 1 ? 'item' : 'items'} total • ${widget.isPreorder ? 'Pay upon batch handoff' : 'Pay upon meetup handoff'}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
          // Contrast WCAG AAA compliant price:
          // citGold in dark mode (9.77:1), citMaroon in light mode (10.95:1)
          Text(
            '₱${_totalPrice.toStringAsFixed(2)}',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationToggle(bool isDark) {
    if (_isLoadingInventory) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? TeknoyTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? TeknoyTheme.darkBorder : TeknoyTheme.lightBorder,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: TeknoyTheme.citMaroon),
        ),
      );
    }

    final isReservation = _isAnyItemReservation;

    final String title;
    final String subtitle;
    final IconData icon;
    final Color accentColor;

    if (widget.isPreorder) {
      title = 'Pre-Order Batch Fulfillment';
      subtitle = 'Prepared on demand by seller. In-app chat updates when ready for campus pickup.';
      icon = Icons.hourglass_top_rounded;
      accentColor = TeknoyTheme.citGold;
    } else if (isReservation) {
      title = 'Automatic Stock Reservation';
      subtitle = 'One or more items are out of stock. Held until restock or seller handoff.';
      icon = Icons.schedule_rounded;
      accentColor = TeknoyTheme.warning;
    } else {
      title = 'Campus Meetup Stock Hold';
      subtitle = '1 on-hand unit held for 24 hours until verified campus meetup handoff.';
      icon = Icons.verified_rounded;
      accentColor = TeknoyTheme.citGold;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? TeknoyTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isPageLoading = _isLoadingInventory || _isLoadingSellerGcash;

    return Scaffold(
      backgroundColor: isDark ? TeknoyTheme.darkBg : TeknoyTheme.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? TeknoyTheme.darkBg : TeknoyTheme.lightBg,
        elevation: 0,
        title: Column(
          children: [
            Text(
              widget.isPreorder ? 'Confirm Pre-Order' : 'Confirm P2P Deal',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
            Text(
              widget.isPreorder ? 'Batch Production Handoff' : 'CIT-U Campus Handshake',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isPreorder) ...[
                _buildPreorderHeroBanner(isDark),
                const SizedBox(height: 18),
              ],
              _buildProductSpotlightCard(isDark),
              const SizedBox(height: 28),

              // Pickup Landmark Header & Horizontal List
              CheckoutSectionHeader(
                icon: Icons.location_on_rounded,
                title: 'Pickup Landmark',
                subtitle: 'Select an approved CIT-U campus meetup location',
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _landmarks.length,
                  itemBuilder: (context, index) {
                    final landmark = _landmarks[index];
                    final isSelected = _selectedLocation == landmark.name;
                    return _buildLandmarkCard(landmark, isSelected, isDark);
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Availability / Schedule Header
              CheckoutSectionHeader(
                icon: widget.isPreorder ? Icons.access_time_filled_rounded : Icons.calendar_month_rounded,
                title: widget.isPreorder ? 'Campus Availability Hours' : 'Suggested Schedule',
                subtitle: widget.isPreorder
                    ? 'Indicate when you are generally on campus between classes'
                    : 'Choose your desired pickup day and meetup time window',
                isDark: isDark,
              ),
              const SizedBox(height: 14),

              if (widget.isPreorder) ...[
                _buildPreorderScheduleClarification(isDark),
                const SizedBox(height: 14),
              ] else ...[
                _buildDayChips(isDark),
                const SizedBox(height: 14),
              ],
              _buildTimeSlotGrid(isDark),
              const SizedBox(height: 28),

              // Reservation status banner
              _buildReservationToggle(isDark),
              const SizedBox(height: 28),

              // Payment Method Header & Cards
              CheckoutSectionHeader(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Payment Method',
                subtitle: 'Choose physical cash at meetup or direct GCash transfer',
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildPaymentMethodSelector(isDark),
              const SizedBox(height: 28),

              // Price Summary Header & Finalizer Card
              CheckoutSectionHeader(
                icon: Icons.payments_rounded,
                title: 'Order Summary',
                subtitle: 'Review total price prior to deal logging',
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildPriceFinalizer(isDark),
              const SizedBox(height: 36),

              // Submit button with signature CIT-U Maroon gradient
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: (_isSubmitting || isPageLoading) ? null : _submitCheckout,
                  icon: (_isSubmitting || isPageLoading)
                      ? const SizedBox.shrink()
                      : Icon(
                          widget.isPreorder ? Icons.assignment_turned_in_rounded : Icons.handshake_rounded,
                          size: 20,
                          color: TeknoyTheme.citGold,
                        ),
                  label: (_isSubmitting || isPageLoading)
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          widget.isPreorder ? 'Confirm Pre-Order Request' : 'Confirm Meetup Deal',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                            color: Colors.white,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
