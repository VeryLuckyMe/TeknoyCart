import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:teknoycart/features/checkout/models/variant_resolution.dart';
import 'package:teknoycart/features/checkout/services/checkout_error_mapper.dart';

/// In-memory product_variants table: productId -> {variantId: variantValue}.
VariantIdLookup _lookupFrom(Map<String, Map<String, String>> table) =>
    (String productId, {String? variantValue, required int limit}) async {
      final variants = table[productId] ?? const {};
      return variants.entries
          .where((e) => variantValue == null || e.value == variantValue)
          .map((e) => e.key)
          .take(limit)
          .toList();
    };

void main() {
  final table = {
    'shirt': {'v-s': 'S', 'v-m': 'M', 'v-l': 'L'},
    'mug': {'v-only': 'Default'},
    'ghost': <String, String>{},
  };
  final lookup = _lookupFrom(table);

  group('resolveCheckoutVariant', () {
    test('an explicit variant id always wins', () async {
      final r = await resolveCheckoutVariant(
          productId: 'shirt', variantId: 'v-l', lookup: lookup);
      expect(r.variantId, 'v-l');
    });

    test('matches the chosen variant by name', () async {
      final r = await resolveCheckoutVariant(
          productId: 'shirt', variantName: 'L', lookup: lookup);
      expect(r.variantId, 'v-l');
    });

    test('never guesses for a multi-variant product without a choice', () async {
      final r = await resolveCheckoutVariant(productId: 'shirt', lookup: lookup);
      expect(r.isResolved, isFalse);
      expect(r.failure, VariantResolutionFailure.ambiguous);
    });

    test('an unknown variant name on a multi-variant product is ambiguous, not "any"', () async {
      final r = await resolveCheckoutVariant(
          productId: 'shirt', variantName: 'XXL', lookup: lookup);
      expect(r.failure, VariantResolutionFailure.ambiguous);
    });

    test('nil placeholder id is treated as missing', () async {
      final r = await resolveCheckoutVariant(
          productId: 'shirt', variantId: kNilVariantId, lookup: lookup);
      expect(r.failure, VariantResolutionFailure.ambiguous);
    });

    test('a single-variant product resolves to its only variant', () async {
      final r = await resolveCheckoutVariant(productId: 'mug', lookup: lookup);
      expect(r.variantId, 'v-only');
    });

    test('a product with no variants is reported as not configured', () async {
      final r = await resolveCheckoutVariant(productId: 'ghost', lookup: lookup);
      expect(r.failure, VariantResolutionFailure.notConfigured);
    });
  });

  group('checkoutErrorMessage', () {
    test('maps server rejection codes to plain language', () {
      expect(checkoutErrorMessage(const CheckoutRejected('INSUFFICIENT_STOCK')),
          contains('no longer available'));
      expect(checkoutErrorMessage(const CheckoutRejected('SOMETHING_NEW')),
          'Could not place this order. Please refresh and try again.');
    });

    test('network failures warn that the order may have gone through', () {
      for (final e in [TimeoutException('t'), http.ClientException('reset')]) {
        expect(checkoutErrorMessage(e), contains('check My Orders'));
      }
    });

    test('never leaks raw exception text', () {
      final cases = <Object>[
        Exception('secret stack detail'),
        const PostgrestException(message: 'relation "orders" violates policy', code: 'XX000'),
        StateError('internal state'),
      ];
      for (final e in cases) {
        final msg = checkoutErrorMessage(e);
        expect(msg, isNot(contains('secret')));
        expect(msg, isNot(contains('relation')));
        expect(msg, isNot(contains('Exception')));
        expect(msg, isNot(contains('internal state')));
      }
    });
  });
}
