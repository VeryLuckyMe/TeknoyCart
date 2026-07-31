import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/core/supabase_client.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Full-screen order detail view.
/// UX improvements: progress stepper, tap-to-call, pickup countdown, GCash proof,
/// realtime toast, confirmation dialogs, order ID copy, gradient buttons.
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

  // #12: realtime toast state
  String? _realtimeToastMsg;
  Timer? _toastTimer;

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
              final newRecord = Map<String, dynamic>.from(payload.newRecord);
              final newStatus = newRecord['status'] as String?;
              final oldStatus = _order['status'] as String?;
              setState(() {
                _order = {..._order, ...newRecord};
                // #12: show animated toast when status changes
                if (newStatus != null && newStatus != oldStatus) {
                  _realtimeToastMsg = _statusChangeMessage(newStatus);
                }
              });
              // auto-dismiss toast after 4 seconds
              _toastTimer?.cancel();
              _toastTimer = Timer(const Duration(seconds: 4), () {
                if (mounted) setState(() => _realtimeToastMsg = null);
              });
            }
          },
        )
        .subscribe();
  }

  String _statusChangeMessage(String status) {
    switch (status) {
      case 'APPROVED':
      case 'SELLER_ACCEPTED': return '🎉 Order accepted by seller!';
      case 'PAYMENT_SUBMITTED': return '💸 Payment submitted by buyer!';
      case 'PAYMENT_VERIFIED': return '✅ Payment verified!';
      case 'COMPLETED': return '🎊 Transaction completed!';
      case 'REJECTED':
      case 'DECLINED': return '❌ Order was declined.';
      case 'CANCELLED': return '⚠️ Order was cancelled.';
      case 'RETURN_REQUESTED': return '🔄 Return / refund requested.';
      case 'RETURN_APPROVED': return '✅ Return approved!';
      case 'RETURN_DECLINED': return '❌ Return request declined.';
      default: return 'Order updated: $status';
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _toastTimer?.cancel();
    super.dispose();
  }

  String get _status => _order['status'] as String? ?? '';
  String get _rawPaymentMethod => _order['payment_method'] as String? ?? 'CASH_ON_PICKUP';
  String get _paymentMethod => (_rawPaymentMethod == 'GCASH' || _rawPaymentMethod == 'GCash') ? 'GCash' : 'Cash on Delivery';
  bool get _isGCash => _paymentMethod == 'GCash';

  Future<void> _refreshOrder() async {
    try {
      final res = await SupabaseConfig.client
          .from('orders')
          .select('''
            order_id, total_amount, status, quantity, created_at,
            pickup_location, pickup_day, pickup_time, payment_method,
            seller_confirmed_at, buyer_confirmed_at, buyer_id, seller_id,
            gcash_reference,
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
      await SupabaseConfig.client.from('orders').update({'status': newStatus}).eq('order_id', _order['order_id']);
      await _refreshOrder();
      if (mounted) {
        String msg = '';
        if (newStatus == 'APPROVED') msg = 'Order accepted! Buyer notified.';
        if (newStatus == 'REJECTED') msg = 'Order declined/rejected.';
        if (newStatus == 'CANCELLED') msg = 'Order cancelled successfully.';
        if (newStatus == 'PAYMENT_SUBMITTED') msg = 'Payment recorded! Awaiting seller verification.';
        if (newStatus == 'PAYMENT_VERIFIED') msg = 'Payment verified!';
        if (newStatus == 'RETURN_REQUESTED') msg = 'Return & refund request submitted.';
        if (newStatus == 'RETURN_APPROVED') msg = 'Return approved!';
        if (newStatus == 'RETURN_DECLINED') msg = 'Return request declined.';
        if (msg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(msg),
            backgroundColor: newStatus.contains('DECLINED') || newStatus.contains('REJECTED') || newStatus == 'CANCELLED'
                ? Colors.red
                : Colors.green,
          ));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() => _isActing = false);
    }
  }

  // ─── #13: Confirmation dialogs ────────────────────────────────────────────

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required IconData icon,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A20) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: confirmColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(icon, color: confirmColor, size: 24),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              Text(message, style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: isDark ? Colors.white54 : Colors.black54), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Go Back', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(confirmLabel, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    return result ?? false;
  }

  void _showCancelConfirmationDialog() async {
    final confirmed = await _confirmAction(
      title: 'Cancel this order?',
      message: 'The seller will be notified and the item reservation will be released.',
      confirmLabel: 'Yes, Cancel',
      confirmColor: Colors.red,
      icon: Icons.cancel_outlined,
    );
    if (confirmed) _updateStatus('CANCELLED');
  }

  void _showDeclineConfirmationDialog() async {
    final confirmed = await _confirmAction(
      title: 'Decline this order?',
      message: 'The buyer will be notified that their order was declined. This cannot be undone.',
      confirmLabel: 'Yes, Decline',
      confirmColor: Colors.red,
      icon: Icons.close_rounded,
    );
    if (confirmed) _updateStatus('REJECTED');
  }

  void _showRejectPaymentConfirmationDialog() async {
    final confirmed = await _confirmAction(
      title: 'Reject this payment?',
      message: 'The buyer will be asked to resubmit their GCash payment details.',
      confirmLabel: 'Yes, Reject',
      confirmColor: Colors.red,
      icon: Icons.cancel_outlined,
    );
    if (confirmed) _updateStatus('REJECTED');
  }

  // ─── Other dialogs ────────────────────────────────────────────────────────

  void _showReturnRequestDialog() {
    String selectedReason = 'Defective or Damaged Item';
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(children: [
            Icon(Icons.assignment_return_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Request Return / Refund', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select a reason:', style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
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
                  onChanged: (val) { if (val != null) setModalState(() => selectedReason = val); },
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
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
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
                    final chat = await SupabaseConfig.client
                        .from('chats').select('chat_id')
                        .eq('buyer_id', _order['buyer_id'])
                        .eq('seller_id', _order['seller_id'])
                        .limit(1).maybeSingle();
                    if (chat != null) {
                      String msg = '📢 [Automated Message]\nI have submitted a Return / Refund request for this order.\nReason: $selectedReason';
                      if (notesController.text.trim().isNotEmpty) msg += '\nNotes: ${notesController.text.trim()}';
                      msg += '\n\nPlease check the order details to review my request.';
                      await SupabaseConfig.client.from('messages').insert({
                        'chat_id': chat['chat_id'],
                        'sender_id': user.id,
                        'content': msg,
                        'is_read': false,
                      });
                    }
                  } catch (e) { debugPrint('Error submitting return: $e'); }
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

  void _showGCashSubmitDialog() {
    final refController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.send_to_mobile_rounded, color: Colors.indigo),
          SizedBox(width: 8),
          Text('GCash Payment Sent', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
              ),
              child: Text('Total to send: ₱ ${_order['total_amount']}',
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
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
            const Text('The seller will verify your reference number and confirm payment.',
                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Colors.black54)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            onPressed: () async {
              final referenceNumber = refController.text.trim();
              Navigator.pop(context);
              try {
                await SupabaseConfig.client.from('orders').update({'gcash_reference': referenceNumber}).eq('order_id', _order['order_id']);
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

  // ─── #10: Pickup countdown helper ────────────────────────────────────────

  String? _pickupCountdownLabel(String pickupDay, String pickupTime) {
    try {
      const dayMap = {
        'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4,
        'Friday': 5, 'Saturday': 6, 'Sunday': 7,
        'monday': 1, 'tuesday': 2, 'wednesday': 3, 'thursday': 4,
        'friday': 5, 'saturday': 6, 'sunday': 7,
      };
      final now = DateTime.now();
      final targetWeekday = dayMap[pickupDay];
      if (targetWeekday == null) return null;

      var daysUntil = targetWeekday - now.weekday;
      if (daysUntil < 0) daysUntil += 7;

      final timeMatch = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)?').firstMatch(pickupTime);
      if (timeMatch == null) return null;
      var hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2)!);
      final ampm = timeMatch.group(3)?.toUpperCase();
      if (ampm == 'PM' && hour < 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;

      final pickup = DateTime(now.year, now.month, now.day + daysUntil, hour, minute);
      final diff = pickup.difference(now);

      if (diff.isNegative) {
        if (diff.inDays.abs() == 0) return '⚠️ Pickup was scheduled earlier today — confirm or reschedule';
        if (diff.inDays.abs() == 1) return '⚠️ Pickup was yesterday — please coordinate with the other party';
        return null;
      }
      if (diff.inHours < 1) return '📍 Pickup in ${diff.inMinutes} min!';
      if (diff.inHours < 24) return '📍 Pickup in ${diff.inHours}h ${diff.inMinutes % 60}m';
      if (daysUntil == 1) return '📍 Pickup tomorrow at $pickupTime';
      if (daysUntil == 0) return '📍 Pickup today at $pickupTime';
      return null;
    } catch (_) {
      return null;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

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

    // #14: full order ID + short display
    final fullOrderId = _order['order_id'] as String? ?? '';
    final shortOrderId = fullOrderId.length >= 8 ? fullOrderId.substring(0, 8).toUpperCase() : fullOrderId.toUpperCase();

    final sellerConfirmed = _order['seller_confirmed_at'] != null;
    final buyerConfirmed = _order['buyer_confirmed_at'] != null;
    final isCompleted = _status == 'COMPLETED';

    // #10: pickup countdown
    final countdownLabel = _pickupCountdownLabel(pickupDay, pickupTime);

    return Scaffold(
      appBar: AppBar(
        // #14: order ID + copy button in AppBar
        title: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: fullOrderId));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Order ID copied!'), duration: Duration(seconds: 2)),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Order #$shortOrderId', style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black38),
            ],
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                // Product card
                _section(isDark, child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? Image.network(imageUrl, width: 72, height: 72, fit: BoxFit.cover,
                              loadingBuilder: (_, child, p) => p == null ? child : Container(width: 72, height: 72, color: Colors.grey.withValues(alpha: 0.15)))
                          : Container(width: 72, height: 72, color: Colors.grey.withValues(alpha: 0.15),
                              child: const Icon(Icons.storefront_rounded, color: Colors.grey)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(productName, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text('₱ ${_order['total_amount']}',
                            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18, color: TeknoyTheme.citMaroon)),
                        const SizedBox(height: 4),
                        Text('Placed: $createdAt',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: isDark ? Colors.white54 : Colors.black45)),
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
                    // #9: tap-to-call contact
                    if (otherPartyContact != null)
                      _tappableContactRow(otherPartyContact, isDark),
                    if (!widget.isSeller && _isGCash && sellerGcash != null)
                      _detailRow('GCash No.', sellerGcash, isDark),
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

                    // #10: Pickup countdown
                    if (countdownLabel != null && (_status == 'APPROVED' || _status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_VERIFIED')) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: countdownLabel.startsWith('⚠️')
                              ? Colors.orange.withValues(alpha: 0.08)
                              : Colors.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: countdownLabel.startsWith('⚠️')
                                ? Colors.orange.withValues(alpha: 0.3)
                                : Colors.teal.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(children: [
                          const SizedBox(width: 4),
                          Expanded(child: Text(countdownLabel,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: countdownLabel.startsWith('⚠️') ? Colors.orange : Colors.teal,
                              ))),
                        ]),
                      ),
                    ],

                    if (!widget.isSeller && _isGCash && sellerGcash != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Send GCash to: $sellerGcash — then share the reference number.',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.blue))),
                        ]),
                      ),
                    ],
                  ],
                )),
                const SizedBox(height: 16),

                // Confirmation status
                if (_status == 'APPROVED' || _status == 'SELLER_ACCEPTED' ||
                    _status == 'PAYMENT_SUBMITTED' || _status == 'PAYMENT_VERIFIED' || isCompleted)
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
                            color: Colors.indigo.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.hourglass_top_rounded, color: Colors.indigo, size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              _order['gcash_reference'] != null && (_order['gcash_reference'] as String).isNotEmpty
                                  ? 'GCash ref: ${_order['gcash_reference']} — Awaiting seller verification.'
                                  : 'GCash payment submitted. Awaiting seller verification.',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.indigo),
                            )),
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

          // #12: Realtime status change toast
          if (_realtimeToastMsg != null)
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: _RealtimeToast(message: _realtimeToastMsg!),
            ),
        ],
      ),
    );
  }

  // ─── Status Stepper ───────────────────────────────────────────────────────

  Widget _buildStatusStepper(bool isDark) {
    final steps = _isGCash
        ? ['Placed', 'Accepted', 'Payment', 'Meetup', 'Done']
        : ['Placed', 'Accepted', 'Meetup', 'Done'];

    final statusToStep = _isGCash
        ? {
            'PENDING_SELLER_ACCEPT': 0, 'INQUIRY_SENT': 0,
            'APPROVED': 1, 'SELLER_ACCEPTED': 1,
            'PAYMENT_SUBMITTED': 2, 'PAYMENT_VERIFIED': 2,
            'COMPLETED': 4,
            'RETURN_REQUESTED': 4, 'RETURN_APPROVED': 4, 'RETURN_DECLINED': 4,
          }
        : {
            'PENDING_SELLER_ACCEPT': 0, 'INQUIRY_SENT': 0,
            'APPROVED': 1, 'SELLER_ACCEPTED': 1,
            'COMPLETED': 3,
            'RETURN_REQUESTED': 3, 'RETURN_APPROVED': 3, 'RETURN_DECLINED': 3,
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
          _statusBanner(
            isCancelled ? 'This order was cancelled.' : 'This order was declined by the seller.',
            Colors.red, Icons.cancel_outlined,
          )
        else if (isReturnRequested)
          _statusBanner('Return / Refund requested. Awaiting seller response.', Colors.orange, Icons.assignment_return_rounded)
        else if (isReturnApproved)
          _statusBanner('Return Approved! Meet up to exchange item & refund.', Colors.teal, Icons.check_circle_outline_rounded)
        else if (isReturnDeclined)
          _statusBanner('Return request was declined by the seller.', Colors.red, Icons.gavel_rounded)
        else
          Row(
            children: List.generate(steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepIdx = i ~/ 2;
                final filled = stepIdx < currentStep;
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 3,
                    decoration: BoxDecoration(
                      gradient: filled
                          ? const LinearGradient(colors: [TeknoyTheme.citMaroon, Color(0xFFB22222)])
                          : null,
                      color: filled ? null : (isDark ? Colors.white12 : Colors.black12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              final stepIdx = i ~/ 2;
              final done = stepIdx <= currentStep;
              final isActive = stepIdx == currentStep;
              return Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: isActive ? 32 : 26,
                  height: isActive ? 32 : 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: done ? const LinearGradient(
                      colors: [TeknoyTheme.citMaroon, Color(0xFFB22222)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ) : null,
                    color: done ? null : (isDark ? Colors.white12 : Colors.black12),
                    border: isActive ? Border.all(color: TeknoyTheme.citMaroon, width: 2) : null,
                    boxShadow: done ? [BoxShadow(color: TeknoyTheme.citMaroon.withValues(alpha: 0.3), blurRadius: 8)] : null,
                  ),
                  child: Center(child: done
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : Text('${stepIdx + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white38 : Colors.black38))),
                ),
                const SizedBox(height: 6),
                Text(steps[stepIdx], style: TextStyle(
                  fontFamily: 'Inter', fontSize: 9,
                  fontWeight: done ? FontWeight.bold : FontWeight.normal,
                  color: done ? TeknoyTheme.citMaroon : (isDark ? Colors.white38 : Colors.black38),
                )),
              ]);
            }),
          ),
      ],
    ));
  }

  Widget _statusBanner(String msg, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: color))),
      ]),
    );
  }

  // ─── Action Buttons ───────────────────────────────────────────────────────

  Widget _buildActionButtons(bool isDark, bool sellerConfirmed, bool buyerConfirmed) {
    final buttons = <Widget>[];

    if (widget.isSeller) {
      if (_status == 'PENDING_SELLER_ACCEPT' || _status == 'INQUIRY_SENT') {
        // #13: Confirmation before decline
        buttons.add(_gradientBtn('Decline Order', Colors.red, const Color(0xFF8B0000), Icons.close_rounded, _showDeclineConfirmationDialog));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_gradientBtn('Accept Order', const Color(0xFF22A559), const Color(0xFF16834A), Icons.check_circle_outline_rounded, () => _updateStatus('APPROVED')));
      }
      if (_isGCash && _status == 'PAYMENT_SUBMITTED') {
        // #13: Confirmation before reject payment
        buttons.add(_gradientBtn('Reject Payment', Colors.red, const Color(0xFF8B0000), Icons.cancel_outlined, _showRejectPaymentConfirmationDialog));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_gradientBtn('✓ Verify GCash Payment', const Color(0xFF22A559), const Color(0xFF16834A), Icons.verified_outlined, () => _updateStatus('PAYMENT_VERIFIED')));
      }
      if ((_status == 'APPROVED' || _status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_VERIFIED') && !sellerConfirmed) {
        buttons.add(_gradientBtn('Mark as Handed Off', TeknoyTheme.citMaroon, const Color(0xFF8B0000), Icons.handshake_outlined, () => _confirmHandoff(true)));
      }
      if (_status == 'RETURN_REQUESTED') {
        buttons.add(_gradientBtn('Decline Return Request', Colors.red, const Color(0xFF8B0000), Icons.close_rounded, () => _updateStatus('RETURN_DECLINED')));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_gradientBtn('Approve Return & Refund', Colors.teal, const Color(0xFF007A6E), Icons.check_circle_outline_rounded, () => _updateStatus('RETURN_APPROVED')));
      }
    } else {
      if (_isGCash && (_status == 'APPROVED' || _status == 'SELLER_ACCEPTED')) {
        buttons.add(_gradientBtn('📤 I\'ve Sent GCash Payment', Colors.indigo, const Color(0xFF2C1F80), Icons.send_rounded, _showGCashSubmitDialog));
        buttons.add(const SizedBox(height: 10));
      }
      if (_isGCash && _status == 'REJECTED') {
        buttons.add(Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: const Row(children: [
            Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Your GCash payment was rejected. Please verify the amount and reference number, then resubmit.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.red),
            )),
          ]),
        ));
        buttons.add(const SizedBox(height: 10));
        buttons.add(_gradientBtn('🔁 Resubmit GCash Payment', Colors.indigo, const Color(0xFF2C1F80), Icons.refresh_rounded, _showGCashSubmitDialog));
        buttons.add(const SizedBox(height: 10));
      }
      if ((_status == 'APPROVED' || _status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_VERIFIED') && !buyerConfirmed) {
        buttons.add(_gradientBtn('Confirm I Received This', const Color(0xFF22A559), const Color(0xFF16834A), Icons.check_circle_outline_rounded, () => _confirmHandoff(false)));
      }
      if (_status == 'COMPLETED' || _status == 'APPROVED' || _status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_VERIFIED') {
        if (_status != 'RETURN_REQUESTED' && _status != 'RETURN_APPROVED' && _status != 'RETURN_DECLINED') {
          buttons.add(const SizedBox(height: 10));
          buttons.add(_gradientBtn('Request Return / Refund', Colors.orange, const Color(0xFFBF6500), Icons.assignment_return_rounded, _showReturnRequestDialog));
        }
      }
      if (_status == 'PENDING_SELLER_ACCEPT' || _status == 'INQUIRY_SENT' ||
          _status == 'APPROVED' || _status == 'SELLER_ACCEPTED' || _status == 'PAYMENT_SUBMITTED') {
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

  // #Visual: gradient action button
  Widget _gradientBtn(String label, Color from, Color to, IconData icon, VoidCallback onTap) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [from, to]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: from.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ElevatedButton.icon(
        onPressed: _isActing ? null : onTap,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(label, style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ─── Section helper widgets ───────────────────────────────────────────────

  Widget _section(bool isDark, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        SizedBox(width: 90, child: Text('$label:', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? Colors.white54 : Colors.black45))),
        Expanded(child: Text(value, style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87))),
      ]),
    );
  }

  // #9: tap-to-call contact row
  Widget _tappableContactRow(String contact, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        onTap: () {
          // Copy to clipboard as fallback (url_launcher not available)
          Clipboard.setData(ClipboardData(text: contact));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.phone_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Contact number copied: $contact'),
              ]),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 90, child: Text('Contact:', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: isDark ? Colors.white54 : Colors.black45))),
          Expanded(child: Row(children: [
            Text(contact, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: TeknoyTheme.citMaroon)),
            const SizedBox(width: 6),
            Icon(Icons.copy_rounded, size: 13, color: TeknoyTheme.citMaroon.withValues(alpha: 0.7)),
          ])),
        ]),
      ),
    );
  }

  Widget _confirmRow(String label, bool done, bool isDark) {
    return Row(children: [
      Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 18, color: done ? Colors.green : (isDark ? Colors.white38 : Colors.black38)),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 13,
          color: done ? Colors.green : (isDark ? Colors.white54 : Colors.black54),
          fontWeight: done ? FontWeight.bold : FontWeight.normal)),
    ]);
  }
}

// ─── #12: Realtime animated toast ─────────────────────────────────────────────

class _RealtimeToast extends StatefulWidget {
  final String message;
  const _RealtimeToast({required this.message});

  @override
  State<_RealtimeToast> createState() => _RealtimeToastState();
}

class _RealtimeToastState extends State<_RealtimeToast> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slide = Tween<double>(begin: -60, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0, end: 1).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _slide.value),
        child: Opacity(
          opacity: _fade.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: Row(children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.message,
                  style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13))),
            ]),
          ),
        ),
      ),
    );
  }
}
