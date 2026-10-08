import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:teknoycart/core/services/secure_token_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:teknoycart/features/chat/views/chat_view.dart';
import 'package:teknoycart/features/chat/services/chat_service.dart';
import 'package:teknoycart/core/models/product.dart';
import 'widgets/order_status_stepper.dart';
import 'widgets/qr_scanner_sheet.dart';
import 'package:teknoycart/core/models/review.dart';
import 'package:teknoycart/features/feed/providers/review_provider.dart';
import 'package:teknoycart/features/feed/views/widgets/review_submission_sheet.dart';

const String backendUrl = 'https://teknoycart-backend.onrender.com/api/orders';

/// Full-screen order detail view with status stepper, party info, cancellation & return request capabilities.
class OrderDetailView extends ConsumerStatefulWidget {
  final Map<String, dynamic> order;
  final bool isSeller;

  const OrderDetailView({super.key, required this.order, required this.isSeller});

  @override
  ConsumerState<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends ConsumerState<OrderDetailView> with WidgetsBindingObserver {
  late Map<String, dynamic> _order;
  bool _isActing = false;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOrder();
    }
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
              if (data['paymongoCheckoutUrl'] != null) _order['paymongo_checkout_url'] = data['paymongoCheckoutUrl'];
              if (data['paymongoCheckoutSessionId'] != null) _order['paymongo_checkout_session_id'] = data['paymongoCheckoutSessionId'];
              if (data['paymentExpiresAt'] != null) _order['payment_expires_at'] = data['paymentExpiresAt'];
              if (data['amountCentavos'] != null) _order['amount_centavos'] = data['amountCentavos'];
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

  bool get _isPreorder {
    if (_order['is_preorder'] == true) return true;
    final loc = _order['pickup_location']?.toString() ?? '';
    final day = _order['pickup_day']?.toString() ?? '';
    final variant = _order['product_variants'] as Map<String, dynamic>?;
    final prod = variant?['products'] as Map<String, dynamic>?;
    return loc.contains('[PRE-ORDER]') ||
        day.contains('3-7') ||
        day.contains('Batch') ||
        prod?['is_preorder_enabled'] == true;
  }

  Product _extractProductFromOrder() {
    final variant = _order['product_variants'] as Map<String, dynamic>?;
    final prod = variant?['products'] as Map<String, dynamic>?;
    final images = prod?['product_images'] as List<dynamic>? ?? [];
    final imgUrl = images.isNotEmpty
        ? (images.firstWhere((img) => img['is_primary'] == true, orElse: () => images[0])['image_url'] as String?)
        : null;
    return Product(
      id: prod?['product_id'] as String? ?? 'prod-${_order['order_id']}',
      title: prod?['name'] as String? ?? 'Campus Product',
      description: prod?['description'] as String? ?? '',
      price: double.tryParse(_order['total_amount']?.toString() ?? '0') ?? 0.0,
      category: 'Campus Gear',
      condition: 'Like New',
      sellerId: _order['seller_id'] as String? ?? '',
      imageUrl: imgUrl,
      isPreorderEnabled: _isPreorder,
      createdAt: DateTime.tryParse(_order['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Future<void> _openChatWithOtherParty() async {
    try {
      final buyerId = _order['buyer_id'] as String?;
      final sellerId = _order['seller_id'] as String?;
      if (buyerId == null || sellerId == null) return;
      final product = _extractProductFromOrder();

      final chatService = ChatService();
      final roomId = await chatService.getOrCreateChatRoom(
        buyerId: buyerId,
        sellerId: sellerId,
        productId: product.id,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatView(product: product, roomId: roomId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open chat: $e')),
        );
      }
    }
  }

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
            dispute_reason, dispute_ruling, return_completed_at, is_preorder,
            paymongo_checkout_session_id, paymongo_checkout_url, payment_expires_at, amount_centavos, payout_released,
            product_variants (
              variant_id,
              variant_value,
              products ( product_id, name, base_price, description, is_preorder_enabled, product_images (image_url, is_primary) )
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

  Future<void> _initiateGcashPayment() async {
    setState(() => _isActing = true);
    try {
      final token = await SecureTokenService.getBearerToken();
      final url = Uri.parse('$backendUrl/${_order['order_id']}/initiate-payment');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({}),
      );
      if (response.statusCode >= 400) {
        throw Exception('Payment initiation failed: ${response.statusCode} - ${response.body}');
      }
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final checkoutUrl = data['checkoutUrl'] as String?;
        if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
          final uri = Uri.parse(checkoutUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            throw Exception('Could not open payment link: $checkoutUrl');
          }
        }
      }
      await _refreshOrder();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start GCash checkout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  void _openReviewSheet(Product product, String orderId, String? variantName, Review? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReviewSubmissionSheet(
        productId: product.id,
        productTitle: product.title,
        productImageUrl: product.imageUrl,
        orderId: orderId,
        sellerId: product.sellerId,
        variantName: variantName,
        existingReview: existing,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openQrScanner(
                    title: 'Scan Return Meetup QR',
                    onScanned: (scannedCode) async {
                      final body = <String, dynamic>{'otp': scannedCode};
                      if (refundRefController.text.trim().isNotEmpty) {
                        body['refund_reference'] = refundRefController.text.trim();
                      }
                      await _handleSpringAction('verify-return-handoff', body, 'Return handoff verified successfully!');
                    },
                    onManualRequested: _showReturnOTPInputDialog,
                  );
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
                label: const Text('Scan Return QR Code', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OR ENTER CODE', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 14),
              const Text('Inspect the returned physical item. Enter the 6-digit code shown on buyer\'s phone:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 6),
                decoration: InputDecoration(
                  hintText: '123456',
                  counterText: '',
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

  void _showNotifyItemReadyDialog({required bool isPreorder}) async {
    final variant = _order['product_variants'] as Map<String, dynamic>?;
    final product = variant?['products'] as Map<String, dynamic>?;
    final productName = product?['name'] as String? ?? 'Campus Product';
    final variantId = variant?['variant_id'] as String?;

    int liveStockQty = 0;
    if (variantId != null) {
      try {
        final invRes = await SupabaseConfig.client
            .from('inventory')
            .select('stock_qty')
            .eq('variant_id', variantId)
            .maybeSingle();
        if (invRes != null && invRes['stock_qty'] != null) {
          liveStockQty = (invRes['stock_qty'] as num).toInt();
        }
      } catch (_) {}
    }

    if (!mounted) return;

    final landmarks = ['Library Lobby', 'Canteen Area', 'Science Building Lobby', 'Admin Building Vestibule', 'Wildcat Circle'];
    final timeSlots = [
      '09:00 AM - 10:30 AM',
      '12:00 PM - 01:30 PM',
      '03:00 PM - 04:30 PM',
      '05:00 PM - 06:30 PM',
    ];

    String rawLoc = (_order['pickup_location'] as String? ?? '').replaceAll('[PRE-ORDER] ', '').trim();
    String selectedLandmark = landmarks.contains(rawLoc) ? rawLoc : landmarks.first;

    String rawTime = (_order['pickup_time'] as String? ?? '').trim();
    String selectedTime = timeSlots.contains(rawTime) ? rawTime : '12:00 PM - 01:30 PM';

    String selectedDay = 'Today';
    final dayOptions = ['Today', 'Tomorrow', 'Next Business Day'];

    String generateMessage(String landmark, String day, String time) {
      if (isPreorder) {
        return 'GOOD NEWS! Your pre-order for "$productName" has arrived on campus and is ready for pickup!\n\nMeetup Location: $landmark\nDate: $day\nTime: $time\n\nPlease bring exact payment / your CIT-U ID. See you on campus!';
      } else {
        return 'Hi! I\'m ready to meet up on campus for "$productName".\n\nMeetup Location: $landmark\nDate: $day\nTime: $time\n\nSee you on campus!';
      }
    }

    final messageController = TextEditingController(text: generateMessage(selectedLandmark, selectedDay, selectedTime));
    bool isCustomized = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          void updateTextIfNotCustomized() {
            if (!isCustomized) {
              messageController.text = generateMessage(selectedLandmark, selectedDay, selectedTime);
            }
          }

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B1B20) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: TeknoyTheme.citMaroon.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isPreorder ? Icons.campaign_rounded : Icons.calendar_month_rounded,
                          color: TeknoyTheme.citMaroon,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPreorder ? 'Pre-Order Ready for Meetup' : 'Finalize Meetup Schedule',
                              style: const TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isPreorder
                                  ? 'Notify buyer via chat & generate handoff OTP'
                                  : 'Confirm date, location & notify buyer',
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
                  const SizedBox(height: 16),

                  // Buyer's requested preference highlight
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TeknoyTheme.citGold.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: TeknoyTheme.citGold.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: TeknoyTheme.citGold, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Buyer requested: $rawLoc • $rawTime',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Advisory banner if physical stock is 0
                  if (liveStockQty == 0) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Colors.amber, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Inventory notice: Listing currently shows 0 stock. Please ensure your received batch has been logged via Manage Listings so physical handoff deductions balance.',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Colors.amber),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Meetup Day Selector
                  const Text('1. Meetup Day', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: dayOptions.map((day) {
                      final isSel = selectedDay == day;
                      return ChoiceChip(
                        label: Text(day, style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87))),
                        selected: isSel,
                        selectedColor: TeknoyTheme.citMaroon,
                        backgroundColor: isDark ? const Color(0xFF24242C) : const Color(0xFFF1F1F4),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              selectedDay = day;
                              updateTextIfNotCustomized();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Time Slot Selector
                  const Text('2. Campus Time Window', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedTime,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.schedule_rounded, size: 20),
                    ),
                    items: timeSlots.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedTime = val;
                          updateTextIfNotCustomized();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Landmark Selector
                  const Text('3. Campus Landmark', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedLandmark,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.place_rounded, size: 20),
                    ),
                    items: landmarks.map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedLandmark = val;
                          updateTextIfNotCustomized();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Automated Message Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('4. Automated In-App Chat Notice', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('(Editable)', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? Colors.white54 : Colors.black45)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    onChanged: (_) => isCustomized = true,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, height: 1.4),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      fillColor: isDark ? const Color(0xFF141418) : const Color(0xFFF9F9FC),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm button
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      setState(() => _isActing = true);
                      try {
                        // 1. Update orders table in Supabase
                        await SupabaseConfig.client.from('orders').update({
                          'pickup_day': selectedDay,
                          'pickup_time': selectedTime,
                          'pickup_location': selectedLandmark,
                        }).eq('order_id', _order['order_id']);

                        // 2. Call Spring API schedule to transition status & generate OTP
                        await _callSpringApi('schedule', {});

                        // 3. Send automated notification to chat room
                        final buyerId = _order['buyer_id'] as String?;
                        final sellerId = _order['seller_id'] as String?;
                        if (buyerId != null && sellerId != null) {
                          final productModel = _extractProductFromOrder();
                          final chatService = ChatService();
                          final roomId = await chatService.getOrCreateChatRoom(
                            buyerId: buyerId,
                            sellerId: sellerId,
                            productId: productModel.id,
                          );
                          await chatService.sendMessage(
                            senderId: sellerId,
                            receiverId: buyerId,
                            roomId: roomId,
                            content: messageController.text.trim(),
                          );
                        }

                        await _refreshOrder();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Buyer notified via in-app chat! Meetup scheduled for $selectedDay ($selectedTime) at $selectedLandmark.'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to schedule: $e'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isActing = false);
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Send Notice & Confirm Schedule',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TeknoyTheme.citMaroon,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  void _showOTPInputDialog() {
    final otpController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: TeknoyTheme.citMaroon),
            SizedBox(width: 8),
            Text('Verify Handoff', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openQrScanner(
                  title: 'Scan Buyer Handoff QR',
                  onScanned: (scannedCode) async {
                    final sellerId = ref.read(authStateProvider).valueOrNull?.id;
                    if (sellerId != null) {
                      await _handleSpringAction('verify-handoff', {'otp': scannedCode}, 'Handoff verified successfully!');
                    }
                  },
                  onManualRequested: _showOTPInputDialog,
                );
              },
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: Colors.white),
              label: const Text('Scan Buyer\'s QR Code', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey.shade300)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('OR ENTER CODE', style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                Expanded(child: Divider(color: Colors.grey.shade300)),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Enter the 6-digit code shown on buyer\'s phone to complete handoff:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
            const SizedBox(height: 10),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 6),
              decoration: InputDecoration(
                hintText: '123456',
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              final code = otpController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(context);
              final sellerId = ref.read(authStateProvider).valueOrNull?.id;
              if (sellerId != null) {
                await _handleSpringAction('verify-handoff', {'otp': code}, 'Handoff verified successfully!');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: TeknoyTheme.citMaroon),
            child: const Text('Verify Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        color: isExpiringSoon ? Colors.red.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpiringSoon ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
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
                      : Container(width: 72, height: 72, color: Colors.grey.withValues(alpha: 0.15), child: const Icon(Icons.image_not_supported, color: Colors.grey)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(productName, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('₱ ${_order['total_amount']}', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon)),
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
                if (_isGCash) _detailRow('Protection', 'PayMongo Escrow Hold', isDark),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openChatWithOtherParty,
                    icon: Icon(Icons.chat_bubble_rounded, size: 18, color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon),
                    label: Text(
                      'Chat with $otherPartyLabel',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        color: isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: (isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon).withValues(alpha: 0.06),
                      side: BorderSide(
                        color: (isDark ? TeknoyTheme.citGold : TeknoyTheme.citMaroon).withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
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
                if (_isGCash) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _status == 'ESCROWED'
                          ? Colors.green.withValues(alpha: 0.08)
                          : (_status == 'AWAITING_PAYMENT' ? Colors.indigo.withValues(alpha: 0.08) : Colors.blue.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _status == 'ESCROWED'
                            ? Colors.green.withValues(alpha: 0.25)
                            : (_status == 'AWAITING_PAYMENT' ? Colors.indigo.withValues(alpha: 0.25) : Colors.blue.withValues(alpha: 0.2)),
                      ),
                    ),
                    child: Row(children: [
                      Icon(
                        _status == 'ESCROWED'
                            ? Icons.verified_user_rounded
                            : (_status == 'AWAITING_PAYMENT' ? Icons.hourglass_top_rounded : Icons.shield_rounded),
                        color: _status == 'ESCROWED'
                            ? Colors.green
                            : (_status == 'AWAITING_PAYMENT' ? Colors.indigo : Colors.blue),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status == 'ESCROWED'
                              ? 'Payment Secured: ₱ ${_order['total_amount']} held in Escrow. Released to seller upon campus handoff.'
                              : (_status == 'AWAITING_PAYMENT'
                                  ? 'Awaiting Payment: Complete GCash checkout via PayMongo to lock order in escrow.'
                                  : 'Protected by PayMongo GCash Payment Hold.'),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: _status == 'ESCROWED'
                                ? Colors.green
                                : (_status == 'AWAITING_PAYMENT' ? Colors.indigo : Colors.blue),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            )),
            const SizedBox(height: 16),

            // Confirmation status
            if (_status == 'APPROVED' || _status == 'SELLER_ACCEPTED' || _status == 'ESCROWED' || _status == 'PAYMENT_SUBMITTED' || _status == 'PAYMENT_VERIFIED' || isCompleted)
              _section(isDark, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.handshake_rounded, 'Transaction Details', isDark),
                  const SizedBox(height: 12),
                  if (_isGCash && _status == 'ESCROWED')
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.shield_rounded, color: Colors.green, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Funds held in platform escrow. Automated payout will be released after physical handoff completion.',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.green),
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
    return OrderStatusStepper(
      isPreorder: _isPreorder,
      status: _status,
      isSeller: widget.isSeller,
      isDark: isDark,
    );
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
      
      if (_status == 'ACCEPTED') {
        if (_isGCash) {
          buttons.add(
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_empty_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Awaiting buyer GCash payment via PayMongo. Meetup scheduling will unlock once payment is secured in escrow.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          if (_isPreorder) {
            buttons.add(
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: TeknoyTheme.citMaroon.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isActing ? null : () => _showNotifyItemReadyDialog(isPreorder: true),
                  icon: const Icon(Icons.campaign_rounded, size: 22, color: TeknoyTheme.citGold),
                  label: const Text(
                    'Item Arrived — Schedule Meetup',
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            );
          } else {
            buttons.add(_actionBtn('Schedule Meetup & Notify Buyer', TeknoyTheme.citMaroon, Icons.calendar_month_rounded, 
                () => _showNotifyItemReadyDialog(isPreorder: false)));
          }
        }
      }

      if (_status == 'AWAITING_PAYMENT') {
        buttons.add(
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.indigo.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.withValues(alpha: 0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.credit_card_rounded, color: Colors.indigo, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Buyer has initiated PayMongo GCash checkout. Waiting for payment webhook confirmation.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Colors.indigo),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (_status == 'ESCROWED' || _status == 'PAYMENT_VERIFIED') {
        if (_isPreorder) {
          buttons.add(
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [TeknoyTheme.citMaroon, TeknoyTheme.citMaroonLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isActing ? null : () => _showNotifyItemReadyDialog(isPreorder: true),
                icon: const Icon(Icons.campaign_rounded, size: 22, color: TeknoyTheme.citGold),
                label: const Text(
                  'Item Arrived — Schedule Meetup',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          );
        } else {
          buttons.add(_actionBtn('Schedule Meetup & Notify Buyer', TeknoyTheme.citMaroon, Icons.calendar_month_rounded, 
              () => _showNotifyItemReadyDialog(isPreorder: false)));
        }
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

      if (_status == 'REFUND_PENDING') {
        buttons.add(
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.assignment_late_rounded, color: Colors.orange, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This order is flagged for refund. Platform administrators will handle the PayMongo refund.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        );
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
      if (_isGCash && (_status == 'ACCEPTED' || _status == 'APPROVED')) {
        buttons.add(_actionBtn(
          'Pay ₱ ${_order['total_amount']} via GCash',
          TeknoyTheme.citMaroon,
          Icons.payment_rounded,
          _initiateGcashPayment,
        ));
        buttons.add(const SizedBox(height: 10));
      }

      if (_isGCash && _status == 'AWAITING_PAYMENT') {
        buttons.add(_actionBtn(
          'Resume GCash Payment (PayMongo)',
          Colors.indigo,
          Icons.open_in_browser_rounded,
          _initiateGcashPayment,
        ));
        buttons.add(const SizedBox(height: 10));
      }

      if (_isGCash && _status == 'ESCROWED') {
        buttons.add(
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Colors.green, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Payment Secured! Your funds are held safely in TeknoyCart Escrow. The seller is preparing handoff.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Colors.green, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
        buttons.add(const SizedBox(height: 10));
      }

      if (_status == 'REFUND_PENDING') {
        buttons.add(
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.currency_exchange_rounded, color: Colors.orange, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Refund In Progress: An administrator is processing your PayMongo refund.',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        );
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2332) : const Color(0xFFF0F6FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: Colors.blue, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Handoff Verification',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.blue[200] : Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Present this QR code or 6-digit code to the seller at the meetup spot:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                if (otp != '------') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: otp,
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    otp.split('').join(' '),
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 34,
                      letterSpacing: 8,
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                    ),
                  ),
                ],
                if (otp == '------') ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _isActing ? null : () => _handleSpringAction('schedule', {}, 'Meetup code generated!'),
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.blue),
                    label: const Text('Generate Code Now', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                ],
              ],
            ),
          ),
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
        final orderId = _order['order_id']?.toString() ?? '';
        final existingReview = ref.watch(orderReviewProvider(orderId));
        final product = _extractProductFromOrder();
        final variant = _order['product_variants'] as Map<String, dynamic>?;
        final variantValue = variant?['variant_value'] as String?;

        if (existingReview == null) {
          buttons.add(
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [TeknoyTheme.citMaroon, Color(0xFF9E1B1B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: TeknoyTheme.citMaroon.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _openReviewSheet(product, orderId, variantValue, null),
                icon: const Icon(Icons.star_rounded, size: 22, color: TeknoyTheme.citGold),
                label: const Text(
                  'Rate & Review Order',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          );
        } else {
          buttons.add(
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : const Color(0xFFF7F7FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: TeknoyTheme.citGold.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: TeknoyTheme.citGold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'You rated this ',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: List.generate(
                                existingReview.rating,
                                (_) => const Icon(Icons.star_rounded, size: 14, color: TeknoyTheme.citGold),
                              ),
                            ),
                          ],
                        ),
                        if (existingReview.comment.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            '"${existingReview.comment}"',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openReviewSheet(product, orderId, variantValue, existingReview),
                    child: const Text('Edit', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon)),
                  ),
                ],
              ),
            ),
          );
        }
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Request Return / Refund', Colors.orange, Icons.assignment_return_rounded, _showReturnRequestDialog));
      }

      if (_status == 'RETURN_APPROVED') {
        final returnOtp = (_order['return_otp'] != null && _order['return_otp'].toString().isNotEmpty)
            ? _order['return_otp'].toString()
            : '------';
        buttons.add(
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF142B28) : const Color(0xFFE6F7F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.35), width: 1.5),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: Colors.teal, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Return Handoff Verification',
                      style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Present this QR code or 6-digit code to seller at return meetup:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.teal),
                ),
                if (returnOtp != '------') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: returnOtp,
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    returnOtp.split('').join(' '),
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontWeight: FontWeight.bold,
                      fontSize: 34,
                      letterSpacing: 8,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }

      if (_status == 'REFUND_REQUESTED') {
        buttons.add(_actionBtn('Escalate to Admin Mediation', Colors.purple, Icons.gavel_rounded, 
            () => _handleSpringAction('dispute', {'reason': 'Seller unresponsive to refund request'}, 'Dispute opened with Admin.')));
      }

      if (_status == 'PLACED' || _status == 'ACCEPTED' || _status == 'AWAITING_PAYMENT' || _status == 'NEEDS_REVIEW') {
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
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

  void _openQrScanner({
    required String title,
    required ValueChanged<String> onScanned,
    required VoidCallback onManualRequested,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QrScannerSheet(
        title: title,
        onScanned: onScanned,
        onManualRequested: onManualRequested,
      ),
    );
  }
}

