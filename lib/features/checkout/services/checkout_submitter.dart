import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/features/checkout/models/order.dart';

/// Signature of `SupabaseClient.rpc`, injectable for tests.
typedef RpcInvoker = Future<dynamic> Function(String fn, Map<String, dynamic> params);

/// Places a checkout through `place_orders_atomic` safely under bad networks.
///
/// When a chat id is supplied, it calls the 4-argument overload added in
/// migration V20 so the server can verify a seller-accepted Tawad price before
/// applying it. Without a chat id the catalog-price behavior is unchanged.
///
/// Every attempt carries the same [clientRequestId]. The server
/// (migration_v17_checkout_idempotency.sql) returns the orders from the first
/// successful attempt instead of creating duplicates, so a request that timed
/// out on the client but succeeded on the server can be retried safely.
class CheckoutSubmitter {
  CheckoutSubmitter(
    this._rpc, {
    this.maxAttempts = 3,
    this.attemptTimeout = const Duration(seconds: 20),
    this.retryDelay = const Duration(milliseconds: 800),
  });

  final RpcInvoker _rpc;
  final int maxAttempts;
  final Duration attemptTimeout;
  final Duration retryDelay;

  Future<AtomicOrderResult> submit({
    required List<Map<String, dynamic>> lines,
    required String paymentMethod,
    required String clientRequestId,
    String? chatId,
  }) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        final raw = await _rpc('place_orders_atomic', {
          'p_lines': lines,
          'p_payment_method': paymentMethod,
          'p_client_request_id': clientRequestId,
          if (chatId != null) 'p_chat_id': chatId,
        }).timeout(attemptTimeout);
        return AtomicOrderResult.fromDynamic(raw);
      } on PostgrestException catch (e) {
        if (isMissingIdempotentOverload(e)) {
          // A negotiated price can only be honoured by the 4-argument
          // function (V20). Falling back would let the buyer believe the
          // agreed price was applied when it was not.
          if (chatId != null) rethrow;
          // Database not yet migrated to V17. Fall back to the legacy
          // function exactly once: it has no idempotency, so never retry it.
          final raw = await _rpc('place_orders_atomic', {
            'p_lines': lines,
            'p_payment_method': paymentMethod,
          }).timeout(attemptTimeout);
          return AtomicOrderResult.fromDynamic(raw);
        }
        rethrow;
      } catch (e) {
        if (!isTransientNetworkError(e) || attempt >= maxAttempts) rethrow;
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  /// PostgREST could not find the 3-argument function signature.
  static bool isMissingIdempotentOverload(PostgrestException e) =>
      e.code == 'PGRST202';

  /// Failures where the request may or may not have reached the server.
  static bool isTransientNetworkError(Object e) =>
      e is TimeoutException || e is http.ClientException;
}
