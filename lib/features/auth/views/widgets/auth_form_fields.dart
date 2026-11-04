import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme.dart';
import '../../utils/student_id.dart';

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

  Color _cardBg(bool isSelected, bool isDark) {
    if (isSelected) {
      return TeknoyTheme.citMaroon.withValues(alpha: isDark ? 0.25 : 0.08);
    }
    return isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF6F6F8);
  }

  Color _borderColor(bool isSelected, bool isDark) {
    if (isSelected) return TeknoyTheme.citMaroon;
    return isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E5EA);
  }

  Color _primaryTextColor(bool isSelected, bool isDark) {
    if (isSelected) return TeknoyTheme.citMaroon;
    return isDark ? Colors.white : Colors.black87;
  }

  Color _iconColor(bool isSelected, bool isDark) {
    if (isSelected) return TeknoyTheme.citMaroon;
    return isDark ? Colors.white60 : Colors.black54;
  }

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
          color: _cardBg(isSelected, isDark),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _borderColor(isSelected, isDark),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 26,
              color: _iconColor(isSelected, isDark),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _primaryTextColor(isSelected, isDark),
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

  Color _cardBg(bool isSelected, bool isDark, Color activeColor) {
    if (isSelected) {
      return activeColor.withValues(alpha: isDark ? 0.25 : 0.08);
    }
    return isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF6F6F8);
  }

  Color _borderColor(bool isSelected, bool isDark, Color activeColor) {
    if (isSelected) return activeColor;
    return isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E5EA);
  }

  Color _primaryTextColor(bool isSelected, bool isDark, Color activeColor) {
    if (isSelected) return activeColor;
    return isDark ? Colors.white : Colors.black87;
  }

  Color _iconColor(bool isSelected, bool isDark, Color activeColor) {
    if (isSelected) return activeColor;
    return isDark ? Colors.white60 : Colors.black54;
  }

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
          color: _cardBg(isSelected, isDark, activeColor),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _borderColor(isSelected, isDark, activeColor),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 22,
              color: _iconColor(isSelected, isDark, activeColor),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _primaryTextColor(isSelected, isDark, activeColor),
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
  final bool enabled;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;

  /// Extra room kept below the caret when the field scrolls itself into view.
  ///
  /// The default (`EdgeInsets.all(20)`) is too small for this form: on a
  /// keyboard-resized 390x844 viewport the Confirm Password field ended 34 px
  /// under the keyboard once an error line appeared above it, so the field
  /// looked impossible to type into. The bottom inset here covers the field
  /// padding, the live password hint row and a validation error line.
  final EdgeInsets scrollPadding;

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
    this.enabled = true,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.scrollPadding = const EdgeInsets.only(top: 24, bottom: 120),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      scrollPadding: scrollPadding,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: enabled
            ? (isDark ? Colors.white : Colors.black87)
            : (isDark ? Colors.white38 : Colors.black38),
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
        fillColor: enabled
            ? (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF8F9FA))
            : (isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFEEEEF0)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE9ECEF)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFE9ECEF)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE0E0E4)),
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

/// Sanitises CIT-U identification numbers **without** inventing separators.
///
/// College IDs look like `21-1029-315` while faculty / other grade levels use
/// shapes such as `2004-3732`, so an auto-inserted dash mangles those numbers
/// (and the old implementation also force-moved the caret to the end, which
/// corrupted digits on backspace).
///
/// The rules live in [StudentIdRules]; this class only maps them onto the
/// editing value while preserving the caret.
class StudentIdInputFormatter extends TextInputFormatter {
  const StudentIdInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    final cleaned = StudentIdRules.sanitize(newValue.text);
    if (cleaned == newValue.text) return newValue; // nothing to fix — keep the caret

    // Map the old caret onto the cleaned string: the kept characters of the
    // text that preceded the caret define the new offset.
    final caret = newValue.selection.isValid
        ? newValue.selection.baseOffset.clamp(0, newValue.text.length)
        : newValue.text.length;
    final keptBeforeCaret =
        StudentIdRules.sanitize(newValue.text.substring(0, caret)).length;

    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: keptBeforeCaret),
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
      initialValue: value,
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
