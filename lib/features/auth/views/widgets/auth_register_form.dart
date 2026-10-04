import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme.dart';
import 'auth_form_fields.dart';

/// Modular Multi-step Register Form Widget extracted from AuthGateView (HIGH-05).
class AuthRegisterForm extends StatefulWidget {
  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController studentIdController;
  final TextEditingController departmentController;
  final TextEditingController storeNameController;
  final TextEditingController orgContactController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;

  final String selectedRole;
  final String selectedSellerType;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<String> onSellerTypeChanged;

  final int registerStep;
  final ValueChanged<int> onStepChanged;
  final bool Function(int step) onValidateStep;
  final VoidCallback onSubmit;
  final bool isLoading;

  const AuthRegisterForm({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.studentIdController,
    required this.departmentController,
    required this.storeNameController,
    required this.orgContactController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.selectedRole,
    required this.selectedSellerType,
    required this.onRoleChanged,
    required this.onSellerTypeChanged,
    required this.registerStep,
    required this.onStepChanged,
    required this.onValidateStep,
    required this.onSubmit,
    required this.isLoading,
  });

  @override
  State<AuthRegisterForm> createState() => _AuthRegisterFormState();
}

class _AuthRegisterFormState extends State<AuthRegisterForm> {
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF8E8E93);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step Progress Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${widget.registerStep + 1} of 3',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: TeknoyTheme.citGold,
              ),
            ),
            Text(
              widget.registerStep == 0
                  ? 'Role & Identity'
                  : widget.registerStep == 1
                      ? 'Campus Details'
                      : 'Account Credentials',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: subtitleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(3, (index) {
            final active = index <= widget.registerStep;
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active
                      ? TeknoyTheme.citGold
                      : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Step 0: Identity & Role
        if (widget.registerStep == 0) ...[
          if (!(widget.selectedRole == 'SELLER' && widget.selectedSellerType == 'ORG')) ...[
            AuthInputField(
              controller: widget.firstNameController,
              label: 'First Name',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 16),
            AuthInputField(
              controller: widget.lastNameController,
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
                  selectedRole: widget.selectedRole,
                  title: 'Buyer',
                  desc: 'Browse & buy (can upgrade anytime)',
                  icon: Icons.shopping_bag_outlined,
                  onSelected: widget.onRoleChanged,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RoleCard(
                  role: 'SELLER',
                  selectedRole: widget.selectedRole,
                  title: 'Seller',
                  desc: 'Sell items, plus browse & buy',
                  icon: Icons.storefront_outlined,
                  onSelected: widget.onRoleChanged,
                ),
              ),
            ],
          ),
          if (widget.selectedRole == 'SELLER') ...[
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
                    selectedSellerType: widget.selectedSellerType,
                    title: 'Student / Personal',
                    desc: 'Individual student seller',
                    icon: Icons.school_outlined,
                    onSelected: widget.onSellerTypeChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SellerTypeCard(
                    type: 'ORG',
                    selectedSellerType: widget.selectedSellerType,
                    title: 'Org / Shop',
                    desc: 'Organization or big store',
                    icon: Icons.storefront_rounded,
                    onSelected: widget.onSellerTypeChanged,
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
                color: (widget.selectedSellerType == 'ORG'
                        ? const Color(0xFF1565C0)
                        : TeknoyTheme.citGold)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.selectedSellerType == 'ORG'
                        ? Icons.info_outline_rounded
                        : Icons.badge_outlined,
                    size: 14,
                    color: widget.selectedSellerType == 'ORG'
                        ? const Color(0xFF1976D2)
                        : TeknoyTheme.citGold,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.selectedSellerType == 'ORG'
                          ? 'Next step: Contact number & college affiliation'
                          : 'Next step: Student ID & department code',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: widget.selectedSellerType == 'ORG'
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
              controller: widget.storeNameController,
              label: 'Store Name',
              icon: Icons.store_mall_directory_outlined,
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (widget.onValidateStep(0)) {
                  widget.onStepChanged(1);
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
        if (widget.registerStep == 1) ...[
          if (widget.selectedRole == 'SELLER' && widget.selectedSellerType == 'ORG') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.3),
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
              controller: widget.orgContactController,
              label: 'Contact Number (09XX-XXX-XXXX)',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            AuthDropdownField<String>(
              value: citDepartmentOptions.any((opt) => opt.code == widget.departmentController.text.trim())
                  ? widget.departmentController.text.trim()
                  : null,
              label: 'College / Dept. Affiliation',
              hint: 'Select Department or School',
              icon: Icons.account_balance_outlined,
              items: citDepartmentOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt.code,
                  child: Text(
                    opt.fullTitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: widget.departmentController.text.trim() == opt.code
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  widget.departmentController.text = val;
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: citDepartmentOptions.map((opt) {
                final isSelected = widget.departmentController.text.trim().toUpperCase() == opt.code;
                return GestureDetector(
                  onTap: () {
                    widget.departmentController.text = opt.code;
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? TeknoyTheme.citMaroon.withValues(alpha: 0.15)
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? TeknoyTheme.citMaroon
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      opt.code,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? TeknoyTheme.citMaroon
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (widget.departmentController.text.trim().isNotEmpty &&
                citDepartmentOptions.any((opt) => opt.code == widget.departmentController.text.trim())) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      citDepartmentOptions.firstWhere((o) => o.code == widget.departmentController.text.trim()).name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ] else ...[
            AuthInputField(
              controller: widget.studentIdController,
              label: 'Student ID (##-####-###)',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                StudentIdInputFormatter(),
              ],
            ),
            const SizedBox(height: 16),
            AuthDropdownField<String>(
              value: citDepartmentOptions.any((opt) => opt.code == widget.departmentController.text.trim())
                  ? widget.departmentController.text.trim()
                  : null,
              label: 'Department / Academic Level',
              hint: 'Select Department or School',
              icon: Icons.school_outlined,
              items: citDepartmentOptions.map((opt) {
                return DropdownMenuItem<String>(
                  value: opt.code,
                  child: Text(
                    opt.fullTitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: widget.departmentController.text.trim() == opt.code
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  widget.departmentController.text = val;
                  setState(() {});
                }
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: citDepartmentOptions.map((opt) {
                final isSelected = widget.departmentController.text.trim().toUpperCase() == opt.code;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.departmentController.text = opt.code;
                    setState(() {});
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? TeknoyTheme.citMaroon.withValues(alpha: 0.15)
                          : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? TeknoyTheme.citMaroon
                            : (isDark ? Colors.white12 : Colors.black12),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      opt.code,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? TeknoyTheme.citMaroon
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (widget.departmentController.text.trim().isNotEmpty &&
                citDepartmentOptions.any((opt) => opt.code == widget.departmentController.text.trim())) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      citDepartmentOptions.firstWhere((o) => o.code == widget.departmentController.text.trim()).name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onStepChanged(0),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFDCDCE0)),
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
                    if (widget.onValidateStep(1)) {
                      widget.onStepChanged(2);
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
        if (widget.registerStep == 2) ...[
          AuthInputField(
            controller: widget.emailController,
            label: widget.selectedRole == 'SELLER'
                ? 'Store / Contact Email (e.g. Gmail)'
                : 'CIT-U Email (@cit.edu)',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your email';
              }
              final email = val.trim().toLowerCase();
              if (widget.selectedRole == 'BUYER') {
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
              if (val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(
                  widget.passwordController.text.length >= 6
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 13,
                  color: widget.passwordController.text.length >= 6
                      ? Colors.green
                      : (isDark ? Colors.white54 : Colors.black45),
                ),
                const SizedBox(width: 4),
                Text(
                  'Must be at least 6 characters',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: widget.passwordController.text.length >= 6
                        ? Colors.green
                        : (isDark ? Colors.white54 : Colors.black45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AuthInputField(
            controller: widget.confirmPasswordController,
            label: 'Confirm Password',
            icon: Icons.lock_clock_outlined,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: isDark ? Colors.white60 : Colors.black54,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please confirm your password';
              }
              if (val != widget.passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onStepChanged(1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    side: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.2) : const Color(0xFFDCDCE0)),
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
                  onPressed: widget.isLoading ? null : widget.onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeknoyTheme.citMaroon,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: widget.isLoading
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
    );
  }
}
