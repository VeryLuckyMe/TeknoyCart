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

  const AuthLoginForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onForgotPassword,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  State<AuthLoginForm> createState() => _AuthLoginFormState();
}

class _AuthLoginFormState extends State<AuthLoginForm> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthInputField(
          controller: widget.emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
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
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: isDark ? Colors.white60 : Colors.black54,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [
                  TeknoyTheme.citMaroonLight,
                  TeknoyTheme.citMaroon,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: TeknoyTheme.citMaroon.withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              key: const Key('auth-submit-btn'),
              onPressed: widget.isLoading ? null : widget.onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
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
                  : const Text(
                      'Login',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
