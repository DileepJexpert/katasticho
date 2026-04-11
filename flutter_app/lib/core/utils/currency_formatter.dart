import 'package:intl/intl.dart';

/// Utility for formatting financial amounts with proper Indian/standard notation.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Format amount in Indian numbering system (e.g., 12,34,567.89).
  static String formatIndian(double amount, {String symbol = '\u20B9'}) {
    if (amount < 0) {
      return '-$symbol${_formatIndianPositive(-amount)}';
    }
    return '$symbol${_formatIndianPositive(amount)}';
  }

  static String _formatIndianPositive(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    if (intPart.length <= 3) {
      return '$intPart.$decPart';
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
    buffer.write(',$lastThree.$decPart');
    return buffer.toString();
  }

  /// Format with standard international notation.
  static String formatStandard(double amount, {String currencyCode = 'INR'}) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: _currencySymbol(currencyCode),
      decimalDigits: 2,
    );
    return format.format(amount);
  }

  /// Compact format for KPIs (e.g., 12.5L, 3.2Cr).
  static String formatCompact(double amount, {String symbol = '\u20B9'}) {
    if (amount.abs() >= 10000000) {
      return '$symbol${(amount / 10000000).toStringAsFixed(2)}Cr';
    } else if (amount.abs() >= 100000) {
      return '$symbol${(amount / 100000).toStringAsFixed(2)}L';
    } else if (amount.abs() >= 1000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '$symbol${amount.toStringAsFixed(0)}';
  }

  static String _currencySymbol(String code) {
    return switch (code) {
      'INR' => '\u20B9',
      'USD' => '\$',
      'EUR' => '\u20AC',
      'GBP' => '\u00A3',
      'KES' => 'KSh',
      'NGN' => '\u20A6',
      'ZAR' => 'R',
      _ => code,
    };
  }
}
