import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/models/notification_item.dart';

void main() {
  group('NotificationItem Unit Tests', () {
    final fixedDate = DateTime.parse('2026-11-01T10:00:00Z');

    test('toJson and fromJson serialize and deserialize symmetrically', () {
      final original = NotificationItem(
        id: 'notif-101',
        userId: 'user-xyz',
        title: 'Order Completed',
        body: 'Your deal at the Canteen was confirmed.',
        type: 'ORDER_STATUS',
        referenceId: 'ord-888',
        referenceType: 'ORDER',
        isRead: false,
        createdAt: fixedDate,
      );

      final json = original.toJson();
      final restored = NotificationItem.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.userId, equals(original.userId));
      expect(restored.title, equals(original.title));
      expect(restored.body, equals(original.body));
      expect(restored.type, equals(original.type));
      expect(restored.referenceId, equals(original.referenceId));
      expect(restored.referenceType, equals(original.referenceType));
      expect(restored.isRead, isFalse);
    });

    test('copyWith updates specified properties while preserving others', () {
      final item = NotificationItem(
        id: 'notif-102',
        userId: 'user-xyz',
        title: 'Pending Offer',
        body: 'New offer received.',
        type: 'OFFER',
        isRead: false,
        createdAt: fixedDate,
      );

      final updated = item.copyWith(isRead: true, title: 'Offer Accepted');
      expect(updated.id, equals('notif-102'));
      expect(updated.title, equals('Offer Accepted'));
      expect(updated.isRead, isTrue);
      expect(updated.type, equals('OFFER'));
    });

    test('fromJson supplies safe defaults for optional notification fields', () {
      final item = NotificationItem.fromJson({
        'id': 'notif-103',
        'user_id': 'user-xyz',
        'created_at': fixedDate.toIso8601String(),
      });

      expect(item.title, equals('Notification'));
      expect(item.body, isEmpty);
      expect(item.type, equals('SYSTEM'));
      expect(item.isRead, isFalse);
      expect(item.referenceId, isNull);
      expect(item.referenceType, isNull);
    });

    test('timeAgo calculates relative labels accurately', () {
      final justNowItem = NotificationItem(
        id: '1',
        userId: 'u',
        title: 't',
        body: 'b',
        type: 'SYSTEM',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(seconds: 15)),
      );
      expect(justNowItem.timeAgo, equals('Just now'));

      final minutesItem = NotificationItem(
        id: '2',
        userId: 'u',
        title: 't',
        body: 'b',
        type: 'SYSTEM',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(minutesItem.timeAgo, equals('10m ago'));

      final hoursItem = NotificationItem(
        id: '3',
        userId: 'u',
        title: 't',
        body: 'b',
        type: 'SYSTEM',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      );
      expect(hoursItem.timeAgo, equals('4h ago'));
    });
  });
}

