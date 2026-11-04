/// Rules for CIT-U identification numbers.
///
/// IDs are **not** uniform across the campus:
///   * college students: `21-1029-315` (##-####-###)
///   * faculty / other grade levels: `2004-3732`
///
/// So the app must never invent separators, and validation can only be based on
/// the digit count. Kept free of Flutter imports so services and widget tests
/// can use it without a binding.
class StudentIdRules {
  StudentIdRules._();

  /// Fewest digits a plausible ID can have (`2004-3732` has 8).
  static const int minDigits = 6;

  /// Most digits accepted in the field.
  static const int maxDigits = 12;

  /// Most separators accepted in the field.
  static const int maxDashes = 4;

  static const int maxLength = maxDigits + maxDashes;

  /// Digits only — used for comparison, because the same ID may be typed with
  /// or without dashes.
  static String digitsOf(String text) => text.replaceAll(RegExp(r'\D'), '');

  /// Keeps digits and dashes, drops leading/duplicate dashes, caps the digit and
  /// dash counts. Never inserts a separator.
  static String sanitize(String raw) {
    final buffer = StringBuffer();
    var digits = 0;
    var dashes = 0;
    for (final rune in raw.runes) {
      if (buffer.length >= maxLength) break;
      if (_isDigit(rune)) {
        if (digits >= maxDigits) continue;
        digits++;
        buffer.writeCharCode(rune);
      } else if (rune == 0x2D && digits > 0 && dashes < maxDashes) {
        if (buffer.toString().endsWith('-')) continue;
        dashes++;
        buffer.write('-');
      }
    }
    final cleaned = buffer.toString();
    return cleaned;
  }

  /// `true` when the ID has a plausible number of digits (dashes optional).
  static bool isValid(String raw) {
    final digits = digitsOf(raw).length;
    return digits >= minDigits && digits <= maxDigits;
  }

  static bool _isDigit(int rune) => rune >= 0x30 && rune <= 0x39;
}
