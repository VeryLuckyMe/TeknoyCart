import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';
import 'package:teknoycart/features/checkout/providers/cart_provider.dart';

class CheckoutItem {
  final Product product;
  final double price;
  final int quantity;
  final String? variantId;
  final String? variantName;

  const CheckoutItem({
    required this.product,
    required this.price,
    required this.quantity,
    this.variantId,
    this.variantName,
  });
}

class CampusLandmark {
  final String name;
  final String description;
  final IconData icon;

  const CampusLandmark({
    required this.name,
    required this.description,
    required this.icon,
  });
}

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

  const CheckoutView({
    super.key,
    this.product,
    this.isDirectBuy = false,
    this.agreedPrice,
    this.roomId,
    this.quantity = 1,
    this.items,
    this.isReservation = false,
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
          backgroundColor: Colors.orange,
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

          // FIX #1: Use per-item reservation status from the map.
          final bool thisItemIsReservation =
              _itemReservationMap[item.product.id] ?? false;

          // Insert into orders.
          await client.from('orders').insert({
            'inquiry_id': inquiryId,
            'buyer_id': buyerId,
            'seller_id': item.product.sellerId,
            'variant_id': itemVariantId,
            'quantity': item.quantity,
            'unit_price': item.price,
            'total_amount': item.price * item.quantity,
            'status': thisItemIsReservation ? 'APPROVED' : 'INQUIRY_SENT',
            'pickup_location': _selectedLocation,
            'pickup_day': _selectedDay,
            'pickup_time': _selectedTimeSlot,
            'payment_method': dbPaymentMethod,
            'reservation_expires_at': thisItemIsReservation
                ? DateTime.now().add(const Duration(hours: 24)).toIso8601String()
                : null,
          });

          // Send handshake message to chat room if available.
          if (widget.roomId != null) {
            try {
              await ref.read(chatControllerProvider.notifier).postMessage(
                senderId: buyerId,
                receiverId: item.product.sellerId,
                content: 'Handshake Deal Confirmed! Meetup Scheduled.',
                roomId: widget.roomId!,
                product: item.product,
              );
            } catch (e) {
              debugPrint("CHAT_CHECKOUT_MESSAGE_POST_ERROR: $e");
            }
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: TeknoyTheme.success, size: 28),
            const SizedBox(width: 10),
            Text(
              _isAnyItemReservation ? 'Item Reserved!' : 'Deal Logged!',
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your order for ₱${_totalPrice.toStringAsFixed(2)} has been successfully logged! Awaiting seller acceptance. You can track this in the Orders Hub.',
              style: const TextStyle(fontFamily: 'Inter', height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Coordinate with the seller via chat for meetup and payment verification updates.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TeknoyTheme.citMaroon,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Back to Feed',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
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
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1B1B1F), const Color(0xFF16161B)]
              : [Colors.white, const Color(0xFFF9F9FB)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C35) : const Color(0xFFECECEF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
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
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: TeknoyTheme.citGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _checkoutItems.first.product.condition.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 10,
                            color: TeknoyTheme.citGold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
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
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(),
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
                              color: TeknoyTheme.citGold.withValues(alpha: 0.2),
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
                                style: const TextStyle(
                                  fontFamily: 'Outfit',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: ${item.quantity} | ₱${item.price.toStringAsFixed(2)} each',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
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
        duration: const Duration(milliseconds: 250),
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.9 : 0.85)
              : (isDark ? const Color(0xFF16161B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? TeknoyTheme.citGold
                : (isDark ? const Color(0xFF2C2C35) : const Color(0xFFECECEF)),
            width: isSelected ? 2 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: TeknoyTheme.citGold.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
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
                      : (isDark ? Colors.white70 : Colors.black54),
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
            const SizedBox(height: 16),
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
                        : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  landmark.description,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.75)
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

  Widget _buildDayChips(bool isDark) {
    final days = ['Today', 'Tomorrow', 'Next Day'];
    return Row(
      children: days.map((day) {
        final isSelected = _selectedDay == day;
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: ChoiceChip(
            label: Text(
              day,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
            selected: isSelected,
            selectedColor: TeknoyTheme.citMaroon,
            backgroundColor: isDark ? const Color(0xFF16161B) : const Color(0xFFF1F1F4),
            checkmarkColor: Colors.white,
            onSelected: (selected) {
              if (selected) {
                setState(() => _selectedDay = day);
              }
            },
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
        childAspectRatio: 3.0,
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
            decoration: BoxDecoration(
              color: isSelected
                  ? TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.9 : 0.8)
                  : (isDark ? const Color(0xFF16161B) : const Color(0xFFF4F4F7)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? TeknoyTheme.citGold
                    : (isDark ? const Color(0xFF2C2C35) : const Color(0xFFECECEF)),
                width: isSelected ? 1.8 : 1.2,
              ),
            ),
            child: Text(
              slot,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white.withValues(alpha: 0.9) : Colors.black87),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodSelector(bool isDark) {
    return Column(
      children: [
        // FIX #3: Renamed label from 'Cash on Delivery' → 'Cash on Pickup'.
        RadioListTile<String>(
          title: const Text('Cash on Pickup', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          subtitle: const Text('Pay with cash at the campus meetup spot.', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
          value: 'Cash on Pickup',
          groupValue: _selectedPaymentMethod,
          activeColor: TeknoyTheme.citMaroon,
          onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
        ),
        RadioListTile<String>(
          title: const Text('GCash', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          subtitle: const Text('Direct GCash transfer to seller.', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
          value: 'GCash',
          groupValue: _selectedPaymentMethod,
          activeColor: TeknoyTheme.citMaroon,
          onChanged: (val) => setState(() => _selectedPaymentMethod = val!),
        ),
        if (_selectedPaymentMethod == 'GCash')
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              // FIX #2: Use orange/warning color if GCash is not configured, blue if it is.
              color: (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                  ? Colors.orange.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                    ? Colors.orange.withValues(alpha: 0.4)
                    : Colors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                      ? Icons.warning_amber_rounded
                      : Icons.info_outline_rounded,
                  color: (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                      ? Colors.orange
                      : Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _isLoadingSellerGcash
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sellerGcashNumber != null && _sellerGcashNumber!.isNotEmpty
                                  ? 'Transfer GCash to Seller: $_sellerGcashNumber'
                                  // FIX #2: Clearly warn that GCash is unavailable and block submission.
                                  : 'GCash Unavailable — Seller has not configured their GCash number. You cannot proceed with GCash. Please switch to Cash on Pickup or contact the seller.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: (_sellerGcashNumber == null || _sellerGcashNumber!.isEmpty)
                                    ? Colors.orange[800]
                                    : (isDark ? Colors.blue[200] : Colors.blue[800]),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPriceFinalizer(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : const Color(0xFFF4F4F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF22222A) : const Color(0xFFE5E5E9),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Text(
          '₱${_totalPrice.toStringAsFixed(2)}',
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildReservationToggle(bool isDark) {
    if (_isLoadingInventory) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141418) : const Color(0xFFF4F4F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: TeknoyTheme.citMaroon)),
      );
    }

    // FIX #1: Use the aggregate reservation status across all items.
    final isReservation = _isAnyItemReservation;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReservation
            ? TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.12 : 0.06)
            : (isDark ? const Color(0xFF141418) : const Color(0xFFF4F4F7)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReservation
              ? TeknoyTheme.citMaroon.withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF22222A) : const Color(0xFFE5E5E9)),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isReservation
                  ? TeknoyTheme.citMaroon
                  : (isDark ? const Color(0xFF22222A) : Colors.white),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              color: isReservation ? Colors.white : TeknoyTheme.citGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReservation ? 'Automatic Reservation' : 'Instant Purchase',
                  style: const TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isReservation
                      ? 'One or more items are out of stock. Proceeding as a reservation.'
                      : 'All items are in stock. Proceeding as a regular purchase.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
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

    // FIX #6: The submit button is disabled while inventory or GCash info is still loading.
    final bool isPageLoading = _isLoadingInventory || _isLoadingSellerGcash;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Confirm P2P Deal',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProductSpotlightCard(isDark),
              const SizedBox(height: 28),

              // Title header
              Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: TeknoyTheme.citGold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Meetup Landmark',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Horizontal scroll of Campus Landmark Cards
              SizedBox(
                height: 155,
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

              // Suggested schedule header
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: TeknoyTheme.citGold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Suggested Schedule',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildDayChips(isDark),
              const SizedBox(height: 14),
              _buildTimeSlotGrid(isDark),
              const SizedBox(height: 28),

              _buildReservationToggle(isDark),
              const SizedBox(height: 28),

              // Payment Method header
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: TeknoyTheme.citGold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Payment Method',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildPaymentMethodSelector(isDark),
              const SizedBox(height: 28),

              // Final Price header
              Row(
                children: [
                  const Icon(Icons.payments_rounded, color: TeknoyTheme.citGold, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Confirm Final Price',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildPriceFinalizer(isDark),
              const SizedBox(height: 36),

              // FIX #6: Disable submit button while page data is still loading.
              ElevatedButton(
                onPressed: (_isSubmitting || isPageLoading) ? null : _submitCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TeknoyTheme.citMaroon,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: TeknoyTheme.citMaroon.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 2,
                ),
                child: (_isSubmitting || isPageLoading)
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isAnyItemReservation ? 'Reserve & Confirm Meetup Deal' : 'Confirm Meetup Deal',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
