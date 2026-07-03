/// Per-country phone-number rules.
///
/// The app historically hardcoded the Indian rule (a 10-digit national number),
/// which rejects valid Gulf numbers (UAE/Kenya mobile = 9 digits, Oman = 8). This
/// keys the minimum national-number length off the org/onboarding country so a
/// UAE signup isn't blocked.
///
/// Only a **minimum** length is enforced (matching the previous `< 10` check), so
/// India stays byte-identical and a user may still type a leading country code
/// (e.g. +971 50…) without being rejected. Unknown OR unset (null) countries fall
/// back to a permissive 7-digit floor — defaulting an unknown country to India's
/// 10-digit rule would wrongly reject valid Gulf/Kenya numbers, defeating the point.
class PhoneRule {
  /// Minimum national-significant-number digits (excluding the country dial code).
  final int minDigits;
  const PhoneRule(this.minDigits);
}

class PhoneRules {
  PhoneRules._();

  static const Map<String, PhoneRule> _byCountry = {
    'IN': PhoneRule(10),
    'AE': PhoneRule(9),
    'OM': PhoneRule(8),
    'KE': PhoneRule(9),
  };

  static const PhoneRule _fallback = PhoneRule(7);

  static PhoneRule forCountry(String? code) =>
      (code == null || code.isEmpty)
          ? _fallback
          : (_byCountry[code.toUpperCase()] ?? _fallback);

  /// Validate the entered phone for [country]. Returns an error string for the
  /// form validator, or null when valid. India ("IN") keeps the prior 10-digit
  /// minimum exactly.
  static String? validate(String? raw, String? country) {
    if (raw == null || raw.trim().isEmpty) return 'Phone number is required';
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length < forCountry(country).minDigits) {
      return 'Enter a valid phone number';
    }
    return null;
  }
}
