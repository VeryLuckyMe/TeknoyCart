import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;

  const AuthInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
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

/// Formatter that automatically places dashes for CIT-U Student IDs (##-####-###)
class StudentIdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If user is deleting and just deleted a dash, delete the preceding digit as well
    String text = newValue.text;
    if (oldValue.text.length > newValue.text.length &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.baseOffset > 0 &&
        oldValue.text[oldValue.selection.baseOffset - 1] == '-') {
      final deletePos = oldValue.selection.baseOffset - 2;
      if (deletePos >= 0 && deletePos < text.length) {
        text = text.substring(0, deletePos) + text.substring(deletePos + 1);
      }
    }

    final digitsOnly = text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length && i < 9; i++) {
      if (i == 2 || i == 6) {
        buffer.write('-');
      }
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Official CIT-U Academic Departments & High School Levels
class CitDepartmentOption {
  final String code;
  final String name;

  const CitDepartmentOption({required this.code, required this.name});

  String get fullTitle => '$code — $name';
}

const List<CitDepartmentOption> citDepartmentOptions = [
  CitDepartmentOption(code: 'CCS', name: 'College of Computer Studies'),
  CitDepartmentOption(code: 'CEA', name: 'College of Engineering & Architecture'),
  CitDepartmentOption(code: 'CASE', name: 'College of Arts, Sciences & Education'),
  CitDepartmentOption(code: 'CMBA', name: 'College of Management, Business & Accountancy'),
  CitDepartmentOption(code: 'CNAHS', name: 'College of Nursing & Allied Health Sciences'),
  CitDepartmentOption(code: 'CCJ', name: 'College of Criminal Justice'),
  CitDepartmentOption(code: 'JHS', name: 'Junior High School'),
  CitDepartmentOption(code: 'SHS', name: 'Senior High School'),
];

/// Premium styled dropdown field matching AuthInputField aesthetics
class AuthDropdownField<T> extends StatelessWidget {
  final T? value;
  final String label;
  final String? hint;
  final IconData icon;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;

  const AuthDropdownField({
    super.key,
    required this.value,
    required this.label,
    this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
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
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white60 : Colors.black54),
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
