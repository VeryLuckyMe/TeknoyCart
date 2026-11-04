import 'package:flutter/foundation.dart';

/// Centralized auth-email redirect configuration.
///
/// Supabase embeds whatever `redirectTo` value the client sends into the
/// password-reset email. When the client sends `null` — which the web build did
/// until now — Supabase silently falls back to the project's dashboard
/// *Site URL* (`http://localhost:3000`), producing links that cannot work.
///
/// Build-time overrides:
///   flutter run -d chrome --web-port=8080 \
///     --dart-define=AUTH_REDIRECT_URL=http://localhost:8080/
///
/// Production:  --dart-define=AUTH_REDIRECT_URL=https://your-web-host/
///
/// Every value used here must also be present in the Supabase dashboard under
/// Authentication → URL Configuration → Redirect URLs, otherwise Supabase
/// ignores it and falls back to the Site URL again.
class AuthRedirectConfig {
  AuthRedirectConfig._();

  /// Explicit web origin used in auth emails (reset / recovery).
  static const String webUrl = String.fromEnvironment('AUTH_REDIRECT_URL');

  /// Native deep-link target. Must match the intent filter in
  /// `android/app/src/main/AndroidManifest.xml` and the iOS URL scheme.
  static const String mobileUrl = String.fromEnvironment(
    'AUTH_REDIRECT_MOBILE_URL',
    defaultValue: 'teknoycart://login-callback',
  );

  /// Resolves the `redirectTo` argument for Supabase auth emails.
  ///
  /// Precedence for web: explicit [webUrl] → current page origin/path with the
  /// query and fragment stripped (survives sub-path deploys) → `null`, which is
  /// the old "use Site URL" fallback of last resort.
  static String? resolve({
    bool? isWeb,
    Uri? baseUri,
    String configuredWebUrl = AuthRedirectConfig.webUrl,
  }) {
    final web = isWeb ?? kIsWeb;
    if (!web) return AuthRedirectConfig.mobileUrl;

    if (configuredWebUrl.isNotEmpty) return configuredWebUrl;

    final base = baseUri ?? Uri.base;
    if (base.scheme != 'http' && base.scheme != 'https') return null;
    // `Uri.replace(fragment: '', query: '')` leaves the `?` and `#` delimiters
    // behind, so build the URL from its components instead.
    final port = base.hasPort ? ':${base.port}' : '';
    return '${base.scheme}://${base.host}$port'
        '${base.path.isEmpty ? '/' : base.path}';
  }
}

/// A failure reported back by Supabase via the redirect URL, e.g.
/// `/?error=access_denied&error_code=otp_expired&error_description=...`.
///
/// Without this the app lands on a blank page with no explanation, which is
/// exactly what a user sees after clicking an expired or already-used reset
/// link.
class AuthRedirectFailure {
  const AuthRedirectFailure({required this.code, required this.message});

  final String code;
  final String message;

  /// Reads `error`/`error_code`/`error_description` from the query or fragment
  /// of [uri]. Returns `null` when the URL carries no auth error.
  static AuthRedirectFailure? parse(Uri uri) {
    final params = <String, String>{
      ...uri.queryParameters,
      ..._fragmentParams(uri.fragment),
    };

    final errorCode = params['error_code'];
    final error = params['error'];
    if ((errorCode == null || errorCode.isEmpty) &&
        (error == null || error.isEmpty)) {
      return null;
    }

    // Both `Uri.queryParameters` and `Uri.splitQueryString` decode already,
    // so the description is used as-is to avoid double decoding.
    final description = params['error_description'] ?? '';

    return AuthRedirectFailure(
      code: errorCode ?? error!,
      message: switch (errorCode) {
        'otp_expired' =>
          'That reset link has expired or was already used. Request a new one '
              'below.',
        'access_denied' =>
          'That reset link is no longer valid. Request a new one below.',
        _ => description.isNotEmpty
            ? description
            : 'The reset link could not be verified. Request a new one below.',
      },
    );
  }

  /// `#error=...&error_code=...` — Supabase mirrors the error in both places.
  static Map<String, String> _fragmentParams(String fragment) {
    if (fragment.isEmpty) return const {};
    try {
      return Uri.splitQueryString(fragment);
    } catch (_) {
      return const {};
    }
  }
}
