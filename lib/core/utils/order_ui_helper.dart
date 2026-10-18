import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

/// Unified UI helper for high-craft order status formatting, semantic palettes,
/// micro-indicator icons, human-readable dates, and UI/UX Pro Max badge components.
///
/// Ensures ZERO raw snake_case enums or underscores ('_') ever leak into user-facing UI.
class OrderUiHelper {
  OrderUiHelper._();

  /// Converts any order status enum to a human-friendly, title-cased label.
  /// Guarantees that unmapped or novel statuses never display underscores to users.
  static String formatStatus(String? rawStatus, {bool isOutOfStock = false}) {
    if (rawStatus == null || rawStatus.trim().isEmpty) return 'Pending';
    final status = rawStatus.trim().toUpperCase();

    if (isOutOfStock && (status == 'SELLER_ACCEPTED' || status == 'APPROVED' || status == 'ACCEPTED')) {
      return 'Reserved (Out of Stock)';
    }

    switch (status) {
      case 'MEETUP_SCHEDULED':
        return 'Meetup Scheduled';
      case 'HANDOFF_PENDING':
        return 'Handoff in Progress';
      case 'NEEDS_REVIEW':
        return 'Reschedule Needed';
      case 'DISPUTED':
        return 'Under Admin Mediation';
      case 'SELLER_ACCEPTED':
      case 'APPROVED':
      case 'ACCEPTED':
        return isOutOfStock ? 'Reserved (Out of Stock)' : 'Item Reserved';
      case 'PLACED':
      case 'PENDING_SELLER_ACCEPT':
        return 'Awaiting Seller';
      case 'AWAITING_PAYMENT':
        return 'Awaiting Payment';
      case 'ESCROWED':
        return 'Funds in Escrow';
      case 'PAYMENT_SUBMITTED':
        return 'Payment Submitted';
      case 'PAYMENT_VERIFIED':
        return 'Payment Verified';
      case 'COMPLETED':
        return 'Completed';
      case 'DECLINED':
      case 'REJECTED':
        return 'Declined';
      case 'CANCELLED':
        return 'Cancelled';
      case 'RETURN_REQUESTED':
        return 'Return Requested';
      case 'RETURN_APPROVED':
        return 'Return Approved';
      case 'RETURN_DECLINED':
        return 'Return Declined';
      case 'RETURN_COMPLETED':
        return 'Return Completed';
      case 'REFUND_PENDING':
        return 'Refund Pending';
      case 'REFUND_REQUESTED':
        return 'Refund Requested';
      case 'REFUNDED':
      case 'REFUND_COMPLETED':
        return 'Refunded';
      case 'INQUIRY_SENT':
        return 'Pending';
      default:
        // Defensive transformation: replace any underscores with spaces and title-case words.
        return cleanEnumText(status);
    }
  }

  /// Curated semantic color for the order status.
  static Color statusColor(String? rawStatus, {bool isOutOfStock = false}) {
    if (isOutOfStock) return const Color(0xFFEA580C);
    if (rawStatus == null) return TeknoyTheme.warning;
    final status = rawStatus.trim().toUpperCase();

    switch (status) {
      case 'COMPLETED':
      case 'PAYMENT_VERIFIED':
      case 'RETURN_COMPLETED':
        return TeknoyTheme.success; // Emerald #10B981

      case 'ESCROWED':
        return const Color(0xFF2563EB); // Cobalt Escrow #2563EB

      case 'MEETUP_SCHEDULED':
        return const Color(0xFF0284C7); // Sky / Cobalt Calm Blue

      case 'HANDOFF_PENDING':
        return const Color(0xFF6366F1); // Indigo Active Handoff

      case 'SELLER_ACCEPTED':
      case 'APPROVED':
      case 'ACCEPTED':
        return TeknoyTheme.warningDark; // Warm Amber / CIT Gold

      case 'AWAITING_PAYMENT':
      case 'PAYMENT_SUBMITTED':
        return const Color(0xFF4F46E5); // Indigo Accent

      case 'REFUND_PENDING':
      case 'RETURN_REQUESTED':
      case 'NEEDS_REVIEW':
        return TeknoyTheme.warning; // #F59E0B

      case 'REFUNDED':
      case 'REFUND_COMPLETED':
      case 'RETURN_APPROVED':
        return const Color(0xFF0D9488); // Teal

      case 'DECLINED':
      case 'REJECTED':
      case 'CANCELLED':
      case 'RETURN_DECLINED':
        return TeknoyTheme.error; // Crimson #EF4444

      case 'DISPUTED':
        return const Color(0xFFE11D48); // Deep Crimson / Mediation

      case 'PENDING_SELLER_ACCEPT':
      case 'PLACED':
      case 'INQUIRY_SENT':
      default:
        return TeknoyTheme.warningDark;
    }
  }

  /// Micro-indicator icon matching the semantic order status.
  static IconData statusIcon(String? rawStatus) {
    if (rawStatus == null) return Icons.info_outline_rounded;
    final status = rawStatus.trim().toUpperCase();

    switch (status) {
      case 'MEETUP_SCHEDULED':
        return Icons.calendar_today_rounded;
      case 'HANDOFF_PENDING':
        return Icons.sync_rounded;
      case 'NEEDS_REVIEW':
        return Icons.schedule_rounded;
      case 'DISPUTED':
        return Icons.gavel_rounded;
      case 'SELLER_ACCEPTED':
      case 'APPROVED':
      case 'ACCEPTED':
        return Icons.bookmark_added_rounded;
      case 'AWAITING_PAYMENT':
        return Icons.hourglass_top_rounded;
      case 'ESCROWED':
        return Icons.shield_rounded;
      case 'PAYMENT_SUBMITTED':
        return Icons.outgoing_mail;
      case 'PAYMENT_VERIFIED':
        return Icons.verified_rounded;
      case 'COMPLETED':
      case 'RETURN_COMPLETED':
        return Icons.check_circle_rounded;
      case 'DECLINED':
      case 'REJECTED':
      case 'CANCELLED':
      case 'RETURN_DECLINED':
        return Icons.cancel_rounded;
      case 'RETURN_REQUESTED':
        return Icons.assignment_return_rounded;
      case 'RETURN_APPROVED':
      case 'REFUNDED':
      case 'REFUND_COMPLETED':
        return Icons.check_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  /// Cleans any screaming snake case enum (e.g. 'RESCHEDULE_RETURN') to human Title Case (e.g. 'Reschedule Return').
  static String cleanEnumText(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    return raw
        .trim()
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + (word.length > 1 ? word.substring(1).toLowerCase() : '');
        })
        .join(' ');
  }

  /// Formats admin dispute rulings human-friendly with clear meaning.
  static String formatDisputeRuling(String? ruling) {
    if (ruling == null || ruling.trim().isEmpty) return 'Pending Review';
    final clean = ruling.trim().toUpperCase();
    switch (clean) {
      case 'RELEASE_SELLER':
        return 'Funds Released to Seller';
      case 'REFUND_BUYER':
        return 'Buyer Refund Approved';
      case 'RESCHEDULE_RETURN':
        return 'Reschedule & Return Approved';
      default:
        return cleanEnumText(clean);
    }
  }

  /// Formats item conditions without aggressive all-caps or underscores.
  static String formatCondition(String? condition) {
    if (condition == null || condition.trim().isEmpty) return 'Standard';
    final trimmed = condition.trim();
    if (trimmed.contains('_')) {
      return cleanEnumText(trimmed);
    }
    // If it's already mixed or title-case, preserve natural casing
    if (trimmed == trimmed.toUpperCase() && trimmed.length > 4) {
      return cleanEnumText(trimmed);
    }
    return trimmed;
  }

  /// Formats dates cleanly as e.g. "Oct 11, 2026" or "Oct 11, 2026 · 10:45 AM"
  /// instead of crude substring slices like "2026-10-11".
  static String formatDate(dynamic dateRaw, {bool withTime = false}) {
    if (dateRaw == null) return '—';
    DateTime? dt;
    if (dateRaw is DateTime) {
      dt = dateRaw;
    } else if (dateRaw is String) {
      dt = DateTime.tryParse(dateRaw);
    }
    if (dt == null) return dateRaw.toString();

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthStr = months[dt.month - 1];
    final dateStr = '$monthStr ${dt.day}, ${dt.year}';

    if (!withTime) return dateStr;

    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$dateStr · $hour:$minute $period';
  }

  /// Strips ugly internal tags like '[PRE-ORDER]' from location strings.
  static String cleanLocation(String? loc) {
    if (loc == null || loc.trim().isEmpty) return '—';
    return loc.replaceAll('[PRE-ORDER]', '').trim();
  }

  /// UI/UX Pro Max Status Badge Widget with micro-indicator dot or icon.
  static Widget buildStatusBadge({
    required String? status,
    bool isOutOfStock = false,
    bool showIcon = true,
    double fontSize = 11.0,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  }) {
    final label = formatStatus(status, isOutOfStock: isOutOfStock);
    final color = statusColor(status, isOutOfStock: isOutOfStock);
    final icon = statusIcon(status);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28), width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
