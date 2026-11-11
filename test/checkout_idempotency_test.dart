import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/core/utils/request_id.dart';
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

Map<String, dynamic> _ok(String orderId) => {
      'success': true,
      'orders': [
        {'line_index': 0, 'order_id': orderId, 'total_amount': 300}
      ],
    };

CheckoutSubmitter _submitter(_FakeRpc rpc) => CheckoutSubmitter(
      rpc.call,
      retryDelay: Duration.zero,
      attemptTimeout: const Duration(seconds: 5),
    );

void main() {
  const lines = [
    {'product_id': 'p1', 'variant_id': 'v1', 'quantity': 1, 'unit_price': 300.0}
  ];

  group('generateRequestId', () {
    test('produces RFC 4122 v4 UUIDs', () {
      final uuidV4 = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      for (var i = 0; i < 200; i++) {
        expect(uuidV4.hasMatch(generateRequestId()), isTrue);
      }
    });

    test('is unique across calls', () {
      final ids = {for (var i = 0; i < 1000; i++) generateRequestId()};
      expect(ids.length, 1000);
    });
  });

  group('CheckoutSubmitter', () {
    test('sends the client request id with the order lines', () async {
      final rpc = _FakeRpc([() => _ok('o1')]);
      final result = await _submitter(rpc).submit(
          lines: lines, paymentMethod: 'CASH_ON_PICKUP', clientRequestId: 'req-1');

      expect(result.success, isTrue);
      expect(rpc.calls.single['p_client_request_id'], 'req-1');
      expect(rpc.calls.single['p_payment_method'], 'CASH_ON_PICKUP');
    });

    test('retries a timed-out request with the SAME request id', () async {
      final rpc = _FakeRpc([
        () => TimeoutException('slow network'),
        () => http.ClientException('connection reset'),
        () => _ok('o1'),
      ]);
      final result = await _submitter(rpc).submit(
          lines: lines, paymentMethod: 'GCASH', clientRequestId: 'req-2');

      expect(result.success, isTrue);
      expect(rpc.calls, hasLength(3));
      expect(rpc.calls.map((c) => c['p_client_request_id']).toSet(), {'req-2'});
    });

    test('gives up after maxAttempts transient failures', () async {
      final rpc = _FakeRpc(List.generate(3, (_) => () => TimeoutException('down')));
      await expectLater(
        _submitter(rpc).submit(
            lines: lines, paymentMethod: 'GCASH', clientRequestId: 'req-3'),
        throwsA(isA<TimeoutException>()),
      );
      expect(rpc.calls, hasLength(3));
    });

    test('does not retry business errors returned by the server', () async {
      final rpc = _FakeRpc([
        () => {'success': false, 'error': 'INSUFFICIENT_STOCK'},
      ]);
      final result = await _submitter(rpc).submit(
          lines: lines, paymentMethod: 'GCASH', clientRequestId: 'req-4');

      expect(result.success, isFalse);
      expect(result.error, 'INSUFFICIENT_STOCK');
      expect(rpc.calls, hasLength(1));
    });

    test('does not retry non-network exceptions', () async {
      final rpc = _FakeRpc([
        () => const PostgrestException(message: 'permission denied', code: '42501'),
      ]);
      await expectLater(
        _submitter(rpc).submit(
            lines: lines, paymentMethod: 'GCASH', clientRequestId: 'req-5'),
        throwsA(isA<PostgrestException>()),
      );
      expect(rpc.calls, hasLength(1));
    });

    test('falls back once to the legacy 2-arg function if V17 is not migrated', () async {
      final rpc = _FakeRpc([
        () => const PostgrestException(message: 'Could not find the function', code: 'PGRST202'),
        () => _ok('o-legacy'),
      ]);
      final result = await _submitter(rpc).submit(
          lines: lines, paymentMethod: 'CASH_ON_PICKUP', clientRequestId: 'req-6');

      expect(result.success, isTrue);
      expect(rpc.calls, hasLength(2));
      expect(rpc.calls.last.containsKey('p_client_request_id'), isFalse);
    });
  });
}
