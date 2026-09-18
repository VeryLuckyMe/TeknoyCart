import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:teknoycart/core/services/secure_token_service.dart';

const String backendUrl = 'https://teknoycart-backend.onrender.com/api/orders';

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
    _refreshOrder();
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
    final token = await SecureTokenService.getBearerToken();
    final url = Uri.parse('$backendUrl/${_order['order_id']}/$action');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode >= 400) {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
    try {
      if (response.body.isNotEmpty) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              if (data['handoffOtp'] != null) _order['handoff_otp'] = data['handoffOtp'].toString();
              if (data['status'] != null) _order['status'] = data['status'];
              if (data['sellerHandedOff'] != null) _order['seller_handed_off'] = data['sellerHandedOff'];
              if (data['buyerConfirmedReceipt'] != null) _order['buyer_confirmed_receipt'] = data['buyerConfirmedReceipt'];
              if (data['handoffCompletedAt'] != null) _order['handoff_completed_at'] = data['handoffCompletedAt'];
              if (data['returnOtp'] != null) _order['return_otp'] = data['returnOtp'].toString();
              if (data['refundReference'] != null) _order['refund_reference'] = data['refundReference'];
              if (data['disputeReason'] != null) _order['dispute_reason'] = data['disputeReason'];
              if (data['disputeRuling'] != null) _order['dispute_ruling'] = data['disputeRuling'];
              if (data['returnCompletedAt'] != null) _order['return_completed_at'] = data['returnCompletedAt'];
            });
          }
        }
      }
    } catch (_) {}
  }

  String get _status {
    final raw = _order['status'] as String? ?? '';
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
            handoff_otp, seller_handed_off, buyer_confirmed_receipt,
            handoff_completed_at, return_otp, refund_reference,
            dispute_reason, dispute_ruling, return_completed_at,
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
              const Text('This will release the item reservation and notify the other party.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.black54)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No, Keep Order', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final actorId = ref.read(authStateProvider).valueOrNull?.id;
                if (actorId != null) {
                  await _handleSpringAction('cancel', {'reason': selectedReason}, 'Order cancelled successfully.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Cancel Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoShowDialog() {
    String selectedReason = 'Other party did not appear at landmark';
    const noShowReasons = [
      'Other party did not appear at landmark',
      'Waited over 20 minutes with no contact',
      'Other party unreachable in campus chat',
      'Other party cancelled at last minute',
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.person_off_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Report No-Show', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Please select the reason for reporting a no-show:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: noShowReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontFamily: 'Inter', fontSize: 13))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedReason = val);
                },
              ),
              const SizedBox(height: 12),
              Text(
                _isGCash
                    ? 'Because payment was attached, this report will open an Admin Mediation Dispute to resolve funds.'
                    : 'This will cancel the order and release the item reservation.',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _handleSpringAction('report-no-show', {'reason': selectedReason}, 'No-show report submitted.');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm No-Show', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                const Text('Additional Explanation / Evidence:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Describe defect or issue...',
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
                  Navigator.pop(context);
                  await _handleSpringAction('refund', {
                    'reason': selectedReason,
                    'evidence': notesController.text.trim().isNotEmpty ? notesController.text.trim() : 'Defect reported by buyer'
                  }, 'Return request submitted to seller.');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Submit Request', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeclineReturnDialog() {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.gavel_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Decline Return Request', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Declining will escalate this order to Admin Dispute Mediation. Please specify your reason:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g. Item was verified functional at handoff...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _handleSpringAction('decline-return', {
                'reason': reasonController.text.trim()
              }, 'Return declined. Escalated to Admin Dispute Mediation.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline & Escalate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReturnOTPInputDialog() {
    final otpController = TextEditingController();
    final refundRefController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.assignment_return_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('Verify Return Handoff', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Inspect the returned physical item. Enter the 6-digit code shown on buyer\'s phone:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: 'e.g. 123456',
                  prefixIcon: const Icon(Icons.pin_rounded, color: Colors.teal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              if (_isGCash) ...[
                const SizedBox(height: 8),
                const Text('GCash Refund Ref (if transferred):', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: refundRefController,
                  decoration: InputDecoration(
                    hintText: 'e.g. 9876543210',
                    prefixIcon: const Icon(Icons.receipt_rounded, color: Colors.teal),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final otp = otpController.text.trim();
              if (otp.isEmpty) return;
              Navigator.pop(context);
              final body = <String, dynamic>{'otp': otp};
              if (refundRefController.text.trim().isNotEmpty) {
                body['refund_reference'] = refundRefController.text.trim();
              }
              await _handleSpringAction('verify-return-handoff', body, 'Return handoff verified successfully!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text('Confirm Return', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConfirmRefundDialog() {
    final refController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.currency_exchange_rounded, color: Colors.green),
            SizedBox(width: 8),
            Text('Issue GCash Refund', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transfer ₱ ${_order['total_amount']} back to buyer\'s GCash, then enter transaction reference number:', style: const TextStyle(fontFamily: 'Inter', fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: refController,
              decoration: InputDecoration(
                hintText: 'e.g. 9876543210',
                prefixIcon: const Icon(Icons.receipt_long_rounded, color: Colors.green),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final refText = refController.text.trim();
              if (refText.isEmpty) return;
              Navigator.pop(context);
              await _handleSpringAction('confirm-refund', {'refund_reference': refText}, 'Refund issued and confirmed!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm Refund', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
              await _handleSpringAction('submit-payment', {
                'payment_reference': referenceNumber,
              }, 'GCash reference submitted! Awaiting seller verification.');
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
            const Text('Enter the 6-digit code shown on buyer\'s phone to complete handoff:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
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
                await _handleSpringAction('verify-handoff', {'otp': otpController.text.trim()}, 'Handoff verified successfully!');
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Widget _buildGuaranteeBanner(bool isDark) {
    if (_status != 'HANDOFF_PENDING') return const SizedBox.shrink();

    DateTime? handoffTime;
    if (_order['handoff_completed_at'] != null) {
      handoffTime = DateTime.tryParse(_order['handoff_completed_at'].toString());
    }
    handoffTime ??= DateTime.tryParse(_order['created_at']?.toString() ?? '') ?? DateTime.now();

    final expireTime = handoffTime.add(const Duration(hours: 24));
    final remaining = expireTime.difference(DateTime.now());
    final hoursLeft = remaining.inHours.clamp(0, 24);
    final minutesLeft = (remaining.inMinutes % 60).clamp(0, 59);
    final isExpiringSoon = remaining.inHours < 4;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isExpiringSoon ? Colors.red.withOpacity(0.08) : Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpiringSoon ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: isExpiringSoon ? Colors.red : Colors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '24-Hour TeknoyCart Guarantee Active',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isExpiringSoon ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            remaining.isNegative
                ? 'Inspection window has elapsed. Transaction is finalizing.'
                : 'You have ${hoursLeft}h ${minutesLeft}m remaining in your guarantee inspection window. Test your item thoroughly. If defective or misrepresented, request a return before this window closes.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
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
    final isCompleted = _status == 'COMPLETED' || _status == 'RETURN_COMPLETED' || _status == 'REFUND_COMPLETED';

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

            // 24-Hour Guarantee Banner
            _buildGuaranteeBanner(isDark),

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
                      Expanded(child: Text('Send GCash to: $sellerGcash — then submit the reference number below.', style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.blue))),
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
                  _sectionTitle(Icons.handshake_rounded, 'Transaction Details', isDark),
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
                            ((_order['payment_reference'] != null && (_order['payment_reference'] as String).isNotEmpty)
                                    ? 'GCash ref: ${_order['payment_reference']} — Awaiting seller verification.'
                                    : 'GCash payment submitted. Awaiting seller verification.'),
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.indigo),
                          ),
                        ),
                      ]),
                    ),
                  _confirmRow('Seller handed off', sellerConfirmed || _order['seller_handed_off'] == true, isDark),
                  const SizedBox(height: 8),
                  _confirmRow('Buyer confirmed receipt', buyerConfirmed || _order['buyer_confirmed_receipt'] == true, isDark),
                  if (_order['refund_reference'] != null && (_order['refund_reference'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detailRow('Refund Ref', _order['refund_reference'], isDark),
                  ],
                  if (_order['dispute_ruling'] != null && (_order['dispute_ruling'] as String).isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _detailRow('Admin Ruling', _order['dispute_ruling'], isDark),
                  ],
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
      'PAYMENT_SUBMITTED': 1,
      'PAYMENT_VERIFIED': 1,
      'MEETUP_SCHEDULED': 2,
      'NEEDS_REVIEW': 2,
      'HANDOFF_PENDING': 3,
      'COMPLETED': 4,
      'RETURN_COMPLETED': 4,
      'REFUND_COMPLETED': 4,
      'CANCELLED': -1,
      'DISPUTED': -1,
      'RETURN_REQUESTED': 3,
      'RETURN_APPROVED': 3,
      'REFUND_REQUESTED': 1,
    };

    final currentStep = statusToStep[_status] ?? 0;
    final isDeclined = _status == 'DECLINED' || _status == 'REJECTED';
    final isCancelled = _status == 'CANCELLED';
    final isNeedsReview = _status == 'NEEDS_REVIEW';
    final isDisputed = _status == 'DISPUTED';
    final isReturnRequested = _status == 'RETURN_REQUESTED';
    final isReturnApproved = _status == 'RETURN_APPROVED';
    final isReturnCompleted = _status == 'RETURN_COMPLETED';
    final isRefundCompleted = _status == 'REFUND_COMPLETED';
    final isRefundRequested = _status == 'REFUND_REQUESTED';

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
        else if (isDisputed)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.purple.withOpacity(0.3))),
            child: const Row(children: [
              Icon(Icons.gavel_rounded, color: Colors.purple, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Under Admin Mediation. Campus administrators are adjudicating this dispute.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.purple))),
            ]),
          )
        else if (isNeedsReview)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.amber.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber.withOpacity(0.4))),
            child: const Row(children: [
              Icon(Icons.schedule_rounded, color: Colors.amber, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Meetup timed out (>24h) or had failed attempts. Reschedule meetup or report no-show.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.amber))),
            ]),
          )
        else if (isReturnRequested)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.withOpacity(0.25))),
            child: const Row(children: [
              Icon(Icons.assignment_return_rounded, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Return requested by buyer. Awaiting seller review.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.orange))),
            ]),
          )
        else if (isReturnApproved)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.teal.withOpacity(0.25))),
            child: const Row(children: [
              Icon(Icons.check_circle_outline_rounded, color: Colors.teal, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Return Approved! Meet up at landmark to return item & verify return code.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.teal))),
            ]),
          )
        else if (isReturnCompleted)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.25))),
            child: const Row(children: [
              Icon(Icons.verified_rounded, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Return Completed! Item returned and cash refunded at the meetup.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.green))),
            ]),
          )
        else if (isRefundCompleted)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green.withOpacity(0.25))),
            child: const Row(children: [
              Icon(Icons.verified_rounded, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Refund Completed! GCash refund transaction has been verified.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.green))),
            ]),
          )
        else if (isRefundRequested)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.indigo.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.indigo.withOpacity(0.25))),
            child: const Row(children: [
              Icon(Icons.currency_exchange_rounded, color: Colors.indigo, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text('Refund Requested. Awaiting seller to return GCash payment.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.indigo))),
            ]),
          )
        else
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
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
            () => _handleSpringAction('cancel', {'reason': 'Seller declined'}, 'Order declined.')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Accept Order', Colors.green, Icons.check_circle_outline_rounded, 
            () => _handleSpringAction('accept', {}, 'Order accepted.')));
      }
      
      if (_status == 'ACCEPTED' || _status == 'PAYMENT_VERIFIED') {
        buttons.add(_actionBtn('Schedule Meetup', Colors.blue, Icons.calendar_month_rounded, 
            () => _handleSpringAction('schedule', {}, 'Meetup scheduled. OTP code generated.')));
      }

      if (_status == 'NEEDS_REVIEW') {
        buttons.add(_actionBtn('Reschedule Meetup', Colors.blue, Icons.refresh_rounded, 
            () => _handleSpringAction('schedule', {}, 'Meetup rescheduled. New OTP generated.')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Report No-Show', Colors.orange, Icons.person_off_rounded, _showNoShowDialog));
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

      if (_isGCash && _status == 'PAYMENT_SUBMITTED') {
        buttons.add(_actionBtn('Verify GCash Payment', Colors.teal, Icons.verified_rounded, 
            () => _handleSpringAction('verify-payment', {}, 'GCash payment verified!')));
        buttons.add(const SizedBox(height: 10));
      }

      if (_status == 'MEETUP_SCHEDULED') {
        buttons.add(_actionBtn('Verify Buyer Handoff (OTP)', TeknoyTheme.citMaroon, Icons.verified_user_rounded, _showOTPInputDialog));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Report No-Show', Colors.orange, Icons.person_off_rounded, _showNoShowDialog));
      }

      if (_status == 'RETURN_REQUESTED') {
        buttons.add(_actionBtn('Approve Return & Meetup', Colors.teal, Icons.check_circle_outline_rounded, 
            () => _handleSpringAction('approve-return', {}, 'Return approved! Return code generated.')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Decline Return Request', Colors.red, Icons.close_rounded, _showDeclineReturnDialog));
      }

      if (_status == 'RETURN_APPROVED') {
        buttons.add(_actionBtn('Verify Return Handoff (Enter OTP)', Colors.teal, Icons.assignment_return_rounded, _showReturnOTPInputDialog));
      }

      if (_status == 'REFUND_REQUESTED') {
        buttons.add(_actionBtn('Issue GCash Refund', Colors.green, Icons.currency_exchange_rounded, _showConfirmRefundDialog));
      }
    } else {
      // Buyer actions
      if (_isGCash && (_status == 'PLACED' || _status == 'ACCEPTED' || _status == 'APPROVED')) {
        buttons.add(_actionBtn('Submit GCash Reference', Colors.indigo, Icons.receipt_long_rounded, _showGCashSubmitDialog));
        buttons.add(const SizedBox(height: 10));
      }

      if (_status == 'NEEDS_REVIEW') {
        buttons.add(_actionBtn('Reschedule Meetup', Colors.blue, Icons.refresh_rounded, 
            () => _handleSpringAction('schedule', {}, 'Meetup rescheduled. New code generated.')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Report No-Show', Colors.orange, Icons.person_off_rounded, _showNoShowDialog));
      }

      if (_status == 'MEETUP_SCHEDULED') {
        final otp = (_order['handoff_otp'] != null && _order['handoff_otp'].toString().isNotEmpty)
            ? _order['handoff_otp'].toString()
            : '------';
        buttons.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withOpacity(0.3))),
            child: Column(children: [
              const Text('Show this code to the seller at the meetup:', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.blue)),
              const SizedBox(height: 8),
              Text(otp, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 32, letterSpacing: 8, color: Colors.blue)),
              if (otp == '------') ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isActing ? null : () => _handleSpringAction('schedule', {}, 'Meetup code generated!'),
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.blue),
                  label: const Text('Generate Code Now', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.blue)),
                ),
              ],
            ]),
          )
        );
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Report No-Show', Colors.orange, Icons.person_off_rounded, _showNoShowDialog));
      }

      if (_status == 'HANDOFF_PENDING') {
        buttons.add(_actionBtn('Confirm I Received This', Colors.green, Icons.check_circle_outline_rounded, 
            () => _handleSpringAction('confirm-receipt', {}, 'Receipt confirmed! Order completed.')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Request Return / Refund', Colors.orange, Icons.assignment_return_rounded, _showReturnRequestDialog));
      }

      if (_status == 'COMPLETED') {
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Request Return / Refund', Colors.orange, Icons.assignment_return_rounded, _showReturnRequestDialog));
      }

      if (_status == 'RETURN_APPROVED') {
        final returnOtp = (_order['return_otp'] != null && _order['return_otp'].toString().isNotEmpty)
            ? _order['return_otp'].toString()
            : '------';
        buttons.add(
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal.withOpacity(0.3))),
            child: Column(children: [
              const Text('Show this return code to seller at return meetup:', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.teal)),
              const SizedBox(height: 8),
              Text(returnOtp, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 32, letterSpacing: 8, color: Colors.teal)),
            ]),
          )
        );
      }

      if (_status == 'REFUND_REQUESTED') {
        buttons.add(_actionBtn('Escalate to Admin Mediation', Colors.purple, Icons.gavel_rounded, 
            () => _handleSpringAction('dispute', {'reason': 'Seller unresponsive to refund request'}, 'Dispute opened with Admin.')));
      }

      if (_status == 'PLACED' || _status == 'ACCEPTED' || _status == 'NEEDS_REVIEW') {
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
        SizedBox(width: 100, child: Text('$label:', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? Colors.white54 : Colors.black54))),
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
