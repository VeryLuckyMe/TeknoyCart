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
}
