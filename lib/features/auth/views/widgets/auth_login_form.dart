import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import 'auth_form_fields.dart';

/// Modular Login Form Widget extracted from AuthGateView (HIGH-05).
class AuthLoginForm extends StatefulWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onForgotPassword;
  final VoidCallback onSubmit;
  final bool isLoading;
  final int? attemptsRemaining;
  final int? lockoutSecondsRemaining;

  const AuthLoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onForgotPassword,
    required this.onSubmit,
    required this.isLoading,
    this.attemptsRemaining,
    this.lockoutSecondsRemaining,
  });

  @override
  State<AuthLoginForm> createState() => _AuthLoginFormState();
}

class _AuthLoginFormState extends State<AuthLoginForm> {
  bool _obscurePassword = true;

  String _formatCooldown(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLocked = widget.lockoutSecondsRemaining != null && widget.lockoutSecondsRemaining! > 0;
    final hasAttemptsWarning = !isLocked && widget.attemptsRemaining != null && widget.attemptsRemaining! < 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthInputField(
          controller: widget.emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          enabled: !isLocked,
          keyboardType: TextInputType.emailAddress,
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter your email';
            }
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(val.trim())) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        AuthInputField(
          controller: widget.passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          enabled: !isLocked,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: isDark ? Colors.white60 : Colors.black54,
              size: 20,
            ),
            onPressed: isLocked ? null : () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) {
              return 'Please enter your password';
            }
            return null;
          },
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: widget.onForgotPassword,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(44, 40),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const Text(
              'Forgot Password?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: TeknoyTheme.citGold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── UI/UX Pro Max: Live Account Lockout Cooldown Card ──
        if (isLocked) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF261810) : const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_clock_rounded,
                        color: Colors.amber.shade800,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Security Lockout Active',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                              color: Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Sign-in is paused for 10 minutes.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatCooldown(widget.lockoutSecondsRemaining!),
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Too many consecutive failed attempts. Please wait for the cooldown timer to expire.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.white60 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: widget.onForgotPassword,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mail_lock_outlined, size: 14, color: Colors.amber.shade800),
                      const SizedBox(width: 5),
                      Text(
                        'Forgot Password? Reset via Outlook',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ] else if (hasAttemptsWarning) ...[
          // ── UI/UX Pro Max: Attempts Warning Pill Banner ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF241014) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.red.shade400.withValues(alpha: 0.4),
                width: 1.1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFDC2626)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.attemptsRemaining} of 5 attempts remaining',
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                    Row(
                      children: List.generate(5, (idx) {
                        final used = idx < (5 - widget.attemptsRemaining!);
                        return Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: used
                                ? const Color(0xFFDC2626)
                                : (isDark ? Colors.white24 : Colors.black12),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'After 5 incorrect attempts, sign-in will be paused for 10 minutes.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Submit Button ──
        SizedBox(
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: isLocked
                  ? null
                  : const LinearGradient(
                      colors: [
                        TeknoyTheme.citMaroonLight,
                        TeknoyTheme.citMaroon,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: isLocked
                  ? (isDark ? Colors.white12 : const Color(0xFFE5E7EB))
                  : null,
              boxShadow: isLocked
                  ? []
                  : [
                      BoxShadow(
                        color: TeknoyTheme.citMaroon.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ElevatedButton(
              key: const Key('auth-submit-btn'),
              onPressed: (widget.isLoading || isLocked) ? null : widget.onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: isLocked ? (isDark ? Colors.white38 : Colors.grey.shade600) : Colors.white,
                disabledBackgroundColor: Colors.transparent,
                disabledForegroundColor: isLocked ? (isDark ? Colors.white38 : Colors.grey.shade600) : Colors.white70,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : (isLocked
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_clock_rounded, size: 18, color: isDark ? Colors.white38 : Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'Locked (${_formatCooldown(widget.lockoutSecondsRemaining!)})',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                                color: isDark ? Colors.white38 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        )),
            ),
          ),
        ),
      ],
    );
  }
}

