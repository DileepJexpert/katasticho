import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/pricing/data/scheme_models.dart';

void main() {
  group('Multi-Tier Trade Scheme Models & Calculation Tests', () {
    test('SchemeModel correctly parses full scheme with half-scheme and subsidy fields', () {
      final json = {
        'id': 'sch-101',
        'name': 'Augmentin 10+1 Scheme',
        'schemeType': 'BUY_X_GET_Y',
        'itemId': 'item-aug-625',
        'itemName': 'Augmentin 625 Duo',
        'buyQuantity': 10,
        'freeQuantity': 1,
        'minOrderQuantity': 5,
        'allowHalfScheme': true,
        'halfSchemeMinQty': 5,
        'companySubsidyPercent': 100.0,
        'maxFreeQuantityCap': 10,
        'active': true,
      };

      final scheme = SchemeModel.fromJson(json);

      expect(scheme.id, 'sch-101');
      expect(scheme.name, 'Augmentin 10+1 Scheme');
      expect(scheme.schemeType, 'BUY_X_GET_Y');
      expect(scheme.buyQuantity, 10.0);
      expect(scheme.freeQuantity, 1.0);
      expect(scheme.allowHalfScheme, isTrue);
      expect(scheme.halfSchemeMinQty, 5.0);
      expect(scheme.companySubsidyPercent, 100.0);
      expect(scheme.maxFreeQuantityCap, 10.0);
    });

    test('SchemeModel correctly parses Special Net Rate scheme', () {
      final json = {
        'id': 'sch-102',
        'name': 'Pan-D Company Net Rate',
        'schemeType': 'SPECIAL_NET_RATE',
        'specialNetRate': 85.50,
        'minOrderQuantity': 50,
        'companySubsidyPercent': 80.0,
        'active': true,
      };

      final scheme = SchemeModel.fromJson(json);

      expect(scheme.schemeType, 'SPECIAL_NET_RATE');
      expect(scheme.specialNetRate, 85.50);
      expect(scheme.minOrderQuantity, 50.0);
      expect(scheme.companySubsidyPercent, 80.0);
    });

    test('SchemeCalculationResult parses live evaluation response correctly', () {
      final json = {
        'schemeId': 'sch-101',
        'schemeName': '10+1 Scheme',
        'schemeType': 'HALF_SCHEME',
        'orderedQuantity': 5,
        'freeQuantity': 0,
        'discountPercent': 9.09,
        'discountAmount': 45.45,
        'baseUnitPrice': 100.0,
        'effectiveUnitPrice': 90.91,
        'totalLineAmount': 454.55,
        'companyFundedAmount': 36.36,
        'distributorFundedAmount': 9.09,
        'isHalfSchemeApplied': true,
        'explanation': 'Half scheme applied @ 9.09% discount',
      };

      final result = SchemeCalculationResult.fromJson(json);

      expect(result.schemeType, 'HALF_SCHEME');
      expect(result.isHalfSchemeApplied, isTrue);
      expect(result.discountPercent, 9.09);
      expect(result.discountAmount, 45.45);
      expect(result.companyFundedAmount, 36.36);
      expect(result.distributorFundedAmount, 9.09);
      expect(result.totalLineAmount, 454.55);
    });

    test('SchemeType enum mapping handles unknown codes safely', () {
      expect(SchemeType.fromCode('BUY_X_GET_Y'), SchemeType.buyXGetY);
      expect(SchemeType.fromCode('PERCENT_DISCOUNT'), SchemeType.percentDiscount);
      expect(SchemeType.fromCode('SPECIAL_NET_RATE'), SchemeType.specialNetRate);
      expect(SchemeType.fromCode('HALF_FULL_SCHEME'), SchemeType.halfFullScheme);
      expect(SchemeType.fromCode('UNKNOWN_CODE'), SchemeType.percentDiscount);
    });
  });
}
