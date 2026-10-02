import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/teknoy_cart_logo.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import 'widgets/email_verification_dialog.dart';
import 'widgets/auth_password_sheets.dart';
import 'widgets/auth_login_form.dart';
import 'widgets/auth_register_form.dart';

class AuthGateView extends ConsumerStatefulWidget {
  const AuthGateView({super.key});

  @override
  ConsumerState<AuthGateView> createState() => _AuthGateViewState();
}

class _AuthGateViewState extends ConsumerState<AuthGateView> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  bool _isLoginTab = true;
  int _registerStep = 0;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _departmentController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _orgContactController = TextEditingController();

  String _selectedRole = 'BUYER';
  String _selectedSellerType = 'STUDENT';

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    // Listen for password recovery events (when user clicks reset password link in email)
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showSetNewPasswordSheet();
          }
        });
      }
    });

    // Check if web URL contains recovery fragment/query
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = Uri.base;
      if (uri.fragment.contains('type=recovery') || uri.queryParameters['type'] == 'recovery') {
        if (mounted) {
          _showSetNewPasswordSheet();
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _fadeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _studentIdController.dispose();
    _departmentController.dispose();
    _storeNameController.dispose();
    _orgContactController.dispose();
    super.dispose();
  }

  void _switchTab(bool isLogin) {
    if (_isLoginTab == isLogin) return;
    _fadeController.reverse().then((_) {
      setState(() {
        _isLoginTab = isLogin;
        _registerStep = 0;
        _confirmPasswordController.clear();
        _formKey.currentState?.reset();
      });
      _fadeController.forward();
    });
  }

  bool _validateStep(int step) {
    if (step == 0) {
      final isOrg = _selectedRole == 'SELLER' && _selectedSellerType == 'ORG';
      if (!isOrg) {
        if (_firstNameController.text.trim().isEmpty) {
          _showErrorSnackBar('Please enter your first name');
          return false;
        }
        if (_lastNameController.text.trim().isEmpty) {
          _showErrorSnackBar('Please enter your last name');
          return false;
        }
      }
      if (_selectedRole == 'SELLER' && _storeNameController.text.trim().isEmpty) {
        _showErrorSnackBar('Please enter a store name');
        return false;
      }
      return true;
    }

    if (step == 1) {
      if (_selectedRole == 'SELLER' && _selectedSellerType == 'ORG') {
        if (_orgContactController.text.trim().isEmpty) {
          _showErrorSnackBar('Please enter a contact number for your store/organization');
          return false;
        }
        if (_departmentController.text.trim().isEmpty) {
          _showErrorSnackBar('Please select your college/department affiliation');
          return false;
        }
      } else {
        final idTrimmed = _studentIdController.text.trim();
        if (idTrimmed.isEmpty) {
          _showErrorSnackBar('Please enter your Student ID');
          return false;
        }
        final studentIdRegex = RegExp(r'^\d{2}-\d{4}-\d{3}$');
        if (!studentIdRegex.hasMatch(idTrimmed)) {
          _showErrorSnackBar('Student ID must follow ##-####-### format (e.g. 21-1234-567)');
          return false;
        }
        if (_departmentController.text.trim().isEmpty) {
          _showErrorSnackBar('Please select your department or school');
          return false;
        }
      }
      return true;
    }

    return true;
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: TeknoyTheme.citMaroon,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (_isLoginTab) {
      if (!_formKey.currentState!.validate()) return;
      try {
        await ref.read(authNotifierProvider.notifier).login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      } catch (e) {
        if (mounted) {
          // Catch unverified email specifically and open the friendly verification modal immediately
          if (e is UnverifiedEmailException) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => EmailVerificationDialog(
                email: e.email,
                fullName: e.fullName,
              ),
            );
            return;
          }
          String msg = e.toString();
          if (msg.contains('EMAIL_UNVERIFIED_PENDING:')) {
            final parts = msg.replaceAll('EMAIL_UNVERIFIED_PENDING:', '').trim().split('|');
            final email = parts.isNotEmpty ? parts[0] : _emailController.text.trim();
            final fullName = parts.length > 1 ? parts[1] : 'Student';
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => EmailVerificationDialog(
                email: email,
                fullName: fullName,
              ),
            );
            return;
          }
          if (msg.contains('invalid_credentials') ||
              msg.contains('Invalid login credentials') ||
              msg.contains('400')) {
            msg = 'No account found matching these credentials. Please check your email and password, or sign up.';
          } else {
            msg = msg
                .replaceAll('AuthException: ', '')
                .replaceAll('FormatException: ', '')
                .replaceAll('Exception: ', '')
                .trim();
          }
          _showErrorSnackBar(msg);
        }
      }
    } else {
      if (!_validateStep(0) || !_validateStep(1)) return;
      if (!_formKey.currentState!.validate()) return;

      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorSnackBar('Passwords do not match. Please re-enter your password.');
        return;
      }

      try {
        final isOrg = _selectedRole == 'SELLER' && _selectedSellerType == 'ORG';
        final fullName = isOrg
            ? _storeNameController.text.trim()
            : '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
        await ref.read(authNotifierProvider.notifier).register(
              email: _emailController.text.trim(),
              username: fullName,
              password: _passwordController.text,
              role: _selectedRole,
              sellerType: _selectedRole == 'SELLER' ? _selectedSellerType : null,
              studentId: (_selectedRole == 'SELLER' && _selectedSellerType == 'ORG')
                  ? ''
                  : _studentIdController.text.trim(),
              department: _departmentController.text.trim(),
              storeName: _selectedRole == 'SELLER' ? _storeNameController.text.trim() : null,
              orgContact: (_selectedRole == 'SELLER' && _selectedSellerType == 'ORG')
                  ? _orgContactController.text.trim()
                  : null,
            );

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => EmailVerificationDialog(
              email: _emailController.text.trim(),
              fullName: fullName,
            ),
          );
          _switchTab(true); // go to login after dialog is dismissed
        }
      } catch (e) {
        if (mounted) _showErrorSnackBar(e.toString());
      }
    }
  }

  void _showForgotPasswordSheet() {
    AuthPasswordSheets.showForgotPasswordSheet(
      context: context,
      initialEmail: _emailController.text,
      onError: (msg) {
        if (mounted) _showErrorSnackBar(msg);
      },
    );
  }

  void _showSetNewPasswordSheet() {
    AuthPasswordSheets.showSetNewPasswordSheet(
      context: context,
      onPasswordUpdated: () {
        if (mounted) _switchTab(true);
      },
      onError: (msg) {
        if (mounted) _showErrorSnackBar(msg);
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleColor = isDark ? Colors.white : const Color(0xFF1D1D1F);
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF8E8E93);
    final cardBg = isDark ? const Color(0xFF1C1C1E).withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.85);
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE5E5EA);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient & Glow Spheres
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF0D0D0F) : const Color(0xFFF2F2F7),
            ),
          ),
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.3 : 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TeknoyTheme.citGold.withValues(alpha: isDark ? 0.2 : 0.12),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header Logo & Branding
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TeknoyTheme.citMaroon.withValues(alpha: 0.08),
                      ),
                      child: const TeknoyCartLogo(
                        size: 44,
                        color: TeknoyTheme.citMaroon,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'TEKNOYCART',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: TeknoyTheme.citMaroon,
                        letterSpacing: 2.0,
                      ),
                    ),
                    Text(
                      'CIT-U EXCLUSIVE CAMPUS MARKETPLACE',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: subtitleColor,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Glassmorphic Form Card
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


                                    if (_isLoginTab)
                                      AuthLoginForm(
                                        emailController: _emailController,
                                        passwordController: _passwordController,
                                        onForgotPassword: _showForgotPasswordSheet,
                                        onSubmit: _submitForm,
                                        isLoading: authState.isLoading,
                                      )
                                    else
                                      AuthRegisterForm(
                                        firstNameController: _firstNameController,
                                        lastNameController: _lastNameController,
                                        studentIdController: _studentIdController,
                                        departmentController: _departmentController,
                                        storeNameController: _storeNameController,
                                        orgContactController: _orgContactController,
                                        emailController: _emailController,
                                        passwordController: _passwordController,
                                        confirmPasswordController: _confirmPasswordController,
                                        selectedRole: _selectedRole,
                                        selectedSellerType: _selectedSellerType,
                                        onRoleChanged: (role) => setState(() => _selectedRole = role),
                                        onSellerTypeChanged: (type) => setState(() => _selectedSellerType = type),
                                        registerStep: _registerStep,
                                        onStepChanged: (step) => setState(() => _registerStep = step),
                                        onValidateStep: _validateStep,
                                        onSubmit: _submitForm,
                                        isLoading: authState.isLoading,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Sign up / Sign in link below card
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
                            color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54,
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
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: TeknoyTheme.citMaroon,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
