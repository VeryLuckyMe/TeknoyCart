import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import '../providers/auth_provider.dart';
import 'widgets/email_verification_dialog.dart';
import 'widgets/auth_password_sheets.dart';
import 'widgets/auth_form_fields.dart';

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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _departmentController = TextEditingController();
  final _storeNameController = TextEditingController();
  final _orgContactController = TextEditingController();

  String _selectedRole = 'BUYER';
  String _selectedSellerType = 'STUDENT';
  bool _obscurePassword = true;

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
          _showErrorSnackBar('Please enter your college/department affiliation');
          return false;
        }
      } else {
        if (_studentIdController.text.trim().isEmpty) {
          _showErrorSnackBar('Please enter your Student ID');
          return false;
        }
        if (_departmentController.text.trim().isEmpty) {
          _showErrorSnackBar('Please enter your department code');
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
          String msg = e.toString();
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
    final subtitleColor = isDark ? Colors.white.withOpacity(0.6) : const Color(0xFF8E8E93);
    final cardBg = isDark ? const Color(0xFF1C1C1E).withOpacity(0.8) : Colors.white.withOpacity(0.85);
    final cardBorder = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E5EA);

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
                color: TeknoyTheme.citMaroon.withOpacity(isDark ? 0.3 : 0.15),
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
                color: TeknoyTheme.citGold.withOpacity(isDark ? 0.2 : 0.12),
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
                        color: TeknoyTheme.citMaroon.withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        size: 40,
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

                                    // Step Progress Indicator
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

                                    // LOGIN FORM
                                    if (_isLoginTab) ...[
                                      AuthInputField(
                                        controller: _emailController,
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
                                          onPressed: _showForgotPasswordSheet,
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

                                    // REGISTER FLOW
                                    if (!_isLoginTab) ...[
                                      // Step 0: Identity & Role
                                      if (_registerStep == 0) ...[
                                        if (!(_selectedRole == 'SELLER' && _selectedSellerType == 'ORG')) ...[
                                          AuthInputField(
                                            controller: _firstNameController,
                                            label: 'First Name',
                                            icon: Icons.person_outline_rounded,
                                          ),
                                          const SizedBox(height: 16),
                                          AuthInputField(
                                            controller: _lastNameController,
                                            label: 'Last Name',
                                            icon: Icons.person_outline_rounded,
                                          ),
                                          const SizedBox(height: 20),
                                        ],
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
                                              child: RoleCard(
                                                role: 'BUYER',
                                                selectedRole: _selectedRole,
                                                title: 'Buyer',
                                                desc: 'Browse & purchase',
                                                icon: Icons.shopping_bag_outlined,
                                                onSelected: (val) => setState(() => _selectedRole = val),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: RoleCard(
                                                role: 'SELLER',
                                                selectedRole: _selectedRole,
                                                title: 'Seller',
                                                desc: 'List & trade products',
                                                icon: Icons.storefront_outlined,
                                                onSelected: (val) => setState(() => _selectedRole = val),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (_selectedRole == 'SELLER') ...[
                                          const SizedBox(height: 16),
                                          Text(
                                            'Seller Type',
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
                                                child: SellerTypeCard(
                                                  type: 'STUDENT',
                                                  selectedSellerType: _selectedSellerType,
                                                  title: 'Student / Personal',
                                                  desc: 'Individual student seller',
                                                  icon: Icons.school_outlined,
                                                  onSelected: (val) => setState(() => _selectedSellerType = val),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: SellerTypeCard(
                                                  type: 'ORG',
                                                  selectedSellerType: _selectedSellerType,
                                                  title: 'Org / Shop',
                                                  desc: 'Organization or big store',
                                                  icon: Icons.storefront_rounded,
                                                  onSelected: (val) => setState(() => _selectedSellerType = val),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeInOut,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: (_selectedSellerType == 'ORG'
                                                  ? const Color(0xFF1565C0)
                                                  : TeknoyTheme.citGold).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _selectedSellerType == 'ORG'
                                                      ? Icons.info_outline_rounded
                                                      : Icons.badge_outlined,
                                                  size: 14,
                                                  color: _selectedSellerType == 'ORG'
                                                      ? const Color(0xFF1976D2)
                                                      : TeknoyTheme.citGold,
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    _selectedSellerType == 'ORG'
                                                        ? 'Next step: Contact number & college affiliation'
                                                        : 'Next step: Student ID & department code',
                                                    style: TextStyle(
                                                      fontFamily: 'Inter',
                                                      fontSize: 11,
                                                      color: _selectedSellerType == 'ORG'
                                                          ? const Color(0xFF1976D2)
                                                          : TeknoyTheme.citGold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          AuthInputField(
                                            controller: _storeNameController,
                                            label: 'Store Name',
                                            icon: Icons.store_mall_directory_outlined,
                                          ),
                                        ],
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

                                      // Step 1: Academic / Org Verification
                                      if (_registerStep == 1) ...[
                                        if (_selectedRole == 'SELLER' && _selectedSellerType == 'ORG') ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1565C0).withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: const Color(0xFF1976D2).withOpacity(0.3),
                                              ),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.storefront_rounded, size: 18, color: Color(0xFF1976D2)),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Organization / Shop verification',
                                                    style: TextStyle(
                                                      fontFamily: 'Outfit',
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1976D2),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          AuthInputField(
                                            controller: _orgContactController,
                                            label: 'Contact Number (09XX-XXX-XXXX)',
                                            icon: Icons.phone_outlined,
                                            keyboardType: TextInputType.phone,
                                          ),
                                          const SizedBox(height: 16),
                                          AuthInputField(
                                            controller: _departmentController,
                                            label: 'College / Dept. Affiliation (e.g. CCS)',
                                            icon: Icons.account_balance_outlined,
                                          ),
                                        ] else ...[
                                          AuthInputField(
                                            controller: _studentIdController,
                                            label: 'Student ID (##-####-###)',
                                            icon: Icons.badge_outlined,
                                            keyboardType: TextInputType.phone,
                                          ),
                                          const SizedBox(height: 16),
                                          AuthInputField(
                                            controller: _departmentController,
                                            label: 'Department Code (e.g. CCS)',
                                            icon: Icons.school_outlined,
                                          ),
                                        ],
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
                                        AuthInputField(
                                          controller: _emailController,
                                          label: _selectedRole == 'SELLER'
                                              ? 'Store / Contact Email (e.g. Gmail)'
                                              : 'CIT-U Email (@cit.edu)',
                                          icon: Icons.email_outlined,
                                          keyboardType: TextInputType.emailAddress,
                                          validator: (val) {
                                            if (val == null || val.trim().isEmpty) {
                                              return 'Please enter your email';
                                            }
                                            final email = val.trim().toLowerCase();
                                            if (_selectedRole == 'BUYER') {
                                              if (!email.endsWith('@cit.edu')) {
                                                return 'Buyers must use an official @cit.edu email';
                                              }
                                            } else {
                                              final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                              if (!emailRegex.hasMatch(email)) {
                                                return 'Please enter a valid email address';
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        AuthInputField(
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
