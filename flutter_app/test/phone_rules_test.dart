import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/core/intl/phone_rules.dart';

void main() {
  group('PhoneRules.validate', () {
    test('India keeps the 10-digit minimum (byte-identical to legacy)', () {
      expect(PhoneRules.validate('9876543210', 'IN'), isNull);
      expect(PhoneRules.validate('98765', 'IN'), 'Enter a valid phone number');
      expect(PhoneRules.validate('', 'IN'), 'Phone number is required');
      expect(PhoneRules.validate(null, 'IN'), 'Phone number is required');
    });

    test('UAE accepts a 9-digit national number', () {
      expect(PhoneRules.validate('501234567', 'AE'), isNull);
      expect(PhoneRules.validate('50123', 'AE'), 'Enter a valid phone number');
    });

    test('Oman accepts an 8-digit national number', () {
      expect(PhoneRules.validate('91234567', 'OM'), isNull);
      expect(PhoneRules.validate('9123', 'OM'), 'Enter a valid phone number');
    });

    test('Kenya accepts a 9-digit national number', () {
      expect(PhoneRules.validate('712345678', 'KE'), isNull);
    });

    test('a leading country code (non-digits stripped) still validates', () {
      expect(PhoneRules.validate('+971 50 123 4567', 'AE'), isNull);
      expect(PhoneRules.validate('+91 98765 43210', 'IN'), isNull);
    });

    test('unknown / null country falls back to a permissive 7-digit floor', () {
      expect(PhoneRules.validate('1234567', null), isNull);
      expect(PhoneRules.validate('123456', null), 'Enter a valid phone number');
      expect(PhoneRules.validate('1234567', 'ZZ'), isNull);
    });
  });
}
