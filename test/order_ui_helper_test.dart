import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:teknoycart/core/utils/order_ui_helper.dart';

void main() {
  group('OrderUiHelper Unit & Component Tests (UI/UX Pro Max Standard)', () {
    test('formatStatus eliminates underscores and provides human-friendly labels', () {
      expect(OrderUiHelper.formatStatus('MEETUP_SCHEDULED'), 'Meetup Scheduled');
      expect(OrderUiHelper.formatStatus('HANDOFF_PENDING'), 'Handoff in Progress');
      expect(OrderUiHelper.formatStatus('NEEDS_REVIEW'), 'Reschedule Needed');
      expect(OrderUiHelper.formatStatus('DISPUTED'), 'Under Admin Mediation');
      expect(OrderUiHelper.formatStatus('SELLER_ACCEPTED'), 'Item Reserved');
      expect(OrderUiHelper.formatStatus('APPROVED'), 'Item Reserved');
      expect(OrderUiHelper.formatStatus('APPROVED', isOutOfStock: true), 'Reserved (Out of Stock)');
      expect(OrderUiHelper.formatStatus('AWAITING_PAYMENT'), 'Awaiting Payment');
      expect(OrderUiHelper.formatStatus('ESCROWED'), 'Funds in Escrow');
      expect(OrderUiHelper.formatStatus('PAYMENT_SUBMITTED'), 'Payment Submitted');
      expect(OrderUiHelper.formatStatus('PAYMENT_VERIFIED'), 'Payment Verified');
      expect(OrderUiHelper.formatStatus('COMPLETED'), 'Completed');
      expect(OrderUiHelper.formatStatus('CANCELLED'), 'Cancelled');
      expect(OrderUiHelper.formatStatus('DECLINED'), 'Declined');
      expect(OrderUiHelper.formatStatus('RETURN_REQUESTED'), 'Return Requested');
      expect(OrderUiHelper.formatStatus('RETURN_APPROVED'), 'Return Approved');
      expect(OrderUiHelper.formatStatus('REFUND_PENDING'), 'Refund Pending');
      expect(OrderUiHelper.formatStatus('REFUNDED'), 'Refunded');
    });

    test('formatStatus defensively cleans unknown snake_case enums with zero underscores', () {
      expect(OrderUiHelper.formatStatus('CUSTOM_UNKNOWN_STATE'), 'Custom Unknown State');
      expect(OrderUiHelper.formatStatus('BATCH_PREPARATION_IN_PROGRESS'), 'Batch Preparation In Progress');
      expect(OrderUiHelper.formatStatus(null), 'Pending');
    });

    test('statusColor assigns curated semantic colors', () {
      expect(OrderUiHelper.statusColor('COMPLETED'), TeknoyTheme.success);
      expect(OrderUiHelper.statusColor('ESCROWED'), const Color(0xFF2563EB));
      expect(OrderUiHelper.statusColor('MEETUP_SCHEDULED'), const Color(0xFF0284C7));
      expect(OrderUiHelper.statusColor('HANDOFF_PENDING'), const Color(0xFF6366F1));
      expect(OrderUiHelper.statusColor('DISPUTED'), const Color(0xFFE11D48));
      expect(OrderUiHelper.statusColor('CANCELLED'), TeknoyTheme.error);
      expect(OrderUiHelper.statusColor('APPROVED', isOutOfStock: true), const Color(0xFFEA580C));
    });

    test('statusIcon assigns contextual micro-indicators', () {
      expect(OrderUiHelper.statusIcon('MEETUP_SCHEDULED'), Icons.calendar_today_rounded);
      expect(OrderUiHelper.statusIcon('ESCROWED'), Icons.shield_rounded);
      expect(OrderUiHelper.statusIcon('COMPLETED'), Icons.check_circle_rounded);
      expect(OrderUiHelper.statusIcon('DISPUTED'), Icons.gavel_rounded);
    });

    test('formatDate renders human-readable dates without raw ISO slices', () {
      expect(OrderUiHelper.formatDate('2026-10-11T14:30:00Z'), 'Oct 11, 2026');
      expect(OrderUiHelper.formatDate(DateTime(2026, 10, 11)), 'Oct 11, 2026');
      expect(OrderUiHelper.formatDate(null), '—');
    });

    test('cleanLocation strips internal debug tags', () {
      expect(OrderUiHelper.cleanLocation('[PRE-ORDER] Library Lobby'), 'Library Lobby');
      expect(OrderUiHelper.cleanLocation('Canteen 2'), 'Canteen 2');
      expect(OrderUiHelper.cleanLocation(null), '—');
    });

    test('formatDisputeRuling cleans raw admin constants', () {
      expect(OrderUiHelper.formatDisputeRuling('RELEASE_SELLER'), 'Funds Released to Seller');
      expect(OrderUiHelper.formatDisputeRuling('REFUND_BUYER'), 'Buyer Refund Approved');
      expect(OrderUiHelper.formatDisputeRuling('RESCHEDULE_RETURN'), 'Reschedule & Return Approved');
    });

    test('formatCondition prevents harsh uppercase and cleans snake case', () {
      expect(OrderUiHelper.formatCondition('LIKE_NEW'), 'Like New');
      expect(OrderUiHelper.formatCondition('BRAND_NEW'), 'Brand New');
      expect(OrderUiHelper.formatCondition('Freshly Made Today'), 'Freshly Made Today');
    });

    testWidgets('buildStatusBadge renders elegant UI/UX Pro Max pill with icon and label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrderUiHelper.buildStatusBadge(
              status: 'MEETUP_SCHEDULED',
            ),
          ),
        ),
      );

      expect(find.text('Meetup Scheduled'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_rounded), findsOneWidget);
    });
  });
}
