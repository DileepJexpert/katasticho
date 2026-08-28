import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/inventory/data/packaging_barcode_models.dart';

void main() {
  group('PackagingBarcodeModel Tests', () {
    test('deserializes complete packaging barcode JSON correctly', () {
      final json = {
        'id': 'pkg_001',
        'itemId': 'item_123',
        'itemName': 'Crocin 650mg Tablet',
        'itemSku': 'MED-CROCIN-650',
        'barcode': '8901234567010',
        'packagingLevel': 'CARTON',
        'packagingName': 'Master Carton 24x',
        'conversionFactor': 24.0,
        'uomName': 'CARTON',
        'mrp': 960.0,
        'salePrice': 800.0,
        'purchasePrice': 650.0,
        'isPrimary': false,
        'notes': 'Wholesale master box',
      };

      final model = PackagingBarcodeModel.fromJson(json);

      expect(model.id, equals('pkg_001'));
      expect(model.itemId, equals('item_123'));
      expect(model.itemName, equals('Crocin 650mg Tablet'));
      expect(model.barcode, equals('8901234567010'));
      expect(model.packagingLevel, equals('CARTON'));
      expect(model.packagingName, equals('Master Carton 24x'));
      expect(model.conversionFactor, equals(24.0));
      expect(model.uomName, equals('CARTON'));
      expect(model.mrp, equals(960.0));
      expect(model.salePrice, equals(800.0));
      expect(model.purchasePrice, equals(650.0));
    });
  });

  group('ResolvedBarcodeModel Tests', () {
    test('deserializes resolved barcode hierarchy match correctly', () {
      final json = {
        'itemId': 'item_123',
        'itemName': 'Crocin 650mg Tablet',
        'sku': 'MED-CROCIN-650',
        'itemBarcode': '8901234567001',
        'scannedBarcode': '8901234567010',
        'packagingLevel': 'CARTON',
        'packagingName': 'Master Carton 24x',
        'conversionFactor': 24.0,
        'quantityMultiplier': 24.0,
        'unitPrice': 800.0,
        'uomName': 'CARTON',
        'isHierarchyMatch': true,
      };

      final model = ResolvedBarcodeModel.fromJson(json);

      expect(model.itemId, equals('item_123'));
      expect(model.itemName, equals('Crocin 650mg Tablet'));
      expect(model.scannedBarcode, equals('8901234567010'));
      expect(model.packagingLevel, equals('CARTON'));
      expect(model.conversionFactor, equals(24.0));
      expect(model.quantityMultiplier, equals(24.0));
      expect(model.unitPrice, equals(800.0));
      expect(model.isHierarchyMatch, isTrue);
    });

    test('deserializes base item fallback match correctly', () {
      final json = {
        'itemId': 'item_123',
        'itemName': 'Crocin 650mg Tablet',
        'sku': 'MED-CROCIN-650',
        'itemBarcode': '8901234567001',
        'scannedBarcode': '8901234567001',
        'packagingLevel': 'UNIT',
        'packagingName': 'Base Unit',
        'conversionFactor': 1.0,
        'quantityMultiplier': 1.0,
        'unitPrice': 35.0,
        'uomName': 'STRIP',
        'isHierarchyMatch': false,
      };

      final model = ResolvedBarcodeModel.fromJson(json);

      expect(model.itemId, equals('item_123'));
      expect(model.conversionFactor, equals(1.0));
      expect(model.quantityMultiplier, equals(1.0));
      expect(model.isHierarchyMatch, isFalse);
    });
  });

  group('CreatePackagingBarcodeRequest Tests', () {
    test('serializes request correctly to JSON map', () {
      const req = CreatePackagingBarcodeRequest(
        barcode: '8901234567050',
        packagingLevel: 'CASE',
        packagingName: 'Outer Shipper Case 100x',
        conversionFactor: 100.0,
        uomName: 'CASE',
        mrp: 4000.0,
        salePrice: 3200.0,
      );

      final map = req.toJson();

      expect(map['barcode'], equals('8901234567050'));
      expect(map['packagingLevel'], equals('CASE'));
      expect(map['packagingName'], equals('Outer Shipper Case 100x'));
      expect(map['conversionFactor'], equals(100.0));
      expect(map['uomName'], equals('CASE'));
      expect(map['mrp'], equals(4000.0));
      expect(map['salePrice'], equals(3200.0));
      expect(map['isPrimary'], isFalse);
    });
  });
}
