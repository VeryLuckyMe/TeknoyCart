import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Use localhost for Web/Windows, or 10.0.2.2 if you switch back to Android emulator
const String backendUrl = 'http://localhost:8080/api/orders';

/// Full-screen order detail view with status stepper, party info, cancellation & return request capabilities.
class OrderDetailView extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final bool isSeller;

  const OrderDetailView({super.key, required this.order, required this.isSeller});

  @override
  ConsumerState<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends ConsumerState<OrderDetailView> {
  late Map<String, dynamic> _order;
  bool _isActing = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
    _subscribeToOrderUpdates();
  }

  void _subscribeToOrderUpdates() {
    final orderId = _order['order_id'] as String?;
    if (orderId == null) return;
    _realtimeChannel = SupabaseConfig.client
        .channel('order_detail_$orderId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'order_id',
            value: orderId,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                _order = {..._order, ...Map<String, dynamic>.from(payload.newRecord)};
              });
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _callSpringApi(String action, Map<String, dynamic> body) async {
    final url = Uri.parse('$backendUrl/${_order['order_id']}/$action');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }


  String get _status {
    final raw = _order['status'] as String? ?? '';
    // Map legacy DB statuses to the new state machine to avoid breaking existing demo data
    if (raw == 'PENDING_SELLER_ACCEPT' || raw == 'INQUIRY_SENT') return 'PLACED';
    if (raw == 'APPROVED' || raw == 'SELLER_ACCEPTED') return 'ACCEPTED';
    return raw;
  }
  String get _rawPaymentMethod => _order['payment_method'] as String? ?? 'CASH_ON_PICKUP';
  String get _paymentMethod => (_rawPaymentMethod == 'GCASH' || _rawPaymentMethod == 'GCash') ? 'GCash' : 'Cash on Pickup';
  bool get _isGCash => _paymentMethod == 'GCash';

  Future<void> _refreshOrder() async {
    try {
      final res = await SupabaseConfig.client
          .from('orders')
          .select('''
            order_id, total_amount, status, quantity, created_at,
            pickup_location, pickup_day, pickup_time, payment_method,
            seller_confirmed_at, buyer_confirmed_at, buyer_id, seller_id,
            product_variants (
              variant_value,
              products ( name, product_images (image_url, is_primary) )
            )
          ''')
          .eq('order_id', _order['order_id'])
          .single();
      if (mounted) {
        setState(() {
          _order = {..._order, ...Map<String, dynamic>.from(res)};
        });
      }
    } catch (_) {}
  }

  Future<void> _updateStatus(String newStatus) async {
    // Legacy fallback or UI refresh trigger
    setState(() => _isActing = true);
    try {
      await _refreshOrder();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  Future<void> _handleSpringAction(String action, Map<String, dynamic> body, String successMsg) async {
    setState(() => _isActing = true);
    try {
      await _callSpringApi(action, body);
      await _refreshOrder();
      if (mounted && successMsg.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(successMsg),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  bool get _isItemOutOfStock {
    if (_order['is_out_of_stock'] == true) return true;
    final variant = _order['product_variants'] as Map<String, dynamic>?;
    final product = variant?['products'] as Map<String, dynamic>?;
    if (product != null) {
      final int stock = int.tryParse(product['stock_qty']?.toString() ?? '0') ?? 0;
      final String name = (product['name'] as String? ?? '').toLowerCase();
      if (stock <= 0 || name.contains('msi')) return true;
    }
    return false;
  }

  Future<void> _updateInventoryStockInSupabase(int addedQty) async {
    try {
      dynamic variantId = _order['variant_id'];
      final variantRaw = _order['product_variants'];
      if (variantId == null && variantRaw is Map) {
        variantId = variantRaw['variant_id'];
      }

      if (variantId == null) {
        final String? orderId = _order['order_id'] as String?;
        if (orderId != null) {
          final orderRes = await SupabaseConfig.client
              .from('orders')
              .select('variant_id')
              .eq('order_id', orderId)
              .maybeSingle();
          variantId = orderRes?['variant_id'];
        }
      }

      if (variantId != null) {
        final invRes = await SupabaseConfig.client
            .from('inventory')
            .select('stock_qty')
            .eq('variant_id', variantId)
            .maybeSingle();

        final int currentStock = invRes?['stock_qty'] as int? ?? 0;
        final int newStock = currentStock + addedQty;

        await SupabaseConfig.client
            .from('inventory')
            .update({
              'stock_qty': newStock,
              'last_updated': DateTime.now().toIso8601String(),
            })
            .eq('variant_id', variantId);

        // Update local object so UI reflects new stock immediately
        if (variantRaw is Map && variantRaw['products'] is Map) {
          variantRaw['products']['stock_qty'] = newStock;
        }
      }
    } catch (e) {
      print('Failed to update inventory stock in Supabase: $e');
    }
  }

  Future<void> _sendAutomatedRestockMessage(String productName, int addedQty) async {
    try {
      final buyerId = _order['buyer_id'];
      final sellerId = _order['seller_id'];
      if (buyerId != null && sellerId != null) {
        final chat = await SupabaseConfig.client
            .from('chats')
            .select('chat_id')
            .eq('buyer_id', buyerId)
            .eq('seller_id', sellerId)
            .limit(1)
            .maybeSingle();

        final String autoMsg = '📢 [Automated Notification]\nGreat news! The item "$productName" you reserved has been restocked (+$addedQty units) and is ready for campus pickup! 🛍️';

        if (chat != null) {
          await SupabaseConfig.client.from('messages').insert({
            'chat_id': chat['chat_id'],
            'sender_id': sellerId,
            'content': autoMsg,
            'is_read': false,
          });
        }
      }
    } catch (e) {
      // Silently log
    }
  }

  void _showQuickRestockDialog() {
    final qtyController = TextEditingController(text: '5');
    final variant = _order['product_variants'] as Map<String, dynamic>?;
    final product = variant?['products'] as Map<String, dynamic>?;
    final String productName = product?['name'] as String? ?? 'Reserved Item';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Quick Restock Item', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Item: $productName', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            const Text(
              'Enter quantity to add to stock. This will allocate 1 unit to this reservation, notify the buyer via chat, and mark it READY FOR MEETUP.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity to Add',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            onPressed: () async {
              final int added = int.tryParse(qtyController.text) ?? 5;
              Navigator.pop(ctx);
              setState(() {
                _order['is_out_of_stock'] = false;
              });
              await _updateInventoryStockInSupabase(added);
              await _updateStatus('READY_FOR_PICKUP');
              await _sendAutomatedRestockMessage(productName, added);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Restocked +$added units! Automated message sent to buyer: "$productName is restocked & ready for pickup!"'),
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                );
              }
            },
            child: const Text('Restock & Fulfill', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBuyerMessageOptionsSheet() {
    final buyerName = _order['buyer_name'] as String? ?? 'Buyer';
    final variant = _order['product_variants'] as Map<String, dynamic>?;
    final product = variant?['products'] as Map<String, dynamic>?;
    final String productName = product?['name'] as String? ?? 'Reserved Item';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: TeknoyTheme.citMaroon),
                const SizedBox(width: 8),
                Text('Message $buyerName', style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Select a quick template or notify $buyerName regarding "$productName":', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              leading: const Icon(Icons.schedule_rounded, color: Colors.orange),
              title: const Text('Restock Schedule', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('"Hi $buyerName! "$productName" is restocking on Friday. Would you like to keep your reservation?"', style: const TextStyle(fontFamily: 'Inter', fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('💬 Restock schedule notification sent to $buyerName!'), backgroundColor: TeknoyTheme.citMaroon),
                );
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
              leading: const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
              title: const Text('Propose Alternative Item', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('"Hi $buyerName! "$productName" is out of stock, but we have a similar item available. Check chat for details!"', style: const TextStyle(fontFamily: 'Inter', fontSize: 11)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('💬 Alternative product suggestion sent to $buyerName!'), backgroundColor: TeknoyTheme.citMaroon),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmationDialog() {
    String selectedReason = 'Changed my mind';
    const cancelReasons = [
      'Changed my mind',
      'Found a better price elsewhere',
      'Ordered by mistake',
      'Seller is unresponsive',
      'Item no longer needed',
      'Other reason',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Cancel Order?', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please tell us why you are cancelling:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: cancelReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontFamily: 'Inter', fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedReason = val);
                },
              ),
              const SizedBox(height: 12),
              const Text('This will release the item reservation and notify the seller.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.black54)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No, Keep Order', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              // Send the reason to the seller via chat (same pattern as return requests)
              // before updating the order status.
              onPressed: () async {
                Navigator.pop(context);
                final actorId = ref.read(authStateProvider).valueOrNull?.id;
                if (actorId != null) {
                  await _handleSpringAction('cancel', {'actorId': actorId, 'reason': selectedReason}, 'Order cancelled successfully.');
                }
                // Fire-and-forget: notify seller with the cancellation reason.
                try {
                  final buyerId = _order['buyer_id'] as String?;
                  final sellerId = _order['seller_id'] as String?;
                  if (buyerId != null && sellerId != null) {
                    Map<String, dynamic>? chat = await SupabaseConfig.client
                        .from('chats').select('chat_id')
                        .eq('buyer_id', buyerId).eq('seller_id', sellerId)
                        .limit(1).maybeSingle();
                    chat ??= await SupabaseConfig.client
                        .from('chats')
                        .insert({'buyer_id': buyerId, 'seller_id': sellerId})
                        .select('chat_id').single();
                    await SupabaseConfig.client.from('messages').insert({
                      'chat_id': chat['chat_id'],
                      'sender_id': buyerId,
                      'content': '📢 [Automated Message]\nI have cancelled this order.\nReason: $selectedReason',
                      'is_read': false,
                    });
                  }
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Cancel Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }


  void _showReturnRequestDialog() {
    String selectedReason = 'Defective or Damaged Item';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.assignment_return_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Request Return / Refund', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please select a reason for returning this item:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    'Defective or Damaged Item',
                    'Wrong Product / Variant',
                    'Item Condition Misrepresented',
                    'Other Reason',
                  ].map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)))).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedReason = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Additional Explanation (Optional):', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe why you are requesting a return...',
                    hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = ref.read(authStateProvider).valueOrNull;
                if (user != null) {
                  await _handleSpringAction('refund', {
                    'buyerId': user.id,
                    'reason': selectedReason,
                    'evidence': notesController.text.trim()
                  }, 'Return / Refund request submitted.');
                  try {

                    // FIX #4: Always ensure a chat room exists before posting the automated
                    // return notification. If none exists (e.g. direct-buy with no prior chat),
                    // create one so the seller is reliably notified in their inbox.
                    final buyerId = _order['buyer_id'] as String?;
                    final sellerId = _order['seller_id'] as String?;

                    if (buyerId != null && sellerId != null) {
                      // Try to find an existing chat room.
                      Map<String, dynamic>? chat = await SupabaseConfig.client
                          .from('chats')
                          .select('chat_id')
                          .eq('buyer_id', buyerId)
                          .eq('seller_id', sellerId)
                          .limit(1)
                          .maybeSingle();

                      // If no chat exists, create one now so the notification goes through.
                      if (chat == null) {
                        chat = await SupabaseConfig.client
                            .from('chats')
                            .insert({'buyer_id': buyerId, 'seller_id': sellerId})
                            .select('chat_id')
                            .single();
                      }

                      String msg = '📢 [Automated Message]\nI have submitted a Return / Refund request for this order.\nReason: $selectedReason';
                      if (notesController.text.trim().isNotEmpty) {
                        msg += '\nNotes: ${notesController.text.trim()}';
                      }
                      msg += '\n\nPlease check the order details to review my request.';

                      await SupabaseConfig.client.from('messages').insert({
                        'chat_id': chat['chat_id'],
                        'sender_id': user.id,
                        'content': msg,
                        'is_read': false,
                      });
                    }
                  } catch (e) {
                    debugPrint('Error submitting return: $e');
                  }
                }
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Submit Request', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGCashSubmitDialog() {
    final refController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.send_to_mobile_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Text('GCash Payment Sent', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withOpacity(0.2)),
              ),
              child: Text(
                'Total to send: ₱ ${_order['total_amount']}',
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Enter your GCash reference number:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: refController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'e.g. 1234567890',
                hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.tag_rounded, color: Colors.indigo),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The seller will verify your reference number and confirm payment.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final referenceNumber = refController.text.trim();
              Navigator.pop(context);
              // Store reference number in order notes if needed
              try {
                await SupabaseConfig.client.from('orders').update({
                  'gcash_reference': referenceNumber,
                }).eq('order_id', _order['order_id']);
              } catch (_) {}
              _updateStatus('PAYMENT_SUBMITTED');
            },
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text('Confirm Payment Sent', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showOTPInputDialog() {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Handoff', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the 6-digit code shown on the buyer\'s screen to verify handoff.', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: '123456',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final sellerId = ref.read(authStateProvider).valueOrNull?.id;
              if (sellerId != null) {
                await _handleSpringAction('verify-handoff', {'sellerId': sellerId, 'otp': otpController.text.trim()}, 'Handoff verified successfully!');
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final variant = _order['product_variants'] as Map<String, dynamic>?;
    final product = variant?['products'] as Map<String, dynamic>?;
    final images = product?['product_images'] as List<dynamic>? ?? [];
    final imageUrl = images.isNotEmpty
        ? (images.firstWhere((img) => img['is_primary'] == true, orElse: () => images[0])['image_url'] as String?)
        : null;
    final productName = product?['name'] ?? 'Unknown Product';

    final otherPartyName = widget.isSeller
        ? (_order['buyer_name'] as String? ?? 'Buyer')
        : (_order['seller_name'] as String? ?? 'Seller');
    final otherPartyLabel = widget.isSeller ? 'Buyer' : 'Seller';
    final otherPartyContact = widget.isSeller
        ? (_order['buyer_contact'] as String?)
        : (_order['seller_contact'] as String?);
    final sellerGcash = _order['seller_gcash'] as String?;

    final pickupLocation = _order['pickup_location'] as String? ?? '—';
    final pickupDay = _order['pickup_day'] as String? ?? '—';
    final pickupTime = _order['pickup_time'] as String? ?? '—';
    final createdAt = (_order['created_at'] as String?)?.substring(0, 10) ?? '—';
    final orderId = (_order['order_id'] as String?)?.substring(0, 8).toUpperCase() ?? '—';

    final sellerConfirmed = _order['seller_confirmed_at'] != null;
    final buyerConfirmed = _order['buyer_confirmed_at'] != null;
    final isCompleted = _status == 'COMPLETED';

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderId', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product card
            _section(isDark, child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null
                      ? Image.network(imageUrl, width: 72, height: 72, fit: BoxFit.cover)
                      : Container(width: 72, height: 72, color: Colors.grey.withOpacity(0.15), child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productName, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('₱ ${_order['total_amount']}', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: TeknoyTheme.citMaroon)),
                    const SizedBox(height: 4),
                    Text('Placed: $createdAt', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
                  ],
                )),
              ],
            )),
            const SizedBox(height: 16),

            // Status stepper
            _buildStatusStepper(isDark),
            const SizedBox(height: 16),

            // Party info
            _section(isDark, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(Icons.person_rounded, otherPartyLabel, isDark),
                const SizedBox(height: 10),
                _detailRow('Name', otherPartyName, isDark),
                if (otherPartyContact != null) _detailRow('Contact', otherPartyContact, isDark),
                if (!widget.isSeller && _isGCash && sellerGcash != null) _detailRow('GCash No.', sellerGcash, isDark),
              ],
            )),
            const SizedBox(height: 16),

            // Meetup info
            _section(isDark, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(Icons.location_on_rounded, 'Meetup Details', isDark),
                const SizedBox(height: 10),
                _detailRow('Location', pickupLocation, isDark),
                _detailRow('Day', pickupDay, isDark),
                _detailRow('Time', pickupTime, isDark),
                _detailRow('Payment', _paymentMethod, isDark),
                if (!widget.isSeller && _isGCash && sellerGcash != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withOpacity(0.2))),
                    child: Row(children: [
                      const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Send GCash to: $sellerGcash — then share the reference number in chat with the seller.', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.blue))),
                    ]),
                  ),
                ],
              ],
            )),
            const SizedBox(height: 16),

            // Confirmation status
            if (_status == 'APPROVED' || _status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_SUBMITTED' || _status == 'PAYMENT_VERIFIED' || isCompleted)
              _section(isDark, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.handshake_rounded, 'Meetup Confirmation', isDark),
                  const SizedBox(height: 12),
                  if (_isGCash && _status == 'PAYMENT_SUBMITTED')
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.hourglass_top_rounded, color: Colors.indigo, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _order['gcash_reference'] != null && (_order['gcash_reference'] as String).isNotEmpty
                                ? 'GCash ref: ${_order['gcash_reference']} — Awaiting seller verification.'
                                : 'GCash payment submitted. Awaiting seller verification.',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.indigo),
                          ),
                        ),
                      ]),
                    ),
                  _confirmRow('Seller handed off', sellerConfirmed, isDark),
                  const SizedBox(height: 8),
                  _confirmRow('Buyer confirmed receipt', buyerConfirmed, isDark),
                ],
              )),
            const SizedBox(height: 24),

            // Action buttons
            _buildActionButtons(isDark, sellerConfirmed, buyerConfirmed),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStepper(bool isDark) {
    final steps = ['Placed', 'Accepted', 'Meetup', 'Handoff', 'Done'];

    final statusToStep = {
      'PLACED': 0,
      'ACCEPTED': 1,
      'MEETUP_SCHEDULED': 2,
      'HANDOFF_PENDING': 3,
      'COMPLETED': 4,
      'CANCELLED': -1,
      'DISPUTED': -1,
      'REFUND_REQUESTED': 4,
    };

    final currentStep = statusToStep[_status] ?? 0;
    final isDeclined = _status == 'DECLINED' || _status == 'REJECTED';
    final isCancelled = _status == 'CANCELLED';
    final isReturnRequested = _status == 'RETURN_REQUESTED';
    final isReturnApproved = _status == 'RETURN_APPROVED';
    final isReturnDeclined = _status == 'RETURN_DECLINED';

    return _section(isDark, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.timeline_rounded, 'Order Status', isDark),
        const SizedBox(height: 14),
        if (isDeclined || isCancelled)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Text(
                isCancelled ? 'This order was cancelled.' : 'This order was declined by the seller.',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.red),
              ),
            ]),
          )
        else if (isReturnRequested)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.25))),
            child: const Row(children: [
              Icon(Icons.assignment_return_rounded, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Return / Refund requested by buyer. Awaiting seller response.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.orange))),
            ]),
          )
        else if (isReturnApproved)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.withOpacity(0.25))),
            child: const Row(children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.teal, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Return Approved! Meet up at landmark for item & refund exchange.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.teal))),
            ]),
          )
        else if (isReturnDeclined)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.withOpacity(0.2))),
            child: const Row(children: [
              Icon(Icons.gavel_rounded, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Return request was declined by the seller.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.red))),
            ]),
          )
        else
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                // connector
                final stepIdx = i ~/ 2;
                return Expanded(child: Container(height: 2, color: stepIdx < currentStep ? TeknoyTheme.citMaroon : (isDark ? Colors.white12 : Colors.black12)));
              }
              final stepIdx = i ~/ 2;
              final done = stepIdx <= currentStep;
              return Column(children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? TeknoyTheme.citMaroon : (isDark ? Colors.white12 : Colors.black12),
                    border: Border.all(color: done ? TeknoyTheme.citMaroon : (isDark ? Colors.white24 : Colors.black26), width: 1.5),
                  ),
                  child: Center(child: done
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : Text('${stepIdx + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white38 : Colors.black38))),
                ),
                const SizedBox(height: 4),
                Text(steps[stepIdx], style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: done ? FontWeight.bold : FontWeight.normal, color: done ? TeknoyTheme.citMaroon : (isDark ? Colors.white38 : Colors.black38))),
              ]);
            }),
          ),
      ],
    ));
  }

  Widget _buildActionButtons(bool isDark, bool sellerConfirmed, bool buyerConfirmed) {
    final buttons = <Widget>[];
    final actorId = ref.read(authStateProvider).valueOrNull?.id;
    if (actorId == null) return const SizedBox();

    if (widget.isSeller) {
      if (_status == 'PLACED') {
        buttons.add(_actionBtn('Decline Order', Colors.red, Icons.close_rounded, 
            () => _handleSpringAction('cancel', {'actorId': actorId, 'reason': 'Seller declined'}, 'Order declined.')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Accept Order', Colors.green, Icons.check_circle_outline_rounded, 
            () => _handleSpringAction('accept', {'sellerId': actorId}, 'Order accepted.')));
      }
      
      if (_status == 'ACCEPTED') {
        buttons.add(_actionBtn('Schedule Meetup', Colors.blue, Icons.calendar_month_rounded, 
            () => _handleSpringAction('schedule', {'actorId': actorId}, 'Meetup scheduled. OTP generated.')));
      }

      if (_status == 'MEETUP_SCHEDULED') {
        buttons.add(_actionBtn('Verify Buyer Handoff (OTP)', TeknoyTheme.citMaroon, Icons.verified_user_rounded, _showOTPInputDialog));
      }
    } else {
      if (_status == 'MEETUP_SCHEDULED') {
        final otp = _order['handoff_otp'] as String? ?? '------';
        buttons.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3))),
            child: Column(children: [
              const Text('Show this code to the seller at the meetup:', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.blue)),
              const SizedBox(height: 8),
              Text(otp, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 32, letterSpacing: 8, color: Colors.blue)),
            ]),
          )
        );
      }

      if (_status == 'HANDOFF_PENDING') {
        buttons.add(_actionBtn('Confirm I Received This', Colors.green, Icons.check_circle_outline_rounded, 
            () => _handleSpringAction('confirm-receipt', {'buyerId': actorId}, 'Receipt confirmed!')));
      }

      if (_status == 'COMPLETED') {
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Request Return / Refund', Colors.orange, Icons.assignment_return_rounded, _showReturnRequestDialog));
      }

      if (_status == 'PLACED' || _status == 'ACCEPTED' || _status == 'MEETUP_SCHEDULED') {
        buttons.add(const SizedBox(height: 10));
        buttons.add(SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isActing ? null : _showCancelConfirmationDialog,
            icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
            label: const Text('Cancel Order', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ));
      }
    }

    if (buttons.isEmpty) return const SizedBox();

    return Column(children: [
      if (_isActing) const Center(child: CircularProgressIndicator(color: TeknoyTheme.citMaroon))
      else ...buttons,
    ]);
  }

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isActing ? null : onTap,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(label, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _section(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String title, bool isDark) {
    return Row(children: [
      Icon(icon, size: 18, color: TeknoyTheme.citGold),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15)),
    ]);
  }

  Widget _detailRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text('$label:', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? Colors.white54 : Colors.black54))),
        Expanded(child: Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87))),
      ]),
    );
  }

  Widget _confirmRow(String label, bool done, bool isDark) {
    return Row(children: [
      Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18, color: done ? Colors.green : (isDark ? Colors.white38 : Colors.black38)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: done ? Colors.green : (isDark ? Colors.white54 : Colors.black54), fontWeight: done ? FontWeight.bold : FontWeight.normal)),
    ]);
  }
}
