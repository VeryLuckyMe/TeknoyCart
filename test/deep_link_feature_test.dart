import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/services/deep_link_service.dart';

void main() {
  group('DeepLinkParser Unit Tests', () {
    test('parses teknoycart://order?id=<uuid> into DeepLinkOrder', () {
      final uri = Uri.parse('teknoycart://order?id=123e4567-e89b-12d3-a456-426614174000');
      final dest = DeepLinkParser.parse(uri);

      expect(dest, isA<DeepLinkOrder>());
      expect((dest as DeepLinkOrder).orderId, '123e4567-e89b-12d3-a456-426614174000');
    });

    test('parses path-style teknoycart://order/<uuid> into DeepLinkOrder', () {
      final uri = Uri.parse('teknoycart://order/123e4567-e89b-12d3-a456-426614174000');
      final dest = DeepLinkParser.parse(uri);

      expect(dest, isA<DeepLinkOrder>());
      expect((dest as DeepLinkOrder).orderId, '123e4567-e89b-12d3-a456-426614174000');
    });

    test('returns DeepLinkUnknown when order id is missing or blank', () {
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://order')), isA<DeepLinkUnknown>());
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://order?id=   ')), isA<DeepLinkUnknown>());
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://order/')), isA<DeepLinkUnknown>());
    });

    test('parses teknoycart://wishlist and teknoycart://home', () {
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://wishlist')), isA<DeepLinkWishlist>());
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://home')), isA<DeepLinkHome>());
    });

    test('ignores Supabase auth callback teknoycart://login-callback', () {
      final uri = Uri.parse('teknoycart://login-callback#access_token=abc&type=recovery');
      expect(DeepLinkParser.parse(uri), isA<DeepLinkIgnored>());
    });

    test('returns DeepLinkUnknown for null or foreign scheme URIs without throwing', () {
      expect(DeepLinkParser.parse(null), isA<DeepLinkUnknown>());
      expect(DeepLinkParser.parse(Uri.parse('https://example.com/order?id=123')), isA<DeepLinkUnknown>());
      expect(DeepLinkParser.parse(Uri.parse('teknoycart://unknown-host')), isA<DeepLinkUnknown>());
    });
  });
}
