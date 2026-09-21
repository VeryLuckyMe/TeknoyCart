import 'package:flutter/material.dart';
import 'package:teknoycart/core/theme.dart';

class OrderStatusStepper extends StatelessWidget {
  final bool isPreorder;
  final String status;
  final bool isSeller;
  final bool isDark;

  const OrderStatusStepper({
    super.key,
    required this.isPreorder,
    required this.status,
    required this.isSeller,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final steps = isPreorder
        ? ['Pre-Ordered', 'Batch Sourcing', 'Ready & Scheduled', 'Handoff', 'Done']
        : ['Placed', 'Accepted', 'Meetup', 'Handoff', 'Done'];

    final statusToStep = {
      'PLACED': 0,
      'ACCEPTED': 1,
      'PAYMENT_SUBMITTED': 1,
      'PAYMENT_VERIFIED': 1,
      'MEETUP_SCHEDULED': 2,
      'NEEDS_REVIEW': 2,
      'HANDOFF_PENDING': 3,
      'COMPLETED': 4,
      'RETURN_COMPLETED': 4,
      'REFUND_COMPLETED': 4,
      'CANCELLED': -1,
      'DISPUTED': -1,
      'RETURN_REQUESTED': 3,
      'RETURN_APPROVED': 3,
      'REFUND_REQUESTED': 1,
    };

    final currentStep = statusToStep[status] ?? 0;
    final isDeclined = status == 'DECLINED' || status == 'REJECTED';
    final isCancelled = status == 'CANCELLED';
    final isNeedsReview = status == 'NEEDS_REVIEW';
    final isDisputed = status == 'DISPUTED';
    final isReturnRequested = status == 'RETURN_REQUESTED';
    final isReturnApproved = status == 'RETURN_APPROVED';
    final isReturnCompleted = status == 'RETURN_COMPLETED';
    final isRefundCompleted = status == 'REFUND_COMPLETED';
    final isRefundRequested = status == 'REFUND_REQUESTED';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141418) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF22222A) : const Color(0xFFECECEF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 18, color: TeknoyTheme.citGold),
              const SizedBox(width: 8),
              const Text(
                'Order Status',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isDeclined || isCancelled)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isCancelled
                        ? 'This order was cancelled.'
                        : 'This order was declined by the seller.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            )
          else if (isDisputed)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.purple.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: Colors.purple, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Under Admin Mediation. Campus administrators are adjudicating this dispute.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isNeedsReview)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule_rounded, color: Colors.amber, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Meetup timed out (>24h) or had failed attempts. Reschedule meetup or report no-show.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isReturnRequested)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withOpacity(0.25))),
              child: const Row(
                children: [
                  Icon(Icons.assignment_return_rounded, color: Colors.orange, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Return requested by buyer. Awaiting seller review.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isReturnApproved)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.teal.withOpacity(0.25))),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: Colors.teal, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Return Approved! Meet up at landmark to return item & verify return code.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isReturnCompleted)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.25))),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Return Completed! Item returned and cash refunded at the meetup.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isRefundCompleted)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withOpacity(0.25))),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Refund Completed! GCash refund transaction has been verified.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isRefundRequested)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withOpacity(0.25))),
              child: const Row(
                children: [
                  Icon(Icons.currency_exchange_rounded, color: Colors.indigo, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Refund Requested. Awaiting seller to return GCash payment.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.indigo,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: List.generate(steps.length * 2 - 1, (i) {
                if (i.isOdd) {
                  final stepIdx = i ~/ 2;
                  return Expanded(
                    child: Container(
                      height: 2,
                      color: stepIdx < currentStep
                          ? TeknoyTheme.citMaroon
                          : (isDark ? Colors.white12 : Colors.black12),
                    ),
                  );
                }
                final stepIdx = i ~/ 2;
                final done = stepIdx <= currentStep;
                return Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? TeknoyTheme.citMaroon
                            : (isDark ? Colors.white12 : Colors.black12),
                        border: Border.all(
                          color: done
                              ? TeknoyTheme.citMaroon
                              : (isDark ? Colors.white24 : Colors.black26),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: done
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : Text(
                                '${stepIdx + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[stepIdx],
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 9,
                        fontWeight: done ? FontWeight.bold : FontWeight.normal,
                        color: done
                            ? TeknoyTheme.citMaroon
                            : (isDark ? Colors.white38 : Colors.black38),
                      ),
                    ),
                  ],
                );
              }),
            ),
          if (isPreorder && (status == 'ACCEPTED' || status == 'PAYMENT_VERIFIED')) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TeknoyTheme.citGold.withOpacity(isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TeknoyTheme.citGold.withOpacity(0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.hourglass_top_rounded,
                      color: TeknoyTheme.citGold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSeller
                          ? 'Batch in Sourcing: You are preparing this pre-order. Once your batch arrives on campus, tap "Item Arrived — Schedule Meetup" below to finalize the meetup and send an automated in-app chat notice.'
                          : 'Batch in Preparation: The seller is preparing your pre-order (Est. 3-7 days). You will receive an automated in-app chat notification the moment the item arrives on campus and is ready for pickup!',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isPreorder && status == 'MEETUP_SCHEDULED') ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.campaign_rounded, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pre-Order Ready: Campus meetup has been scheduled! Review the meetup spot and time below and check your in-app chat for messages.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
