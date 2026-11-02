import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/chat/services/presence_service.dart';

void main() {
  group('PresenceService Unit Tests', () {
    test('singleton instance returns identical reference', () {
      final s1 = PresenceService.instance;
      final s2 = PresenceService.instance;
      expect(identical(s1, s2), isTrue);
    });

    test('onlineThreshold is configured to 10 minutes', () {
      expect(PresenceService.onlineThreshold, equals(const Duration(minutes: 10)));
    });

    test('stopHeartbeat resets internal timer and user reference safely', () async {
      final service = PresenceService.instance;
      await service.stopHeartbeat();
      // Calling stop repeatedly without active session must remain graceful
      await service.stopHeartbeat();
    });
  });
}
