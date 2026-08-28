import 'package:flutter/foundation.dart';

enum FieldType {
  text,
  number,
  date,
  dropdown,
  boolean,
  url;

  static FieldType fromString(String val) {
    return FieldType.values.firstWhere(
      (e) => e.name.toUpperCase() == val.toUpperCase(),
      orElse: () => FieldType.text,
    );
  }

  String get label {
    switch (this) {
      case FieldType.text:
        return 'Text';
      case FieldType.number:
        return 'Number';
      case FieldType.date:
        return 'Date';
      case FieldType.dropdown:
        return 'Dropdown';
      case FieldType.boolean:
        return 'Yes / No';
      case FieldType.url:
        return 'URL / Link';
    }
  }
}

@immutable
class CustomFieldDefinition {
  final String id;
  final String entityType;
  final String fieldName;
  final String fieldLabel;
  final FieldType fieldType;
  final bool isRequired;
  final String? defaultValue;
  final List<String> options;
  final String? validationRegex;
  final int sortOrder;
  final bool isActive;
  final bool showInGrid;
  final bool showInPdf;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CustomFieldDefinition({
    required this.id,
    required this.entityType,
    required this.fieldName,
    required this.fieldLabel,
    required this.fieldType,
    required this.isRequired,
    this.defaultValue,
    this.options = const [],
    this.validationRegex,
    required this.sortOrder,
    required this.isActive,
    required this.showInGrid,
    required this.showInPdf,
    this.createdAt,
    this.updatedAt,
  });

  factory CustomFieldDefinition.fromJson(Map<String, dynamic> json) {
    return CustomFieldDefinition(
      id: json['id'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      fieldName: json['fieldName'] as String? ?? '',
      fieldLabel: json['fieldLabel'] as String? ?? '',
      fieldType: FieldType.fromString(json['fieldType'] as String? ?? 'TEXT'),
      isRequired: json['isRequired'] as bool? ?? false,
      defaultValue: json['defaultValue'] as String?,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      validationRegex: json['validationRegex'] as String?,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      showInGrid: json['showInGrid'] as bool? ?? false,
      showInPdf: json['showInPdf'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entityType': entityType,
      'fieldName': fieldName,
      'fieldLabel': fieldLabel,
      'fieldType': fieldType.name.toUpperCase(),
      'isRequired': isRequired,
      'defaultValue': defaultValue,
      'options': options,
      'validationRegex': validationRegex,
      'sortOrder': sortOrder,
      'isActive': isActive,
      'showInGrid': showInGrid,
      'showInPdf': showInPdf,
    };
  }
}

@immutable
class CustomFieldValueDTO {
  final String fieldDefinitionId;
  final String fieldName;
  final String fieldLabel;
  final FieldType fieldType;
  final bool isRequired;
  final List<String> options;
  final bool showInGrid;
  final bool showInPdf;
  final int sortOrder;
  final String? valueText;
  final double? valueNumber;
  final String? valueDate;
  final bool? valueBoolean;

  const CustomFieldValueDTO({
    required this.fieldDefinitionId,
    required this.fieldName,
    required this.fieldLabel,
    required this.fieldType,
    required this.isRequired,
    this.options = const [],
    required this.showInGrid,
    required this.showInPdf,
    required this.sortOrder,
    this.valueText,
    this.valueNumber,
    this.valueDate,
    this.valueBoolean,
  });

  factory CustomFieldValueDTO.fromJson(Map<String, dynamic> json) {
    return CustomFieldValueDTO(
      fieldDefinitionId: json['fieldDefinitionId'] as String? ?? '',
      fieldName: json['fieldName'] as String? ?? '',
      fieldLabel: json['fieldLabel'] as String? ?? '',
      fieldType: FieldType.fromString(json['fieldType'] as String? ?? 'TEXT'),
      isRequired: json['isRequired'] as bool? ?? false,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      showInGrid: json['showInGrid'] as bool? ?? false,
      showInPdf: json['showInPdf'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
      valueText: json['valueText'] as String?,
      valueNumber: (json['valueNumber'] as num?)?.toDouble(),
      valueDate: json['valueDate'] as String?,
      valueBoolean: json['valueBoolean'] as bool?,
    );
  }

  String get displayValue {
    if (valueText != null && valueText!.isNotEmpty) {
      return valueText!;
    }
    if (valueNumber != null) {
      return valueNumber.toString();
    }
    if (valueDate != null) {
      return valueDate!;
    }
    if (valueBoolean != null) {
      return valueBoolean! ? 'Yes' : 'No';
    }
    return '-';
  }
}

class CustomFieldValueInput {
  final String? fieldDefinitionId;
  final String? fieldName;
  final String? value;

  const CustomFieldValueInput({
    this.fieldDefinitionId,
    this.fieldName,
    this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      if (fieldDefinitionId != null) 'fieldDefinitionId': fieldDefinitionId,
      if (fieldName != null) 'fieldName': fieldName,
      'value': value ?? '',
    };
  }
}
