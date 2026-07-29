import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
  }

  String get _status => _order['status'] as String? ?? '';
  String get _paymentMethod => _order['payment_method'] as String? ?? 'Cash on Delivery';
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
    setState(() => _isActing = true);
    try {
      final update = <String, dynamic>{'status': newStatus};
      if (newStatus == 'SELLER_CONFIRMED') {
        update['seller_confirmed_at'] = DateTime.now().toIso8601String();
      }
      await SupabaseConfig.client.from('orders').update(update).eq('order_id', _order['order_id']);
      await _refreshOrder();
      if (mounted) {
        String msg = '';
        if (newStatus == 'SELLER_ACCEPTED') msg = 'Order accepted! Buyer notified.';
        if (newStatus == 'DECLINED') msg = 'Order declined.';
        if (newStatus == 'CANCELLED') msg = 'Order cancelled successfully.';
        if (newStatus == 'PAYMENT_VERIFIED') msg = 'Payment verified!';
        if (newStatus == 'PAYMENT_REJECTED') msg = 'Payment rejected. Buyer notified.';
        if (newStatus == 'RETURN_REQUESTED') msg = 'Return & refund request submitted to seller.';
        if (newStatus == 'RETURN_APPROVED') msg = 'Return approved! Please coordinate item return & refund.';
        if (newStatus == 'RETURN_DECLINED') msg = 'Return request declined.';
        if (msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: newStatus.contains('DECLINED') || newStatus.contains('REJECTED') || newStatus == 'CANCELLED'
                  ? Colors.red
                  : Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Order?', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to cancel this order? This will release the item reservation and notify the seller.',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep Order', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus('CANCELLED');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
                  try {
                    await SupabaseConfig.client.from('order_returns').insert({
                      'order_id': _order['order_id'],
                      'requested_by': user.id,
                      'reason': selectedReason,
                      'explanation': notesController.text.trim(),
                      'status': 'PENDING',
                    });
                  } catch (_) {}
                }
                if (mounted) Navigator.pop(context);
                _updateStatus('RETURN_REQUESTED');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Submit Request', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmHandoff(bool isSeller) async {
    setState(() => _isActing = true);
    try {
      final update = isSeller
          ? {'seller_confirmed_at': DateTime.now().toIso8601String()}
          : {'buyer_confirmed_at': DateTime.now().toIso8601String()};
      await SupabaseConfig.client.from('orders').update(update).eq('order_id', _order['order_id']);

      await _refreshOrder();
      final sellerConfirmed = _order['seller_confirmed_at'] != null;
      final buyerConfirmed = _order['buyer_confirmed_at'] != null;
      if (sellerConfirmed && buyerConfirmed) {
        await SupabaseConfig.client.from('orders').update({'status': 'COMPLETED'}).eq('order_id', _order['order_id']);
        await _refreshOrder();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Transaction completed!'), backgroundColor: Colors.green));
      } else {
        if (mounted) {
          final who = isSeller ? 'Handoff marked. Waiting for buyer to confirm receipt.' : 'Receipt confirmed! Waiting for seller to confirm handoff.';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(who)));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
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
            if (_status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_VERIFIED' || isCompleted)
              _section(isDark, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(Icons.handshake_rounded, 'Meetup Confirmation', isDark),
                  const SizedBox(height: 12),
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
    final steps = _isGCash
        ? ['Placed', 'Accepted', 'Payment', 'Meetup', 'Done']
        : ['Placed', 'Accepted', 'Meetup', 'Done'];

    final statusToStep = _isGCash
        ? {
            'PENDING_SELLER_ACCEPT': 0,
            'INQUIRY_SENT': 0,
            'SELLER_ACCEPTED': 1,
            'PAYMENT_SUBMITTED': 2,
            'PAYMENT_VERIFIED': 2,
            'PAYMENT_REJECTED': 2,
            'COMPLETED': 4,
            'DECLINED': -1,
            'CANCELLED': -1,
            'RETURN_REQUESTED': 4,
            'RETURN_APPROVED': 4,
            'RETURN_DECLINED': 4,
          }
        : {
            'PENDING_SELLER_ACCEPT': 0,
            'INQUIRY_SENT': 0,
            'SELLER_ACCEPTED': 1,
            'COMPLETED': 3,
            'DECLINED': -1,
            'CANCELLED': -1,
            'RETURN_REQUESTED': 3,
            'RETURN_APPROVED': 3,
            'RETURN_DECLINED': 3,
          };

    final currentStep = statusToStep[_status] ?? 0;
    final isDeclined = _status == 'DECLINED';
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

    if (widget.isSeller) {
      // Seller: Accept/Decline
      if (_status == 'PENDING_SELLER_ACCEPT' || _status == 'INQUIRY_SENT') {
        buttons.add(_actionBtn('Decline Order', Colors.red, Icons.close_rounded, () => _updateStatus('DECLINED')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Accept Order', Colors.green, Icons.check_circle_outline_rounded, () => _updateStatus('SELLER_ACCEPTED')));
      }
      // Seller: Verify GCash
      if (_isGCash && _status == 'PAYMENT_SUBMITTED') {
        buttons.add(_actionBtn('Reject Payment', Colors.red, Icons.cancel_outlined, () => _updateStatus('PAYMENT_REJECTED')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('✓ Verify GCash Payment', Colors.green, Icons.verified_outlined, () => _updateStatus('PAYMENT_VERIFIED')));
      }
      // Seller: Mark handed off
      if ((_status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_VERIFIED') && !sellerConfirmed) {
        buttons.add(_actionBtn('Mark as Handed Off', TeknoyTheme.citMaroon, Icons.handshake_outlined, () => _confirmHandoff(true)));
      }
      // Seller: Handle Return Request
      if (_status == 'RETURN_REQUESTED') {
        buttons.add(_actionBtn('Decline Return Request', Colors.red, Icons.close_rounded, () => _updateStatus('RETURN_DECLINED')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_actionBtn('Approve Return & Refund', Colors.teal, Icons.check_circle_outline_rounded, () => _updateStatus('RETURN_APPROVED')));
      }
    } else {
      // Buyer: Confirm received
      if ((_status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_VERIFIED') && !buyerConfirmed) {
        buttons.add(_actionBtn('Confirm I Received This', Colors.green, Icons.check_circle_outline_rounded, () => _confirmHandoff(false)));
      }

      // Buyer: Request Return / Refund (if accepted or completed)
      if (_status == 'COMPLETED' || _status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_VERIFIED') {
        if (_status != 'RETURN_REQUESTED' && _status != 'RETURN_APPROVED' && _status != 'RETURN_DECLINED') {
          buttons.add(const SizedBox(height: 10));
          buttons.add(_actionBtn('Request Return / Refund', Colors.orange, Icons.assignment_return_rounded, _showReturnRequestDialog));
        }
      }

      // Buyer: Cancel Order (if order is still pending/active before handoff)
      if (_status == 'PENDING_SELLER_ACCEPT' || _status == 'INQUIRY_SENT' || _status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_SUBMITTED') {
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
