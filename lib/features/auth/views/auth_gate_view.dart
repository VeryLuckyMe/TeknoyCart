import 'dart:async';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/core/theme.dart';
import 'package:http/http.dart' as http;

/// Authentication gate view upgraded to a premium, world-class mobile visual standard.
class AuthGateView extends ConsumerStatefulWidget {
  const AuthGateView({super.key});

  @override
  ConsumerState<AuthGateView> createState() => _AuthGateViewState();
}

class _AuthGateViewState extends ConsumerState<AuthGateView>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _departmentController = TextEditingController(text: 'CCS');

  String _selectedRole = 'BUYER';
  bool _isLoginTab = true;
  bool _obscurePassword = true;
  int _registerStep = 0; // 0: Identity & Role, 1: Academic Verification, 2: Account Credentials

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _studentIdController.dispose();
    _departmentController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    if (step == 0) {
      if (_firstNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your first name'),
            backgroundColor: TeknoyTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      if (_lastNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your last name'),
            backgroundColor: TeknoyTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      return true;
    } else if (step == 1) {
      final studentId = _studentIdController.text.trim();
      final studentIdRegex = RegExp(r'^\d{2}-\d{4}-\d{3}$');
      if (!studentIdRegex.hasMatch(studentId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student ID must be formatted as ##-####-###'),
            backgroundColor: TeknoyTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      if (_departmentController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter your Department Code (e.g. CCS)'),
            backgroundColor: TeknoyTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return false;
      }
      return true;
    }
    return true;
  }

  void _submitForm() async {
    if (!_isLoginTab) {
      if (!_validateStep(0) || !_validateStep(1)) return;
    }
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName';
    final studentId = _studentIdController.text.trim();
    final authNotifier = ref.read(authNotifierProvider.notifier);
    if (_isLoginTab) {
      authNotifier.login(email: email, password: password);
    } else {
      try {
        await authNotifier.register(
          email: email,
          username: fullName,
          password: password,
          role: _selectedRole,
          studentId: studentId,
          department: _departmentController.text.trim().toUpperCase(),
        );
        if (mounted) {
          // Clear inputs on successful signup
          _emailController.clear();
          _passwordController.clear();
          _firstNameController.clear();
          _lastNameController.clear();
          _studentIdController.clear();

          _switchTab(true);

          // Use addPostFrameCallback to ensure the dialog appears AFTER
          // the widget tree settles from the _switchTab setState rebuild.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showRegistrationSuccessDialog(email, fullName);
          });
        }
      } catch (_) {
        // Handled by ref.listen
      }
    }
  }

  /// Premium dialog shown after successful registration, prompting the user
  /// to check their Outlook inbox for the verification link.
  /// Features a live countdown timer showing remaining time before link expiry.
  void _showRegistrationSuccessDialog(String email, String fullName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _VerificationCountdownDialog(
        email: email,
        fullName: fullName,
        parentContext: context,
        parentMounted: () => mounted,
      ),
    );
  }

  void _showUnverifiedEmailDialog(String email, String fullName) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _VerificationCountdownDialog(
        email: email,
        fullName: fullName,
        parentContext: context,
        parentMounted: () => mounted,
        isUnverifiedLogin: true,
      ),
    );
  }

  void _switchTab(bool toLogin) {
    if (_isLoginTab == toLogin) return;
    _fadeCtrl.reset();
    setState(() {
      _isLoginTab = toLogin;
      _registerStep = 0;
    });
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Define adaptive colors
    final scaffoldBg = isDark ? const Color(0xFF0F0A0A) : const Color(0xFFF6F6F9);
    final cardBg = isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.9);
    final cardBorder = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFECECEF);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white.withOpacity(0.5) : Colors.black54;

    ref.listen<AsyncValue>(authNotifierProvider, (_, state) {
      state.whenOrNull(
        error: (err, _) {
          final errorStr = err.toString();
          if (errorStr.contains('EMAIL_UNVERIFIED_PENDING:')) {
            final dataStr = errorStr.replaceFirst('EMAIL_UNVERIFIED_PENDING:', '').trim();
            final parts = dataStr.split('|');
            final email = parts[0];
            final fullName = parts.length > 1 ? parts[1] : 'Student';

            // Show the popup dialog with the Resend option
            _showUnverifiedEmailDialog(email, fullName);
            return;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorStr.replaceAll('Exception: ', '').replaceAll('EMAIL_UNVERIFIED_PENDING:', ''),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: TeknoyTheme.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
          );
        },
      );
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Premium Ambient Background Gradient ────────────────────────
          Container(
            decoration: BoxDecoration(
              color: scaffoldBg,
            ),
          ),
          // Blur circle 1 (Maroon)
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TeknoyTheme.citMaroon.withOpacity(isDark ? 0.35 : 0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          // Blur circle 2 (Gold Accent)
          Positioned(
            bottom: 50,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TeknoyTheme.citGold.withOpacity(isDark ? 0.20 : 0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // ── Main Content Scrollable View ────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // Elegant Premium Logo Badge
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: TeknoyTheme.citGold.withOpacity(0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              TeknoyTheme.citMaroon,
                              TeknoyTheme.citMaroonDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: TeknoyTheme.citMaroon.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.shopping_basket_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Teknoy',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: titleColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Text(
                          'Cart',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: TeknoyTheme.citGold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CIT-U STUDENT MARKETPLACE',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: subtitleColor,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Glassmorphic Form Card ─────────────────────────────────
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: cardBorder,
                            width: 1,
                          ),
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                            child: Form(
                              key: _formKey,
                              child: FadeTransition(
                                opacity: _fadeAnim,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _isLoginTab ? 'Welcome Back' : 'Create Account',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _isLoginTab
                                          ? 'Sign in to access student deals.'
                                          : 'Join the premium campus market.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: subtitleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // ── Step Progress Indicator ──
                                    if (!_isLoginTab) ...[
                                      Row(
                                        children: List.generate(3, (index) {
                                          final active = index <= _registerStep;
                                          return Expanded(
                                            child: Container(
                                              height: 4,
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              decoration: BoxDecoration(
                                                color: active
                                                    ? TeknoyTheme.citGold
                                                    : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 24),
                                    ],

                                    // ── LOGIN FORM ──
                                    if (_isLoginTab) ...[
                                      _buildInputField(
                                        controller: _emailController,
                                        label: 'CIT-U Email',
                                        icon: Icons.email_outlined,
                                        keyboardType: TextInputType.emailAddress,
                                        validator: (val) {
                                          if (val == null || val.trim().isEmpty) {
                                            return 'Please enter your email';
                                          }
                                          final email = val.trim().toLowerCase();
                                          if (!email.endsWith('@cit.edu')) {
                                            return 'Only @cit.edu emails are permitted';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      _buildInputField(
                                        controller: _passwordController,
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
                                          onPressed: () =>
                                              setState(() => _obscurePassword = !_obscurePassword),
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
                                          onPressed: () {},
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                            gradient: LinearGradient(
                                              colors: [
                                                TeknoyTheme.citMaroonLight,
                                                TeknoyTheme.citMaroon,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: TeknoyTheme.citMaroon.withOpacity(0.4),
                                                blurRadius: 12,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: ElevatedButton(
                                            key: const Key('auth-submit-btn'),
                                            onPressed: authState.isLoading ? null : _submitForm,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.transparent,
                                              foregroundColor: Colors.white,
                                              shadowColor: Colors.transparent,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: authState.isLoading
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

                                    // ── REGISTER FLOW ──
                                    if (!_isLoginTab) ...[
                                      // Step 0: Identity & Role
                                      if (_registerStep == 0) ...[
                                        _buildInputField(
                                          controller: _firstNameController,
                                          label: 'First Name',
                                          icon: Icons.person_outline_rounded,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInputField(
                                          controller: _lastNameController,
                                          label: 'Last Name',
                                          icon: Icons.person_outline_rounded,
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          'Select Your Campus Role',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildRoleCard(
                                                role: 'BUYER',
                                                title: 'Buyer',
                                                desc: 'Browse & purchase',
                                                icon: Icons.shopping_bag_outlined,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _buildRoleCard(
                                                role: 'SELLER',
                                                title: 'Seller',
                                                desc: 'List & trade products',
                                                icon: Icons.storefront_outlined,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),
                                        SizedBox(
                                          height: 52,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              if (_validateStep(0)) {
                                                setState(() => _registerStep = 1);
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: TeknoyTheme.citMaroon,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                            ),
                                            child: const Text(
                                              'Continue',
                                              style: TextStyle(
                                                fontFamily: 'Outfit',
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],

                                      // Step 1: Academic Verification
                                      if (_registerStep == 1) ...[
                                        _buildInputField(
                                          controller: _studentIdController,
                                          label: 'Student ID (##-####-###)',
                                          icon: Icons.badge_outlined,
                                          keyboardType: TextInputType.phone,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInputField(
                                          controller: _departmentController,
                                          label: 'Department Code (e.g. CCS)',
                                          icon: Icons.school_outlined,
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => setState(() => _registerStep = 0),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: isDark ? Colors.white : Colors.black87,
                                                  side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFDCDCE0)),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                                child: const Text(
                                                  'Back',
                                                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  if (_validateStep(1)) {
                                                    setState(() => _registerStep = 2);
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: TeknoyTheme.citMaroon,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                                child: const Text(
                                                  'Continue',
                                                  style: TextStyle(
                                                    fontFamily: 'Outfit',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],

                                      // Step 2: Account Credentials
                                      if (_registerStep == 2) ...[
                                        _buildInputField(
                                          controller: _emailController,
                                          label: 'CIT-U Email',
                                          icon: Icons.email_outlined,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: (val) {
                                            if (val == null || val.trim().isEmpty) {
                                              return 'Please enter your email';
                                            }
                                            final email = val.trim().toLowerCase();
                                            if (!email.endsWith('@cit.edu')) {
                                              return 'Only @cit.edu emails are permitted';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInputField(
                                          controller: _passwordController,
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
                                            onPressed: () =>
                                                setState(() => _obscurePassword = !_obscurePassword),
                                          ),
                                          validator: (val) {
                                            if (val == null || val.isEmpty) {
                                              return 'Please enter your password';
                                            }
                                            if (val.length < 6) {
                                              return 'Password must be at least 6 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () => setState(() => _registerStep = 1),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: isDark ? Colors.white : Colors.black87,
                                                  side: BorderSide(color: isDark ? Colors.white.withOpacity(0.2) : const Color(0xFFDCDCE0)),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                                child: const Text(
                                                  'Back',
                                                  style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                key: const Key('auth-submit-btn'),
                                                onPressed: authState.isLoading ? null : _submitForm,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: TeknoyTheme.citMaroon,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                                ),
                                                child: authState.isLoading
                                                    ? const SizedBox(
                                                        height: 20,
                                                        width: 20,
                                                        child: CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                      )
                                                    : const Text(
                                                        'Submit',
                                                        style: TextStyle(
                                                          fontFamily: 'Outfit',
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    // ── Sign up / Sign in link below card ─────────────────────
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLoginTab
                              ? "Don't have an account? "
                              : 'Already have an account? ',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: isDark ? Colors.white.withOpacity(0.7) : Colors.black54,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _switchTab(!_isLoginTab),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              _isLoginTab ? 'Sign up' : 'Sign in',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: TeknoyTheme.citGold,
                                decoration: TextDecoration.underline,
                                decorationColor: TeknoyTheme.citGold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? TeknoyTheme.citMaroon.withOpacity(0.12)
              : (isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF4F4F6)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? TeknoyTheme.citGold
                : (isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E5E9)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? TeknoyTheme.citGold : (isDark ? Colors.white60 : Colors.black45),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
        ),
        prefixIcon: Icon(icon, color: isDark ? Colors.white60 : Colors.black45, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.03) : const Color(0xFFF4F4F6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E5E9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TeknoyTheme.citGold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TeknoyTheme.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: TeknoyTheme.error, width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          color: TeknoyTheme.error,
        ),
      ),
      validator: validator,
    );
  }
}

/// Self-contained StatefulWidget dialog with a live countdown timer.
/// Used for both post-registration and unverified-login email verification prompts.
class _VerificationCountdownDialog extends StatefulWidget {
  final String email;
  final String fullName;
  final BuildContext parentContext;
  final bool Function() parentMounted;
  final bool isUnverifiedLogin;

  const _VerificationCountdownDialog({
    required this.email,
    required this.fullName,
    required this.parentContext,
    required this.parentMounted,
    this.isUnverifiedLogin = false,
  });

  @override
  State<_VerificationCountdownDialog> createState() => _VerificationCountdownDialogState();
}

class _VerificationCountdownDialogState extends State<_VerificationCountdownDialog> {
  late int _secondsRemaining;
  Timer? _timer;
  Timer? _pollTimer;
  bool _isResending = false;
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = 5 * 60; // 5 minutes
    _startTimer();
    _startPolling();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 0 || _isVerified) {
        timer.cancel();
        return;
      }
      setState(() {
        _secondsRemaining--;
      });
    });
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      debugPrint('Polling verification status for ${widget.email}...');
      if (_secondsRemaining <= 0 || _isVerified || !mounted) {
        timer.cancel();
        return;
      }
      try {
        final url = Uri.parse('https://teknoycart-backend.onrender.com/api/auth/check-verification')
            .replace(queryParameters: {'email': widget.email});
        final response = await http.get(url);
        debugPrint('Poll response status: ${response.statusCode}, body: ${response.body}');
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['verified'] == true) {
            debugPrint('Email verified! Transitioning to success layout.');
            timer.cancel();
            _timer?.cancel();
            setState(() {
              _isVerified = true;
            });
          }
        }
      } catch (e) {
        debugPrint('Poll background error: $e');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final min = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final sec = (_secondsRemaining % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Color get _timerColor {
    if (_secondsRemaining <= 0) return TeknoyTheme.error;
    if (_secondsRemaining <= 60) return const Color(0xFFE65100); // Orange-red warning
    return TeknoyTheme.citGold;
  }

  String get _timerLabel {
    if (_secondsRemaining <= 0) return 'Verification link has expired!';
    return 'Link expires in';
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      final url = Uri.parse('https://teknoycart-backend.onrender.com/api/auth/send-verification')
          .replace(queryParameters: {
            'email': widget.email,
            'fullName': widget.fullName,
          });
      final response = await http.post(url);
      if (response.statusCode == 200) {
        // Reset countdown to 5 minutes on successful resend
        setState(() {
          _secondsRemaining = 5 * 60;
          _isResending = false;
        });
        _startTimer();
        if (widget.parentMounted()) {
          ScaffoldMessenger.of(widget.parentContext).showSnackBar(
            const SnackBar(
              content: Text('New verification email sent! Check your Outlook inbox.'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        throw Exception('Server returned status ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isResending = false);
      if (widget.parentMounted()) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text('Failed to resend: $e'),
            backgroundColor: TeknoyTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isVerified) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Verification Successful!',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.5,
                  color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
                ),
                children: [
                  const TextSpan(text: 'Excellent, '),
                  TextSpan(
                    text: widget.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '! Your account ('),
                  TextSpan(
                    text: widget.email,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon),
                  ),
                  const TextSpan(text: ') has been fully verified. You are now ready to log in and start shopping!'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.stars_rounded,
                  color: TeknoyTheme.citGold,
                  size: 64,
                ),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TeknoyTheme.citMaroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Go to Login',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      );
    }

    final isExpired = _secondsRemaining <= 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      title: Row(
        children: [
          Icon(
            widget.isUnverifiedLogin
                ? Icons.warning_amber_rounded
                : Icons.mark_email_unread_rounded,
            color: TeknoyTheme.citGold,
            size: 28,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.isUnverifiedLogin ? 'Verify Email First' : 'Verify Your Email',
              style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                height: 1.5,
                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87,
              ),
              children: widget.isUnverifiedLogin
                  ? [
                      TextSpan(text: 'Hello ${widget.fullName}, your account email ('),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon),
                      ),
                      const TextSpan(text: ') is not verified yet. Check your Outlook inbox for the activation link.'),
                    ]
                  : [
                      const TextSpan(text: 'Account created! A verification link was sent to '),
                      TextSpan(
                        text: widget.email,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: TeknoyTheme.citMaroon),
                      ),
                      const TextSpan(text: '. Check your '),
                      const TextSpan(
                        text: 'Outlook inbox',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' and click the verification button to activate your account.'),
                    ],
            ),
          ),
          const SizedBox(height: 16),
          // ── Live Countdown Timer Banner ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _timerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _timerColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
                  color: _timerColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _timerLabel,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _timerColor,
                    ),
                  ),
                ),
                // Countdown digits badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _timerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formattedTime,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _timerColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Spam / Junk Reminder ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: TeknoyTheme.citMaroon.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TeknoyTheme.citMaroon.withValues(alpha: 0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: TeknoyTheme.citMaroon, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Check junk/spam folder if you don\'t see the email.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: TeknoyTheme.citMaroon,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            widget.isUnverifiedLogin ? 'Cancel' : 'Got it',
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: TeknoyTheme.citMaroon,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: _isResending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_rounded, size: 18),
          label: Text(
            _isResending ? 'Sending...' : 'Resend Email',
            style: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          ),
          onPressed: _isResending ? null : _resendEmail,
        ),
      ],
    );
  }
}
