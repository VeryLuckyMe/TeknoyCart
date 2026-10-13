import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/services/fcm_service.dart';

void main() {
  group('FcmService Client & Lifecycle Tests', () {
    test('Empty or whitespace token is rejected and not cached', () async {
      final fcm = FcmService.instance;
      final resultEmpty = await fcm.registerToken('');
      expect(resultEmpty, isFalse);

      final resultWhitespace = await fcm.registerToken('   ');
      expect(resultWhitespace, isFalse);
    });

    test('Cold-start deep-link payload queueing and atomic consumption', () {
      final fcm = FcmService.instance;

      expect(fcm.consumePendingPayload(), isNull);

      final testPayload = {
        'referenceType': 'ORDER',
        'referenceId': 'order-uuid-999',
        'title': '📦 Order Accepted',
        'body': 'Your order has been accepted by the seller.',
      };

      fcm.queueNotificationPayload(testPayload);

      final consumed = fcm.consumePendingPayload();
      expect(consumed, isNotNull);
      expect(consumed!['referenceType'], equals('ORDER'));
      expect(consumed['referenceId'], equals('order-uuid-999'));

      // Subsequent read returns null (atomic one-shot consumption)
      expect(fcm.consumePendingPayload(), isNull);
    });

    test('Foreground notification stream dispatches to subscribers', () async {
      final fcm = FcmService.instance;
      final completer = Completer<Map<String, dynamic>>();

      final subscription = fcm.onForegroundNotification.listen((event) {
        if (!completer.isCompleted) {
          completer.complete(event);
        }
      });

      final payload = {
        'title': '🎉 Seller Verification Approved!',
        'referenceType': 'KYC',
      };

      fcm.dispatchForegroundNotification(payload);

      final received = await completer.future.timeout(const Duration(seconds: 2));
      expect(received['title'], equals('🎉 Seller Verification Approved!'));
      expect(received['referenceType'], equals('KYC'));

      await subscription.cancel();
    });

    test('Pre-logout unregister clears cached token', () async {
      final fcm = FcmService.instance;
      // Without auth session, unregister safely cleans cache without throwing
      final success = await fcm.unregisterToken();
      expect(success, isTrue);
      expect(fcm.cachedToken, isNull);
    });
  });
}
