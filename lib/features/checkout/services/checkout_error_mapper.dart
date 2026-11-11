import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// A checkout rejected by `place_orders_atomic` with a known error code.
class CheckoutRejected implements Exception {
  final String? code;
  const CheckoutRejected(this.code);

  @override
  String toString() => 'CheckoutRejected($code)';
}

/// Plain-language text for a `place_orders_atomic` error code.
String checkoutRejectionMessage(String? code) => switch (code) {
      'INSUFFICIENT_STOCK' =>
        'Some items are no longer available. Refresh your cart and try again.',
      'PREORDER_NOT_ALLOWED' => 'Pre-orders are not enabled for one of these listings.',
      'INVALID_LISTING' => 'A listing or seller is no longer available.',
      'PRODUCT_NOT_ACTIVE' => 'A listing is no longer active.',
      'CANNOT_PURCHASE_OWN_PRODUCT' => 'You cannot purchase your own listing.',
      'PRICE_MISMATCH' =>
        'The price of a listing changed. Refresh the listing and try again.',
      'INVALID_QUANTITY' => 'One of the quantities is not valid.',
      'INVALID_LINES' => 'Your cart is empty or has too many items.',
      'INVALID_PAYMENT_METHOD' => 'Choose a payment method and try again.',
      'UNAUTHORIZED' => 'Your session expired. Please log in again.',
      _ => 'Could not place this order. Please refresh and try again.',
    };

/// User-facing message for anything thrown while placing a checkout.
///
/// Never shows raw exception text. Network failures say that the order may
/// still have gone through, because a timed-out request can succeed on the
/// server; the buyer is pointed at My Orders instead of retrying blindly.
String checkoutErrorMessage(Object error) {
  if (error is CheckoutRejected) return checkoutRejectionMessage(error.code);

  if (error is TimeoutException || error is http.ClientException) {
    return 'Connection lost. Your order may still have gone through — '
        'check My Orders before trying again.';
  }

  if (error is AuthException) {
    return 'Your session expired. Please log in again.';
  }

  if (error is PostgrestException) {
    if (error.code == '42501') {
      return 'You are not allowed to place this order. Please log in again.';
    }
    return 'The server could not place this order. Please try again in a moment.';
  }

  return 'Something went wrong while placing your order. Please try again.';
}
