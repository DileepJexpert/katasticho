import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/core/utils/currency_formatter.dart';

void main() {
  // Reset to India defaults before each test (active currency is global state).
  setUp(CurrencyFormatter.resetActiveCurrency);
  tearDown(CurrencyFormatter.resetActiveCurrency);

  group('India defaults (byte-identical to legacy formatIndian)', () {
    test('lakh/crore grouping with ₹ and 2 decimals', () {
      expect(CurrencyFormatter.format(1234567.89), '₹12,34,567.89');
      expect(CurrencyFormatter.format(100), '₹100.00');
      expect(CurrencyFormatter.format(-5000.5), '-₹5,000.50');
    });

    test('format() matches formatIndian() for the default config', () {
      for (final v in [0.0, 999.99, 1000.0, 1234567.89, -42.5]) {
        expect(CurrencyFormatter.format(v), CurrencyFormatter.formatIndian(v));
      }
    });

    test('compact uses lakh/crore', () {
      expect(CurrencyFormatter.formatCompact(12500000), '₹1.25Cr');
      expect(CurrencyFormatter.formatCompact(320000), '₹3.20L');
    });
  });

  group('UAE (AED, Western grouping, 2dp)', () {
    setUp(() => CurrencyFormatter.setActiveCurrency(
        symbol: 'AED ', decimals: 2, indianGrouping: false));

    test('thousands grouping with AED prefix', () {
      expect(CurrencyFormatter.format(1234567.89), 'AED 1,234,567.89');
      expect(CurrencyFormatter.format(1050), 'AED 1,050.00');
    });

    test('compact uses K/M/B not lakh/crore', () {
      expect(CurrencyFormatter.formatCompact(1500000), 'AED 1.50M');
      expect(CurrencyFormatter.formatCompact(2500), 'AED 2.5K');
    });
  });

  group('Oman (OMR, 3 decimal places)', () {
    setUp(() => CurrencyFormatter.setActiveCurrency(
        symbol: 'OMR ', decimals: 3, indianGrouping: false));

    test('renders three decimals', () {
      expect(CurrencyFormatter.format(1234.5), 'OMR 1,234.500');
      expect(CurrencyFormatter.format(0.125), 'OMR 0.125');
    });
  });
}
