import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/features/checkout/services/checkout_submitter.dart';

/// Records every RPC call and replies from a scripted queue.
class _FakeRpc {
  _FakeRpc(this._replies);
  final List<Object Function()> _replies;
  final calls = <Map<String, dynamic>>[];

  Future<dynamic> call(String fn, Map<String, dynamic> params) async {
    calls.add({'fn': fn, ...params});
    final reply = _replies.removeAt(0)();
    if (reply is Exception || reply is Error) throw reply;
    return reply;
  }
}

Map<String, dynamic> _ok(String orderId, double total) => {
      'success': true,
      'orders': [
        {'line_index': 0, 'order_id': orderId, 'total_amount': total}
      ],
    };

CheckoutSubmitter _submitter(_FakeRpc rpc) => CheckoutSubmitter(
      rpc.call,
      retryDelay: Duration.zero,
      attemptTimeout: const Duration(seconds: 5),
    );

void main() {
  const agreedLines = [
    {
      'product_id': 'p1',
      'variant_id': 'v1',
      'quantity': 1,
      'unit_price': 150.0,
    }
  ];

  group('negotiated chat checkout', () {
    test('sends the chat id so the server can verify the accepted price',
        () async {
      final rpc = _FakeRpc([() => _ok('o-deal', 150)]);
      final result = await _submitter(rpc).submit(
        lines: agreedLines,
        paymentMethod: 'CASH_ON_PICKUP',
        clientRequestId: 'req-deal',
        chatId: 'chat-room-1',
      );

      expect(result.success, isTrue);
      expect(result.orders.single['total_amount'], 150);
      expect(rpc.calls.single['fn'], 'place_orders_atomic');
      expect(rpc.calls.single['p_chat_id'], 'chat-room-1');
      expect(rpc.calls.single['p_client_request_id'], 'req-deal');
      expect(rpc.calls.single['p_payment_method'], 'CASH_ON_PICKUP');
    });

    test('omits the chat id for ordinary catalog checkouts', () async {
      final rpc = _FakeRpc([() => _ok('o-catalog', 300)]);
      final result = await _submitter(rpc).submit(
        lines: const [
          {
            'product_id': 'p1',
            'variant_id': 'v1',
            'quantity': 1,
            'unit_price': 300.0,
          }
        ],
        paymentMethod: 'GCASH',
        clientRequestId: 'req-catalog',
      );

      expect(result.success, isTrue);
      expect(rpc.calls.single.containsKey('p_chat_id'), isFalse);
      expect(rpc.calls.single['p_client_request_id'], 'req-catalog');
    });

    test('never silently drops the chat id on an unmigrated database', () async {
      final rpc = _FakeRpc([
        () => const PostgrestException(
              message: 'Could not find the function',
              code: 'PGRST202',
            ),
      ]);

      await expectLater(
        _submitter(rpc).submit(
          lines: agreedLines,
          paymentMethod: 'CASH_ON_PICKUP',
          clientRequestId: 'req-deal',
          chatId: 'chat-room-1',
        ),
        throwsA(isA<PostgrestException>()),
      );

      // Do not retry through the 3-argument function: it would either reject
      // the agreed price or charge the catalog price.
      expect(rpc.calls, hasLength(1));
      expect(rpc.calls.single['p_chat_id'], 'chat-room-1');
    });
  });
}
