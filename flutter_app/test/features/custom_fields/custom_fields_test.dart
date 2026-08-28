import 'package:flutter_test/flutter_test.dart';
import 'package:katasticho/features/custom_fields/data/custom_field_models.dart';

void main() {
  group('Step 4.3: CustomFieldDefinition Tests', () {
    test('deserializes complete custom field definition JSON correctly', () {
      final json = {
        'id': 'cf-101',
        'entityType': 'CONTACT',
        'fieldName': 'drug_license_validity',
        'fieldLabel': 'Drug License Validity Date',
        'fieldType': 'DATE',
        'isRequired': true,
        'defaultValue': '2026-12-31',
        'options': <String>[],
        'validationRegex': r'^\d{4}-\d{2}-\d{2}$',
        'sortOrder': 1,
        'isActive': true,
        'showInGrid': true,
        'showInPdf': true,
        'createdAt': '2026-08-20T10:00:00Z',
        'updatedAt': '2026-08-20T10:00:00Z',
      };

      final def = CustomFieldDefinition.fromJson(json);

      expect(def.id, 'cf-101');
      expect(def.entityType, 'CONTACT');
      expect(def.fieldName, 'drug_license_validity');
      expect(def.fieldLabel, 'Drug License Validity Date');
      expect(def.fieldType, FieldType.date);
      expect(def.isRequired, isTrue);
      expect(def.defaultValue, '2026-12-31');
      expect(def.validationRegex, r'^\d{4}-\d{2}-\d{2}$');
      expect(def.showInGrid, isTrue);
      expect(def.showInPdf, isTrue);
    });

    test('deserializes dropdown field with options list correctly', () {
      final json = {
        'id': 'cf-102',
        'entityType': 'ITEM',
        'fieldName': 'storage_temp_range',
        'fieldLabel': 'Storage Temperature',
        'fieldType': 'DROPDOWN',
        'isRequired': false,
        'options': ['2-8°C (Cold Chain)', '15-25°C (Ambient)', 'Below 0°C (Frozen)'],
        'sortOrder': 2,
        'isActive': true,
        'showInGrid': true,
        'showInPdf': false,
      };

      final def = CustomFieldDefinition.fromJson(json);

      expect(def.fieldType, FieldType.dropdown);
      expect(def.options.length, 3);
      expect(def.options.first, '2-8°C (Cold Chain)');
    });

    test('FieldType enum mapping handles labels and fallback safely', () {
      expect(FieldType.fromString('TEXT').label, 'Text');
      expect(FieldType.fromString('NUMBER').label, 'Number');
      expect(FieldType.fromString('DATE').label, 'Date');
      expect(FieldType.fromString('DROPDOWN').label, 'Dropdown');
      expect(FieldType.fromString('BOOLEAN').label, 'Yes / No');
      expect(FieldType.fromString('URL').label, 'URL / Link');
      expect(FieldType.fromString('NON_EXISTENT'), FieldType.text);
    });
  });

  group('Step 4.3: CustomFieldValueDTO Tests', () {
    test('deserializes custom field value DTO JSON map properly', () {
      final json = {
        'fieldDefinitionId': 'cf-101',
        'fieldName': 'drug_license_validity',
        'fieldLabel': 'Drug License Validity Date',
        'fieldType': 'DATE',
        'isRequired': true,
        'options': <String>[],
        'showInGrid': true,
        'showInPdf': true,
        'sortOrder': 1,
        'valueDate': '2027-03-31',
      };

      final val = CustomFieldValueDTO.fromJson(json);

      expect(val.fieldDefinitionId, 'cf-101');
      expect(val.fieldName, 'drug_license_validity');
      expect(val.fieldLabel, 'Drug License Validity Date');
      expect(val.fieldType, FieldType.date);
      expect(val.valueDate, '2027-03-31');
      expect(val.displayValue, '2027-03-31');
    });

    test('serializes CustomFieldValueInput payload correctly', () {
      const input = CustomFieldValueInput(
        fieldDefinitionId: 'cf-101',
        fieldName: 'driver_dl_number',
        value: 'DL-KA01-2026',
      );

      final json = input.toJson();

      expect(json['fieldDefinitionId'], 'cf-101');
      expect(json['fieldName'], 'driver_dl_number');
      expect(json['value'], 'DL-KA01-2026');
    });
  });
}
