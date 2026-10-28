import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme.dart';
import '../../services/auth_service.dart';

class AuthPasswordSheets {
  /// Verifies a recovery input (either a redirected URL containing ?code=...,
  /// a raw Supabase verify link from the email, or a 6-digit recovery OTP code).
  static Future<void> verifyRecoveryInput({
    required String email,
    required String rawInput,
  }) async {
    final input = rawInput.trim();
    if (input.isEmpty) {
      throw Exception('Please enter your recovery code or paste the link.');
    }

    final auth = Supabase.instance.client.auth;

    // Case 1: User pasted a full URL
    if (input.startsWith('http://') ||
        input.startsWith('https://') ||
        input.startsWith('teknoycart://')) {
      final uri = Uri.parse(input);

      // 1a. URL containing ?code=... (PKCE) or #access_token=... (Implicit)
      if (uri.queryParameters.containsKey('code') ||
          uri.fragment.contains('access_token=') ||
          uri.fragment.contains('error=')) {
        await auth.getSessionFromUrl(uri);
        return;
      }

      // 1b. Raw email verification link: /auth/v1/verify?token=...&type=recovery
      final tokenParam =
          uri.queryParameters['token_hash'] ?? uri.queryParameters['token'];
      if (tokenParam != null && tokenParam.isNotEmpty) {
        try {
          await auth.verifyOTP(
            tokenHash: tokenParam,
            type: OtpType.recovery,
          );
          return;
        } catch (_) {
          // Resolve any 302/303 redirect in-place to exchange the challenge token cleanly
          final client = http.Client();
          try {
            final req = http.Request('GET', uri)..followRedirects = false;
            final streamed =
                await client.send(req).timeout(const Duration(seconds: 12));
            final location = streamed.headers['location'];
            if (location != null && location.isNotEmpty) {
              await auth.getSessionFromUrl(Uri.parse(location));
              return;
            }
          } finally {
            client.close();
          }
          rethrow;
        }
      }

      // Fallback callback exchange
      await auth.getSessionFromUrl(uri);
      return;
    }

    // Case 2: Code parameter snippet
    if (input.contains('code=')) {
      final normalized = input.startsWith('?')
          ? 'https://app.teknoycart.local/$input'
          : 'https://app.teknoycart.local/?$input';
      await auth.getSessionFromUrl(Uri.parse(normalized));
      return;
    }

    // Case 3: 6-digit OTP code or raw token hash
    try {
      if (email.trim().isNotEmpty) {
        await auth.verifyOTP(
          email: email.trim(),
          token: input,
          type: OtpType.recovery,
        );
        return;
      }
    } catch (_) {
      if (input.length <= 8) rethrow;
    }

    await auth.verifyOTP(
      tokenHash: input,
      type: OtpType.recovery,
    );
  }

  static void showForgotPasswordSheet({
    required BuildContext context,
    required String initialEmail,
    required void Function(String message) onError,
    VoidCallback? onPasswordRecoveryVerified,
  }) {
    final forgotEmailCtrl = TextEditingController(text: initialEmail);
    final recoveryInputCtrl = TextEditingController();
    bool isSending = false;
    bool isVerifying = false;
    bool isStepTwo = false;
    bool showManualInput = false;
    String? inlineError;
    StreamSubscription<AuthState>? authSub;

    void triggerSetNewPassword(BuildContext sheetCtx) {
      authSub?.cancel();
      AuthService.passwordRecoveryPending = false;
      if (Navigator.of(sheetCtx).canPop()) {
        Navigator.of(sheetCtx).pop();
      }
      if (onPasswordRecoveryVerified != null) {
        onPasswordRecoveryVerified();
      } else if (context.mounted) {
        showSetNewPasswordSheet(
          context: context,
          onPasswordUpdated: () {},
          onError: onError,
        );
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            // Auto-detect when the user clicks the email link on their phone
            authSub ??=
                Supabase.instance.client.auth.onAuthStateChange.listen((data) {
              if (data.event == AuthChangeEvent.passwordRecovery) {
                if (modalCtx.mounted) {
                  triggerSetNewPassword(modalCtx);
                }
              }
            });

            final isDark = Theme.of(modalCtx).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(
                            isStepTwo
                                ? Icons.mark_email_read_rounded
                                : Icons.lock_reset_rounded,
                            color: TeknoyTheme.citMaroon,
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isStepTwo ? 'Check Your Email' : 'Reset Password',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!isStepTwo) ...[
                        Text(
                          'Enter your institutional email address to receive password reset instructions.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: forgotEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Institutional Email Address',
                            hintText: 'student@cit.edu',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                        if (inlineError != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            inlineError!,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: Colors.redAccent,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: isSending
                              ? null
                              : () async {
                                  final email = forgotEmailCtrl.text.trim();
                                  if (email.isEmpty) {
                                    setModalState(() {
                                      inlineError =
                                          'Please enter your email address.';
                                    });
                                    return;
                                  }
                                  setModalState(() {
                                    isSending = true;
                                    inlineError = null;
                                  });
                                  try {
                                    await Supabase.instance.client.auth
                                        .resetPasswordForEmail(
                                      email,
                                      redirectTo: kIsWeb
                                          ? null
                                          : 'teknoycart://login-callback',
                                    );
                                    if (modalCtx.mounted) {
                                      setModalState(() {
                                        isSending = false;
                                        isStepTwo = true;
                                      });
                                    }
                                  } catch (e) {
                                    if (modalCtx.mounted) {
                                      setModalState(() {
                                        isSending = false;
                                        inlineError = e
                                            .toString()
                                            .replaceAll('AuthException: ', '')
                                            .replaceAll('Exception: ', '');
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TeknoyTheme.citMaroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Send Reset Link',
                                  style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              inlineError = null;
                              isStepTwo = true;
                              showManualInput = true;
                            });
                          },
                          child: Text(
                            'Already have a reset code? Enter it here',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? TeknoyTheme.citGold
                                  : TeknoyTheme.citMaroon,
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: Colors.green, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Reset Link Sent!',
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'We sent reset instructions to ${forgotEmailCtrl.text.trim()}.\n\nPlease open your email on this phone and tap the reset link to proceed.',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12.5,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black87,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!showManualInput) ...[
                          OutlinedButton.icon(
                            onPressed: () {
                              setModalState(() => showManualInput = true);
                            },
                            icon: const Icon(Icons.pin_outlined, size: 18),
                            label: const Text(
                              'Enter code or link manually',
                              style: TextStyle(fontFamily: 'Outfit'),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white70
                                  : TeknoyTheme.citMaroon,
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white24
                                    : TeknoyTheme.citMaroon
                                        .withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ] else ...[
                          Text(
                            'If you received a 6-digit code or copied the reset link, paste it below:',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: recoveryInputCtrl,
                            decoration: InputDecoration(
                              labelText: 'Reset Code or Link',
                              hintText: 'e.g. 123456 or paste link',
                              prefixIcon: const Icon(Icons.link_rounded),
                              suffixIcon: IconButton(
                                tooltip: 'Paste from clipboard',
                                icon: const Icon(Icons.content_paste_rounded),
                                onPressed: () async {
                                  final data = await Clipboard.getData(
                                      Clipboard.kTextPlain);
                                  if (data?.text != null &&
                                      data!.text!.trim().isNotEmpty) {
                                    recoveryInputCtrl.text = data.text!.trim();
                                    setModalState(() => inlineError = null);
                                  }
                                },
                              ),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          if (inlineError != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              inlineError!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: isVerifying
                                ? null
                                : () async {
                                    setModalState(() {
                                      isVerifying = true;
                                      inlineError = null;
                                    });
                                    try {
                                      await verifyRecoveryInput(
                                        email: forgotEmailCtrl.text.trim(),
                                        rawInput: recoveryInputCtrl.text,
                                      );
                                      if (modalCtx.mounted) {
                                        triggerSetNewPassword(modalCtx);
                                      }
                                    } catch (e) {
                                      if (modalCtx.mounted) {
                                        setModalState(() {
                                          isVerifying = false;
                                          inlineError = e
                                              .toString()
                                              .replaceAll(
                                                  'AuthException: ', '')
                                              .replaceAll('Exception: ', '');
                                        });
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TeknoyTheme.citMaroon,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: isVerifying
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Verify & Set Password',
                                    style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () {
                            if (Navigator.of(modalCtx).canPop()) {
                              Navigator.of(modalCtx).pop();
                            }
                          },
                          child: Text(
                            'Close',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      authSub?.cancel();
    });
  }

  static void showSetNewPasswordSheet({
    required BuildContext context,
    required VoidCallback onPasswordUpdated,
    required void Function(String message) onError,
  }) {
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isUpdating = false;
    String? inlineError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final isDark = Theme.of(modalCtx).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(modalCtx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Icon(Icons.lock_reset_rounded,
                              color: TeknoyTheme.citMaroon, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Set New Password',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your new password below (minimum 12 characters).',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: newPasswordCtrl,
                        obscureText: obscureNew,
                        onChanged: (_) {
                          if (inlineError != null) {
                            setModalState(() => inlineError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'New Password (12+ characters)',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip:
                                obscureNew ? 'Show password' : 'Hide password',
                            icon: Icon(obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () =>
                                setModalState(() => obscureNew = !obscureNew),
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: confirmPasswordCtrl,
                        obscureText: obscureConfirm,
                        onChanged: (_) {
                          if (inlineError != null) {
                            setModalState(() => inlineError = null);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: obscureConfirm
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setModalState(
                                () => obscureConfirm = !obscureConfirm),
                          ),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                      if (inlineError != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  inlineError!,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12.5,
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: isUpdating
                            ? null
                            : () async {
                                final pass = newPasswordCtrl.text;
                                final confirm = confirmPasswordCtrl.text;
                                if (pass.length < 12) {
                                  setModalState(() {
                                    inlineError =
                                        'Password must be at least 12 characters long (currently ${pass.length}).';
                                  });
                                  return;
                                }
                                if (pass != confirm) {
                                  setModalState(() {
                                    inlineError =
                                        'Passwords do not match. Please check both fields.';
                                  });
                                  return;
                                }

                                setModalState(() {
                                  isUpdating = true;
                                  inlineError = null;
                                });

                                try {
                                  await Supabase.instance.client.auth
                                      .updateUser(
                                    UserAttributes(password: pass),
                                  );
                                  await Supabase.instance.client.auth.signOut();
                                  if (modalCtx.mounted &&
                                      Navigator.of(modalCtx).canPop()) {
                                    Navigator.of(modalCtx).pop();
                                  }
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Password updated successfully! Please log in with your new password.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    onPasswordUpdated();
                                  }
                                } catch (e) {
                                  final errText = e
                                      .toString()
                                      .replaceAll('AuthException: ', '')
                                      .replaceAll('Exception: ', '');
                                  if (modalCtx.mounted) {
                                    setModalState(() {
                                      isUpdating = false;
                                      inlineError = errText;
                                    });
                                  } else {
                                    onError(errText);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TeknoyTheme.citMaroon,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Update Password',
                                style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: isUpdating
                            ? null
                            : () async {
                                try {
                                  await Supabase.instance.client.auth.signOut();
                                } catch (_) {}
                                if (modalCtx.mounted &&
                                    Navigator.of(modalCtx).canPop()) {
                                  Navigator.of(modalCtx).pop();
                                }
                              },
                        child: Text(
                          'Cancel & Return to Sign In',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
