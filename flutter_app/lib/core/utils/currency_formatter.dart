import 'package:intl/intl.dart';

/// Formats financial amounts. Carries an **active currency** (symbol + decimals
/// + grouping style) set once after login from the org's country profile, so
/// money renders as ₹ (Indian grouping, 2dp) for an India org, AED (Western
/// grouping, 2dp) for UAE, OMR (3dp) for Oman — without every call site knowing
/// the currency.
///
/// The active config is read by [format] / [formatCompact] (and therefore by
/// `KMoney`), so widgets stay `const` — no provider/ref plumbing. Defaults to
/// Indian ₹/2dp, so until [setActiveCurrency] is called nothing changes.
class CurrencyFormatter {
  CurrencyFormatter._();

  // ── Active currency (set at login from /api/v1/reference/country-profile) ──
  static String _symbol = '₹';
  static int _decimals = 2;
  static bool _indianGrouping = true; // lakh/crore vs thousands

  /// Set the active currency for the signed-in org. Indian grouping + ₹ by
  /// default keeps India behaviour byte-identical.
  static void setActiveCurrency({
    required String symbol,
    int decimals = 2,
    bool indianGrouping = true,
  }) {
    _symbol = symbol;
    _decimals = decimals;
    _indianGrouping = indianGrouping;
  }

  /// Reset to Indian defaults (e.g. on logout).
  static void resetActiveCurrency() {
    _symbol = '₹';
    _decimals = 2;
    _indianGrouping = true;
  }

  static String get activeSymbol => _symbol;
  static int get activeDecimals => _decimals;

  /// Format using the ACTIVE currency (symbol + decimals + grouping).
  static String format(double amount) {
    final body = _grouped(amount.abs(), _decimals, indian: _indianGrouping);
    return amount < 0 ? '-$_symbol$body' : '$_symbol$body';
  }

  /// Format amount in Indian numbering system (e.g., 12,34,567.89).
  /// Kept for explicit Indian formatting / back-compat.
  static String formatIndian(double amount, {String symbol = '₹'}) {
    if (amount < 0) {
      return '-$symbol${_formatIndianPositive(-amount)}';
    }
    return '$symbol${_formatIndianPositive(amount)}';
  }

  static String _formatIndianPositive(double amount) =>
      _grouped(amount, 2, indian: true);

  /// Format with standard international notation for a given currency code.
  static String formatStandard(double amount, {String currencyCode = 'INR'}) {
    final format = NumberFormat.currency(
      locale: _indianGrouping ? 'en_IN' : 'en_US',
      symbol: _currencySymbol(currencyCode),
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  /// Compact format for KPIs. Uses the active currency symbol; lakh/crore for
  /// Indian grouping, K/M/B otherwise.
  static String formatCompact(double amount, {String? symbol}) {
    final sym = symbol ?? _symbol;
    final a = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (_indianGrouping) {
      if (a >= 10000000) return '$sign$sym${(a / 10000000).toStringAsFixed(2)}Cr';
      if (a >= 100000) return '$sign$sym${(a / 100000).toStringAsFixed(2)}L';
      if (a >= 1000) return '$sign$sym${(a / 1000).toStringAsFixed(1)}K';
      return '$sign$sym${a.toStringAsFixed(0)}';
    }
    if (a >= 1000000000) return '$sign$sym${(a / 1000000000).toStringAsFixed(2)}B';
    if (a >= 1000000) return '$sign$sym${(a / 1000000).toStringAsFixed(2)}M';
    if (a >= 1000) return '$sign$sym${(a / 1000).toStringAsFixed(1)}K';
    return '$sign$sym${a.toStringAsFixed(0)}';
  }

  // ── grouping ────────────────────────────────────────────────────────────

  /// Group a non-negative amount with [decimals] places, Indian (lakh/crore)
  /// or Western (thousands) separators.
  static String _grouped(double amount, int decimals, {required bool indian}) {
    if (!indian) {
      final pattern = decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';
      return NumberFormat(pattern, 'en_US').format(amount);
    }
    final parts = amount.toStringAsFixed(decimals).split('.');
    final intPart = parts[0];
    final decPart = parts.length > 1 ? parts[1] : '';
    final dec = decimals > 0 ? '.$decPart' : '';

    if (intPart.length <= 3) {
      return '$intPart$dec';
    }
    final lastThree = intPart.substring(intPart.length - 3);
    final remaining = intPart.substring(0, intPart.length - 3);
    final buffer = StringBuffer();
    for (int i = 0; i < remaining.length; i++) {
      if (i > 0 && (remaining.length - i) % 2 == 0) {
        buffer.write(',');
      }
      buffer.write(remaining[i]);
    }
    buffer.write(',$lastThree$dec');
    return buffer.toString();
  }

  static String _currencySymbol(String code) {
    return switch (code) {
      'INR' => '₹',
      'USD' => '\$',
      'EUR' => '€',
      'GBP' => '£',
      'AED' => 'AED',
      'OMR' => 'OMR',
      'SAR' => 'SAR',
      'KES' => 'KSh',
      'NGN' => '₦',
      'ZAR' => 'R',
      _ => code,
    };
  }
}
