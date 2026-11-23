import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/views/widgets/email_verification_dialog.dart';

void main() {
  testWidgets('verification dialog returns the user to sign in without polling',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const EmailVerificationDialog(
                  email: 'student@cit.edu',
                ),
              );
            },
            child: const Text('Open verification'),
          ),
        );
      }),
    ));

    await tester.tap(find.text('Open verification'));
    await tester.pump();

    expect(find.text('I verified — return to sign in'), findsOneWidget);
    expect(find.text('Resend in 60s'), findsOneWidget);

    await tester.tap(find.text('I verified — return to sign in'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, isTrue);
  });

  testWidgets('failed initial delivery shows the reason and allows a retry',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () {
              showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => const EmailVerificationDialog(
                  email: 'seller@gmail.com',
                  fullName: 'Wildcat Store',
                  initialDeliveryError:
                      'Unable to reach the verification service. Please check your internet connection and try again.',
                ),
              );
            },
            child: const Text('Open verification'),
          ),
        );
      }),
    ));

    await tester.tap(find.text('Open verification'));
    await tester.pump();

    expect(find.text('Email Not Sent'), findsOneWidget);
    expect(
      find.textContaining('Unable to reach the verification service'),
      findsOneWidget,
    );
    // The user must be able to retry immediately, not wait 60 seconds.
    expect(find.text('Resend Verification Email'), findsOneWidget);
    // No fake "email sent" countdown while delivery has failed.
    expect(find.text('Link expires in'), findsNothing);
    expect(find.textContaining('sent to:'), findsOneWidget);
  });

  testWidgets('closes by itself once the emailed link was clicked', (tester) async {
    bool? result;
    var verifiedCalls = 0;
    var checks = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: ElevatedButton(
            onPressed: () async {
              result = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => EmailVerificationDialog(
                  email: 'student@cit.edu',
                  pollKey: 'key-123',
                  onVerified: () => verifiedCalls++,
                  statusChecker: (key) async {
                    expect(key, 'key-123');
                    checks++;
                    return checks >= 2; // pending first, then verified
                  },
                ),
              );
            },
            child: const Text('Open verification'),
          ),
        );
      }),
    ));

    await tester.tap(find.text('Open verification'));
    await tester.pump();
    expect(find.byType(EmailVerificationDialog), findsOneWidget);

    await tester.pump(EmailVerificationDialog.pollInterval);
    await tester.pump();
    expect(find.byType(EmailVerificationDialog), findsOneWidget);

    await tester.pump(EmailVerificationDialog.pollInterval);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(EmailVerificationDialog), findsNothing);
    expect(result, isTrue);
    expect(verifiedCalls, 1);
  });

  testWidgets('does not poll without a pollKey', (tester) async {
    var checks = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EmailVerificationDialog(
          email: 'student@cit.edu',
          statusChecker: (_) async {
            checks++;
            return true;
          },
        ),
      ),
    ));
    await tester.pump(EmailVerificationDialog.pollInterval * 3);
    expect(checks, 0);
    expect(find.byType(EmailVerificationDialog), findsOneWidget);
  });
}
