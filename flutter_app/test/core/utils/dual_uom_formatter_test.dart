import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/core/utils/dual_uom_formatter.dart';

void main() {
  group('DualUomParser Tests', () {
    test('Standard single-unit fallback without packaging conversion', () {
      final res = DualUomParser.parse('10.5', conversionFactor: 1.0, mainUnit: 'KG');
      expect(res.isDual, false);
      expect(res.totalBaseQty, 10.5);
      expect(res.totalMainQty, 10.5);
      expect(res.mainQty, 10.5);
      expect(res.subQty, 0.0);
      expect(res.displayText, '10.5 KG');
    });

    test('Pharma 10-pack (1 Box = 10 Strips) with dot syntax', () {
      // 10.5 means 10 boxes + 5 strips = 105 strips
      final res = DualUomParser.parse(
        '10.5',
        conversionFactor: 10.0,
        mainUnit: 'BOX',
        subUnit: 'STRIP',
      );
      expect(res.isDual, true);
      expect(res.mainQty, 10.0);
      expect(res.subQty, 5.0);
      expect(res.totalBaseQty, 105.0);
      expect(res.totalMainQty, 10.5);
      expect(res.displayText, '10 BOX + 5 STRIP (105 STRIP)');
      expect(res.shortSummary, '10 BOX 5 STRIP');
    });

    test('Pharma 10-pack with slash syntax 10/5', () {
      final res = DualUomParser.parse(
        '10/5',
        conversionFactor: 10.0,
        mainUnit: 'BOX',
        subUnit: 'STRIP',
      );
      expect(res.isDual, true);
      expect(res.mainQty, 10.0);
      expect(res.subQty, 5.0);
      expect(res.totalBaseQty, 105.0);
      expect(res.totalMainQty, 10.5);
    });

    test('FMCG 24-pack (1 Case = 24 Bottles) with 2.6 syntax', () {
      // 2.6 means 2 cases + 6 bottles = (2 * 24) + 6 = 54 bottles
      final res = DualUomParser.parse(
        '2.6',
        conversionFactor: 24.0,
        mainUnit: 'CASE',
        subUnit: 'BOTTLE',
      );
      expect(res.isDual, true);
      expect(res.mainQty, 2.0);
      expect(res.subQty, 6.0);
      expect(res.totalBaseQty, 54.0);
      expect(res.totalMainQty, 2.25);
      expect(res.displayText, '2 CASE + 6 BOTTLE (54 BOTTLE)');
    });

    test('Loose-only syntax .3 or /3 (0 Box + 3 Strips)', () {
      final resDot = DualUomParser.parse(
        '.3',
        conversionFactor: 10.0,
        mainUnit: 'BOX',
        subUnit: 'STRIP',
      );
      expect(resDot.mainQty, 0.0);
      expect(resDot.subQty, 3.0);
      expect(resDot.totalBaseQty, 3.0);
      expect(resDot.totalMainQty, 0.3);
      expect(resDot.displayText, '3 STRIP');

      final resSlash = DualUomParser.parse(
        '/3',
        conversionFactor: 10.0,
        mainUnit: 'BOX',
        subUnit: 'STRIP',
      );
      expect(resSlash.mainQty, 0.0);
      expect(resSlash.subQty, 3.0);
      expect(resSlash.totalBaseQty, 3.0);
    });

    test('Automatic rollover when loose quantity >= conversion factor', () {
      // User typed 10/15 with 1 Box = 10 Strips -> should rollover to 11 Box + 5 Strips (115 strips)
      final res = DualUomParser.parse(
        '10/15',
        conversionFactor: 10.0,
        mainUnit: 'BOX',
        subUnit: 'STRIP',
      );
      expect(res.mainQty, 11.0);
      expect(res.subQty, 5.0);
      expect(res.totalBaseQty, 115.0);
      expect(res.totalMainQty, 11.5);
      expect(res.displayText, '11 BOX + 5 STRIP (115 STRIP)');
    });

    test('Format total base quantity back to trade input string', () {
      expect(DualUomParser.formatInput(105.0, 10.0), '10.5');
      expect(DualUomParser.formatInput(105.0, 10.0, useSlash: true), '10/5');
      expect(DualUomParser.formatInput(100.0, 10.0), '10');
      expect(DualUomParser.formatInput(54.0, 24.0), '2.6');
      expect(DualUomParser.formatInput(10.5, 1.0), '10.5');
    });
  });
}
