import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teknoycart/features/auth/services/auth_service.dart';

/// Guards the verification-email error surface: a suspended/unreachable
/// backend must never leak a raw ClientException or HTTP status into the UI.
void main() {
  group('AuthService.sendVerificationEmail', () {
    test('turns a browser network failure into an actionable message',
        () async {
      await http.runWithClient(
        () async {
          await expectLater(
            AuthService().sendVerificationEmail('seller@gmail.com', 'Store'),
            throwsA(
              isA<VerificationEmailException>().having(
                (e) => e.message,
                'message',
                contains('Unable to reach the verification service'),
              ),
            ),
          );
        },
        () => MockClient(
          (_) async => throw http.ClientException('Failed to fetch'),
        ),
      );
    });

    test('surfaces the backend JSON message when delivery is rejected',
        () async {
      await http.runWithClient(
        () async {
          await expectLater(
            AuthService().sendVerificationEmail('seller@gmail.com', 'Store'),
            throwsA(
              isA<VerificationEmailException>().having(
                (e) => e.message,
                'message',
                'Verification email could not be sent. Please try again later.',
              ),
            ),
          );
        },
        () => MockClient(
          (_) async => http.Response(
            '{"type":"EMAIL_DELIVERY_FAILED","message":"Verification email could not be sent. Please try again later."}',
            503,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
    });

    test('falls back to a status message for non-JSON server errors', () async {
      await http.runWithClient(
        () async {
          await expectLater(
            AuthService().sendVerificationEmail('seller@gmail.com', 'Store'),
            throwsA(
              isA<VerificationEmailException>().having(
                (e) => e.message,
                'message',
                contains('temporarily unavailable'),
              ),
            ),
          );
        },
        () => MockClient((_) async => http.Response('Bad Gateway', 502)),
      );
    });

    test('reports a successful dispatch without throwing', () async {
      await http.runWithClient(
        () async {
          await AuthService()
              .sendVerificationEmail('seller@gmail.com', 'Store');
        },
        () => MockClient(
          (_) async => http.Response(
            '{"message":"Verification email sent successfully!"}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
    });
  });
}
