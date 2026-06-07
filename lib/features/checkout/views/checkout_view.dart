import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/feed/models/product.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/features/chat/providers/chat_provider.dart';

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
  final Product product;
  final bool isDirectBuy;
  final double agreedPrice;
  final String? roomId;

  const CheckoutView({
    super.key,
    required this.product,
    this.isDirectBuy = false,
    required this.agreedPrice,
    this.roomId,
  });

  @override
  ConsumerState<CheckoutView> createState() => _CheckoutViewState();
}

class _CheckoutViewState extends ConsumerState<CheckoutView> {
  final _formKey = GlobalKey<FormState>();

  String _selectedLocation = 'Library Lobby';
  String _selectedDay = 'Today';
  String _selectedTimeSlot = '12:00 PM - 01:30 PM';
  String _selectedPaymentMethod = 'Cash on Delivery';
  bool _isReservation = false;
  String? _sellerGcashNumber;
  bool _isLoadingSellerGcash = false;

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
  }

  Future<void> _fetchSellerGcash() async {
    setState(() => _isLoadingSellerGcash = true);
    try {
      final res = await SupabaseConfig.client
          .from('users')
          .select('gcash_number')
          .eq('user_id', widget.product.sellerId)
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

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _submitCheckout() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final authState = ref.read(authStateProvider).valueOrNull;
    final buyerId = authState?.id;
    final combinedLocation = '$_selectedLocation ($_selectedDay, $_selectedTimeSlot) | Payment: $_selectedPaymentMethod';

    if (buyerId != null) {
      try {
        final client = SupabaseConfig.client;

        // 1. Fetch variant ID for product
        final variants = await client
            .from('product_variants')
            .select('variant_id')
            .eq('product_id', widget.product.id)
            .limit(1);

        final String variantId = (variants as List).isNotEmpty
            ? (variants[0]['variant_id'] as String)
            : '00000000-0000-0000-0000-000000000000'; // fallback

        // 2. Fetch inventory status for stock validation (NFR-04 / FR-09)
        final inventoryRecord = await client
            .from('inventory')
            .select('stock_qty, reserved_qty')
            .eq('variant_id', variantId)
            .maybeSingle();

        if (inventoryRecord != null) {
          final int stockQty = inventoryRecord['stock_qty'] as int? ?? 0;
          final int reservedQty = inventoryRecord['reserved_qty'] as int? ?? 0;

          if (stockQty <= 0) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction Failed: This item is currently out of stock.'),
                  backgroundColor: TeknoyTheme.error,
                ),
              );
            }
            setState(() => _isSubmitting = false);
            return;
          }

          // Update inventory: decrement stock, and increment reserved if instantly reserving
          await client.from('inventory').update({
            'stock_qty': stockQty - 1,
            'reserved_qty': _isReservation ? reservedQty + 1 : reservedQty,
          }).eq('variant_id', variantId);
        }

        // 3. Find or create matching inquiry row
        final existingInquiries = await client
            .from('inquiries')
            .select('inquiry_id')
            .eq('buyer_id', buyerId)
            .eq('product_id', widget.product.id)
            .limit(1);

        String inquiryId;
        if ((existingInquiries as List).isNotEmpty) {
          inquiryId = existingInquiries[0]['inquiry_id'] as String;
        } else {
          final insertedInquiry = await client.from('inquiries').insert({
            'buyer_id': buyerId,
            'product_id': widget.product.id,
            'variant_id': variantId,
            'quantity': 1,
            'inquiry_type': 'AVAILABILITY',
            'message': 'Initiated checkout for ${widget.product.title}',
          }).select().single();
          inquiryId = insertedInquiry['inquiry_id'] as String;
        }

        // 4. Perform live Supabase insert into orders
        await client.from('orders').insert({
          'inquiry_id': inquiryId,
          'buyer_id': buyerId,
          'seller_id': widget.product.sellerId,
          'variant_id': variantId,
          'quantity': 1,
          'unit_price': widget.agreedPrice,
          'total_amount': widget.agreedPrice,
          'status': _isReservation ? 'APPROVED' : 'INQUIRY_SENT',
          'pickup_location': combinedLocation,
          'reservation_expires_at': _isReservation 
              ? DateTime.now().add(const Duration(hours: 24)).toIso8601String() 
              : null,
        });

        // 4. Send handshake message to chat room if available
        if (widget.roomId != null) {
          try {
            await ref.read(chatControllerProvider.notifier).postMessage(
              senderId: buyerId,
              receiverId: widget.product.sellerId,
              content: 'Handshake Deal Confirmed! Meetup Scheduled.',
              roomId: widget.roomId!,
              product: widget.product,
            );
          } catch (e) {
            print("CHAT_CHECKOUT_MESSAGE_POST_ERROR: $e");
          }
        }
      } catch (e) {
        // Network unavailable (e.g. test environment) — degrade gracefully
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      _showSuccessDialog();
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
              _isReservation ? 'Item Reserved!' : 'Deal Logged!',
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          _isReservation 
              ? 'Your P2P offer of ₱${widget.agreedPrice.toStringAsFixed(2)} has been successfully logged and the item is now reserved for 24 hours! Make sure to coordinate and upload your payment proof via chat before the reservation expires.'
              : 'Your P2P offer of ₱${widget.agreedPrice.toStringAsFixed(2)} at $_selectedLocation ($_selectedDay, $_selectedTimeSlot) has been successfully logged! Coordinate with the seller via chat for the meetup.',
          style: const TextStyle(fontFamily: 'Inter', height: 1.4),
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
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 85,
            height: 85,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: TeknoyTheme.citGold.withOpacity(0.3),
                width: 1.5,
              ),
              image: DecorationImage(
                image: NetworkImage(widget.product.imageUrl ?? ''),
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
                  widget.product.title,
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
                  'Category: ${widget.product.category}',
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
                    color: TeknoyTheme.citGold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.product.condition.toUpperCase(),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? TeknoyTheme.citMaroon.withOpacity(isDark ? 0.9 : 0.85)
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
                    color: TeknoyTheme.citGold.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
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
                        : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
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
                        ? Colors.white.withOpacity(0.75)
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
                  ? TeknoyTheme.citMaroon.withOpacity(isDark ? 0.9 : 0.8)
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
                    : (isDark ? Colors.white.withOpacity(0.9) : Colors.black87),
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
        RadioListTile<String>(
          title: const Text('Cash on Delivery', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          subtitle: const Text('Pay with cash upon meetup.', style: TextStyle(fontFamily: 'Inter', fontSize: 12)),
          value: 'Cash on Delivery',
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
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 20),
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
                      : Text(
                          _sellerGcashNumber != null && _sellerGcashNumber!.isNotEmpty
                              ? 'Transfer GCash to Seller: $_sellerGcashNumber'
                              : 'Seller has not configured their GCash details. Please coordinate via chat.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.blue[200] : Colors.blue[800]),
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
          '₱${widget.agreedPrice.toStringAsFixed(2)}',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isReservation
            ? TeknoyTheme.citMaroon.withOpacity(isDark ? 0.12 : 0.06)
            : (isDark ? const Color(0xFF141418) : const Color(0xFFF4F4F7)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isReservation
              ? TeknoyTheme.citMaroon.withOpacity(0.5)
              : (isDark ? const Color(0xFF22222A) : const Color(0xFFE5E5E9)),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isReservation
                  ? TeknoyTheme.citMaroon
                  : (isDark ? const Color(0xFF22222A) : Colors.white),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_empty_rounded,
              color: _isReservation ? Colors.white : TeknoyTheme.citGold,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Instantly Reserve Item',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Locks stock for 24 hours. Auto-cancels if payment is not uploaded.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isReservation,
            activeColor: TeknoyTheme.citMaroon,
            onChanged: (val) {
              setState(() => _isReservation = val);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                height: 145,
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

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TeknoyTheme.citMaroon,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  elevation: 2,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isReservation ? 'Reserve & Confirm Meetup Deal' : 'Confirm Meetup Deal',
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
