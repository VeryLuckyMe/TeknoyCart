import 'package:flutter/material.dart';
import '../../../../core/theme.dart';

class RoleCard extends StatelessWidget {
  final String role;
  final String selectedRole;
  final String title;
  final String desc;
  final IconData icon;
  final ValueChanged<String> onSelected;

  const RoleCard({
    super.key,
    required this.role,
    required this.selectedRole,
    required this.title,
    required this.desc,
    required this.icon,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedRole == role;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onSelected(role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.25 : 0.08)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF6F6F8)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? TeknoyTheme.citMaroon
                : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E5EA)),
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
}

class SellerTypeCard extends StatelessWidget {
  final String type;
  final String selectedSellerType;
  final String title;
  final String desc;
  final IconData icon;
  final ValueChanged<String> onSelected;

  const SellerTypeCard({
    super.key,
    required this.type,
    required this.selectedSellerType,
    required this.title,
    required this.desc,
    required this.icon,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedSellerType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = type == 'ORG' ? const Color(0xFF1976D2) : TeknoyTheme.citGold;

    return GestureDetector(
      onTap: () => onSelected(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.08)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF6F6F8)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E5EA)),
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
}

class AuthInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AuthInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
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
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8F9FA),
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
          borderSide: const BorderSide(color: TeknoyTheme.citMaroon, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}
