import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teknoycart/features/auth/providers/auth_provider.dart';
import 'package:teknoycart/core/theme.dart';

/// Authentication gate view matching Figma "Login Screen" (Node 1:2).
/// Layout: 390×884, white card on #f8f9fa background.
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

  String _selectedRole = 'BUYER';
  bool _isLoginTab = true;
  bool _obscurePassword = true;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _passwordController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName = '$firstName $lastName';
    final authNotifier = ref.read(authNotifierProvider.notifier);
    if (_isLoginTab) {
      authNotifier.login(email: email, password: password);
    } else {
      authNotifier.register(
        email: email,
        username: fullName,
        password: password,
        role: _selectedRole,
      );
    }
  }

  void _switchTab(bool toLogin) {
    if (_isLoginTab == toLogin) return;
    _fadeCtrl.reset();
    setState(() => _isLoginTab = toLogin);
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AsyncValue>(authNotifierProvider, (_, state) {
      state.whenOrNull(
        error: (err, _) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err.toString().replaceAll('Exception: ', '')),
              backgroundColor: TeknoyTheme.error,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              children: [
                // ── Logo area above the card ──────────────────────────────
                const SizedBox(height: 40),
                // TeknoyCart circular logo
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TeknoyTheme.citMaroon,
                    boxShadow: [
                      BoxShadow(
                        color: TeknoyTheme.citMaroon.withOpacity(0.30),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.shopping_basket_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'TeknoyCart',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: TeknoyTheme.citMaroon,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),

                // ── White card (Figma: Background+Border+Shadow, cornerRadius: 12) ─
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.fromLTRB(25, 24, 25, 24),
                  child: Form(
                    key: _formKey,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Heading ──────────────────────────────────────
                          Text(
                            _isLoginTab ? 'Welcome Back' : 'Create Account',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF191C1D),
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isLoginTab
                                ? 'Sign in to continue to TeknoyCart.'
                                : 'Join the CIT-U student marketplace.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF5A413D),
                              letterSpacing: 0.25,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ── First Name & Last Name (register only) ───────
                          if (!_isLoginTab) ...[
                            _buildInputField(
                              controller: _firstNameController,
                              label: 'First Name',
                              icon: Icons.person_outline_rounded,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your first name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildInputField(
                              controller: _lastNameController,
                              label: 'Last Name',
                              icon: Icons.person_outline_rounded,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please enter your last name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // ── Role Selector Dropdown ──────────────────────
                            DropdownButtonFormField<String>(
                              value: _selectedRole,
                              dropdownColor: Colors.white,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: Color(0xFF191C1D),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Registration Role',
                                labelStyle: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xFF5A413D),
                                  letterSpacing: 0.25,
                                ),
                                prefixIcon: const Icon(
                                  Icons.assignment_ind_outlined,
                                  color: Color(0xFF5A413D),
                                  size: 20,
                                ),
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: const BorderSide(color: TeknoyTheme.citMaroon, width: 1.5),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'BUYER',
                                  child: Text(
                                    'Student Buyer (Browse & Inquire)',
                                    style: TextStyle(color: Color(0xFF191C1D)),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'SELLER',
                                  child: Text(
                                    'Campus Vendor / Seller (List & Sell)',
                                    style: TextStyle(color: Color(0xFF191C1D)),
                                  ),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedRole = val);
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── CIT-U Email ───────────────────────────────
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
                              if (!email.endsWith('@cit.edu') &&
                                  !email.endsWith('@my.cit.edu')) {
                                return 'Only @cit.edu or @my.cit.edu emails';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // ── Password ──────────────────────────────────
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
                                color: const Color(0xFF5A413D),
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

                          // ── Forgot Password link ──────────────────────
                          if (_isLoginTab) ...[
                            const SizedBox(height: 8),
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
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: TeknoyTheme.citMaroon,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // ── Login / Register Button ────────────────────
                          // Figma: #570000, cornerRadius: 12, height: 48
                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              key: const Key('auth-submit-btn'),
                              onPressed: authState.isLoading ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TeknoyTheme.citMaroon,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                  : Text(
                                      _isLoginTab ? 'Login' : 'Create Account',
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.15,
                                      ),
                                    ),
                            ),
                          ),
                        ],
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
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF5A413D),
                        letterSpacing: 0.25,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _switchTab(!_isLoginTab),
                      child: Text(
                        _isLoginTab ? 'Sign up' : 'Sign in',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: TeknoyTheme.citMaroon,
                          letterSpacing: 0.15,
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: Color(0xFF191C1D),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF5A413D),
          letterSpacing: 0.25,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF5A413D), size: 20),
        suffixIcon: suffixIcon,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: TeknoyTheme.citMaroon, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFB3261E)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}
