import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/config/api_config.dart';

void main() {
  group('ApiConfig Unit Tests', () {
    test('default endpoints resolve with standard baseUrl', () {
      expect(ApiConfig.baseUrl, isNotEmpty);
      expect(ApiConfig.ordersUrl, equals('${ApiConfig.baseUrl}/orders'));
      expect(ApiConfig.authUrl, equals('${ApiConfig.baseUrl}/auth'));
      expect(ApiConfig.paymentsUrl, equals('${ApiConfig.baseUrl}/payments'));
    });

    test('demoMode defaults to false in standard test builds', () {
      expect(ApiConfig.demoMode, isFalse);
    });
  });
}
