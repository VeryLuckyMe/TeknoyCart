import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import '../providers/auth_provider.dart';

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
            msg = msg.replaceAll('AuthException: ', '').replaceAll('Exception: ', '').trim();
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
            builder: (ctx) => _EmailVerificationDialog(
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
    final forgotEmailCtrl = TextEditingController(text: _emailController.text);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
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
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your email address and we will send you instructions to reset your password.',
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
                    labelText: 'Email Address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final email = forgotEmailCtrl.text.trim();
                    if (email.isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      await Supabase.instance.client.auth.resetPasswordForEmail(email);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password reset instructions sent to your email.')),
                        );
                      }
                    } catch (e) {
                      if (mounted) _showErrorSnackBar(e.toString());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeknoyTheme.citMaroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Send Reset Link',
                    style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSetNewPasswordSheet() {
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
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
                        const Icon(Icons.lock_reset_rounded, color: TeknoyTheme.citMaroon, size: 28),
                        const SizedBox(width: 10),
                        Text(
                          'Set New Password',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please enter and confirm your new account password.',
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
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setModalState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: confirmPasswordCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () async {
                        final pass = newPasswordCtrl.text;
                        final confirm = confirmPasswordCtrl.text;
                        if (pass.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password must be at least 6 characters.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (pass != confirm) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Passwords do not match.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        try {
                          await Supabase.instance.client.auth.updateUser(
                            UserAttributes(password: pass),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ Password updated successfully! Please log in with your new password.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            _switchTab(true);
                          }
                        } catch (e) {
                          if (mounted) _showErrorSnackBar(e.toString());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TeknoyTheme.citMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Update Password',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? TeknoyTheme.citMaroon.withOpacity(isDark ? 0.25 : 0.08)
              : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF6F6F8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? TeknoyTheme.citMaroon
                : (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE5E5EA)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected ? TeknoyTheme.citMaroon : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? TeknoyTheme.citMaroon
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerTypeCard({
    required String type,
    required String title,
    required String desc,
    required IconData icon,
  }) {
    final isSelected = _selectedSellerType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = type == 'ORG' ? const Color(0xFF1976D2) : TeknoyTheme.citGold;

    return GestureDetector(
      onTap: () => setState(() => _selectedSellerType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(isDark ? 0.25 : 0.08)
              : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF6F6F8)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white.withOpacity(0.1) : const Color(0xFFE5E5EA)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? activeColor : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? activeColor : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10,
                color: isDark ? Colors.white38 : Colors.black45,
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
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
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
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white60 : Colors.black54),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE9ECEF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE9ECEF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: TeknoyTheme.citMaroon, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
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
                                      _buildInputField(
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
                                                child: _buildSellerTypeCard(
                                                  type: 'STUDENT',
                                                  title: 'Student / Personal',
                                                  desc: 'Individual student seller',
                                                  icon: Icons.school_outlined,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _buildSellerTypeCard(
                                                  type: 'ORG',
                                                  title: 'Org / Shop',
                                                  desc: 'Organization or big store',
                                                  icon: Icons.storefront_rounded,
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
                                          _buildInputField(
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
                                          _buildInputField(
                                            controller: _orgContactController,
                                            label: 'Contact Number (09XX-XXX-XXXX)',
                                            icon: Icons.phone_outlined,
                                            keyboardType: TextInputType.phone,
                                          ),
                                          const SizedBox(height: 16),
                                          _buildInputField(
                                            controller: _departmentController,
                                            label: 'College / Dept. Affiliation (e.g. CCS)',
                                            icon: Icons.account_balance_outlined,
                                          ),
                                        ] else ...[
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
                                        _buildInputField(
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

// ---------------------------------------------------------------------------
// Email Verification Dialog with countdown timer
// ---------------------------------------------------------------------------
class _EmailVerificationDialog extends StatefulWidget {
  final String email;
  const _EmailVerificationDialog({required this.email});

  @override
  State<_EmailVerificationDialog> createState() => _EmailVerificationDialogState();
}

class _EmailVerificationDialogState extends State<_EmailVerificationDialog> {
  static const int _totalSeconds = 300; // 5 minutes
  int _secondsLeft = _totalSeconds;
  bool _expired = false;
  bool _resending = false;
  bool _resent = false;
  bool _verifiedSuccess = false;
  Timer? _timer;
  Timer? _statusPollTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _startStatusPoller();
  }

  void _startStatusPoller() {
    _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (!mounted) { t.cancel(); return; }
      try {
        final res = await Supabase.instance.client
            .from('users')
            .select('is_verified')
            .eq('email', widget.email.trim())
            .maybeSingle();

        if (res != null && res['is_verified'] == true) {
          t.cancel();
          _timer?.cancel();
          if (mounted) {
            setState(() {
              _verifiedSuccess = true;
            });
            await Future.delayed(const Duration(milliseconds: 1800));
            if (mounted) {
              Navigator.of(context).pop(true);
            }
          }
        }
      } catch (_) {}
    });
  }

  void _startTimer() {
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
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) {
        setState(() {
          _resending = false;
          _resent = true;
          _expired = false;
          _secondsLeft = _totalSeconds;
        });
        _startTimer();
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
    _statusPollTimer?.cancel();
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
    if (_secondsLeft > 120) return const Color(0xFF2E7D32);
    if (_secondsLeft > 60) return const Color(0xFFF57F17);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_verifiedSuccess) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 54,
                  color: Color(0xFF2E7D32),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Verification Successful!',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your institutional email has been verified.\nRedirecting to login...',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
                color: (_expired
                    ? const Color(0xFFC62828)
                    : const Color(0xFF2E7D32)).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _expired
                    ? Icons.timer_off_rounded
                    : Icons.mark_email_unread_rounded,
                size: 42,
                color: _expired ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              _expired ? 'Link Expired' : 'Verify Your Email',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _expired
                    ? const Color(0xFFC62828)
                    : (isDark ? Colors.white : Colors.black87),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            // Subtitle
            Text(
              _expired
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
                color: TeknoyTheme.citMaroon.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TeknoyTheme.citMaroon.withOpacity(0.25)),
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
            const SizedBox(height: 20),

            // Countdown or expired indicator
            if (!_expired) ...[
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
                      backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
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
                    const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF2E7D32)),
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
                  onPressed: _resending ? null : _resendEmail,
                  icon: _resending
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _resending ? 'Sending...' : 'Resend Verification Email',
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
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _expired ? 'Close' : 'Got it, I\'ll check my email',
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
