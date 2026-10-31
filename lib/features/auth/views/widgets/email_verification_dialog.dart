import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Email Verification Dialog with countdown timer
// ---------------------------------------------------------------------------
class EmailVerificationDialog extends StatefulWidget {
  final String email;
  final String? fullName;

  /// When set, the initial verification email was never delivered. The dialog
  /// shows the reason and allows an immediate retry instead of a fake timer.
  final String? initialDeliveryError;

  const EmailVerificationDialog({
    super.key,
    required this.email,
    this.fullName,
    this.initialDeliveryError,
  });

  @override
  State<EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<EmailVerificationDialog> {
  static const int _totalSeconds = 900; // Backend verification links expire after 15 minutes.
  static const int _resendCooldownSeconds = 60;
  int _secondsLeft = _totalSeconds;
  int _resendSecondsLeft = _resendCooldownSeconds;
  bool _expired = false;
  bool _resending = false;
  bool _resent = false;
  bool _deliveryFailed = false;
  Timer? _timer;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _deliveryFailed = widget.initialDeliveryError != null;
    if (_deliveryFailed) {
      // The initial email was never sent, so a countdown would be misleading.
      _resendSecondsLeft = 0;
    } else {
      _startTimer();
      _startResendCooldown();
    }
  }

  void _startResendCooldown() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_resendSecondsLeft > 0) {
          _resendSecondsLeft--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          _expired = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _resendEmail() async {
    setState(() { _resending = true; _resent = false; });
    try {
      final authService = AuthService();
      await authService.resendVerificationEmail(
        widget.email,
        widget.fullName ?? 'Student',
      );

      if (mounted) {
        setState(() {
          _resending = false;
          _resent = true;
          _deliveryFailed = false;
          _expired = false;
          _secondsLeft = _totalSeconds;
          _resendSecondsLeft = _resendCooldownSeconds;
        });
        _startTimer();
        _startResendCooldown();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _resending = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend: ${e.toString()}',
                style: const TextStyle(fontFamily: 'Inter')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Progress 1.0 → 0.0 as time runs out
  double get _progress => _secondsLeft / _totalSeconds;

  Color get _timerColor {
    if (_secondsLeft > 120) return TeknoyTheme.successDark;
    if (_secondsLeft > 60) return const Color(0xFFF57F17);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _deliveryFailed
        ? const Color(0xFFE65100)
        : (_expired ? const Color(0xFFC62828) : TeknoyTheme.successDark);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _expired
                    ? Icons.timer_off_rounded
                    : Icons.mark_email_unread_rounded,
                size: 42,
                color: accent,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              _deliveryFailed
                  ? 'Email Not Sent'
                  : (_expired ? 'Link Expired' : 'Verify Your Email'),
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _deliveryFailed || _expired
                    ? accent
                    : (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              _deliveryFailed
                  ? 'Your account was created, but the verification link could not be sent to:'
                  : _expired
                      ? 'The verification link has expired. Tap below to resend a new one.'
                      : 'A verification link has been sent to:',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Email pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: TeknoyTheme.citMaroon.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TeknoyTheme.citMaroon.withValues(alpha: 0.25)),
              ),
              child: Text(
                widget.email,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: TeknoyTheme.citMaroon,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Delivery failure reason
            if (_deliveryFailed) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 16, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.initialDeliveryError ??
                            'The verification email could not be sent.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Countdown or expired indicator
            if (!_expired && !_deliveryFailed) ...[
              // Circular progress + time
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 5,
                      backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
                    ),
                  ),
                  Text(
                    _formattedTime,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _timerColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Link expires in',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please check your inbox and spam folder.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // Resent success message
            if (_resent)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: TeknoyTheme.successDark),
                    const SizedBox(width: 6),
                    Text(
                      'New verification email sent!',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Resend button (allows instant resend or when expired)
            SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _resending || _resendSecondsLeft > 0 ? null : _resendEmail,
                  icon: _resending
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _resending
                        ? 'Sending...'
                        : _resendSecondsLeft > 0
                            ? 'Resend in ${_resendSecondsLeft}s'
                            : 'Resend Verification Email',
                    style: const TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeknoyTheme.citMaroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),

            // Close button
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'I verified — return to sign in',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
