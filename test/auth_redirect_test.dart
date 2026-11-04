import 'package:flutter_test/flutter_test.dart';
import 'package:teknoycart/features/auth/utils/auth_redirect.dart';

/// Regression tests for the "reset email points at localhost" bug.
///
/// The client used to send `redirectTo: null` on web, so Supabase fell back to
/// the dashboard Site URL (http://localhost:3000) and every reset link was dead.
void main() {
  group('AuthRedirectConfig.resolve', () {
    test('uses the explicit web define verbatim', () {
      expect(
        AuthRedirectConfig.resolve(
          isWeb: true,
          baseUri: Uri.parse('http://localhost:59519/'),
          configuredWebUrl: 'https://teknoycart.example/',
        ),
        'https://teknoycart.example/',
      );
    });

    test('falls back to the current web origin, stripping query and fragment', () {
      expect(
        AuthRedirectConfig.resolve(
          isWeb: true,
          baseUri: Uri.parse(
            'https://app.teknoycart.example/login?next=/feed#section',
          ),
          configuredWebUrl: '',
        ),
        'https://app.teknoycart.example/login',
      );
    });

    test('preserves a deploy sub-path', () {
      expect(
        AuthRedirectConfig.resolve(
          isWeb: true,
          baseUri: Uri.parse('https://host.example/app/'),
          configuredWebUrl: '',
        ),
        'https://host.example/app/',
      );
    });

    test('keeps the native deep link unchanged', () {
      expect(
        AuthRedirectConfig.resolve(
          isWeb: false,
          baseUri: Uri.parse('/data/user/0/app'),
        ),
        AuthRedirectConfig.mobileUrl,
      );
      expect(AuthRedirectConfig.mobileUrl, 'teknoycart://login-callback');
    });

    test('returns null for a non-http base URI instead of inventing one', () {
      expect(
        AuthRedirectConfig.resolve(
          isWeb: true,
          baseUri: Uri.parse('file:///index.html'),
          configuredWebUrl: '',
        ),
        isNull,
      );
    });
  });

  group('AuthRedirectFailure.parse', () {
    test('reads the otp_expired error that Supabase appends to the redirect', () {
      final uri = Uri.parse(
        'http://localhost:59519/?error=access_denied&error_code=otp_expired'
        '&error_description=Email+link+is+invalid+or+has+expired',
      );

      final failure = AuthRedirectFailure.parse(uri);
      expect(failure, isNotNull);
      expect(failure!.code, 'otp_expired');
      expect(failure.message, contains('expired'));
    });

    test('also reads the error mirrored into the fragment', () {
      final uri = Uri.parse(
        'http://localhost:59519/#error=access_denied&error_code=otp_expired',
      );
      expect(AuthRedirectFailure.parse(uri)?.code, 'otp_expired');
    });

    test('returns null for a clean URL (no false positives on normal loads)', () {
      expect(AuthRedirectFailure.parse(Uri.parse('http://localhost:8080/')), isNull);
      expect(
        AuthRedirectFailure.parse(
          Uri.parse('http://localhost:8080/?code=abc123'),
        ),
        isNull,
      );
    });
  });
}
