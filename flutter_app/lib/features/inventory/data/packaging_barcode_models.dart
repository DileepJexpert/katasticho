class PackagingBarcodeModel {
  final String id;
  final String itemId;
  final String itemName;
  final String itemSku;
  final String barcode;
  final String packagingLevel;
  final String? packagingName;
  final double conversionFactor;
  final String? uomName;
  final double? mrp;
  final double? salePrice;
  final double? purchasePrice;
  final bool isPrimary;
  final String? notes;

  const PackagingBarcodeModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemSku,
    required this.barcode,
    required this.packagingLevel,
    this.packagingName,
    this.conversionFactor = 1.0,
    this.uomName,
    this.mrp,
    this.salePrice,
    this.purchasePrice,
    this.isPrimary = false,
    this.notes,
  });

  factory PackagingBarcodeModel.fromJson(Map<String, dynamic> json) {
    return PackagingBarcodeModel(
      id: json['id']?.toString() ?? '',
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      itemSku: json['itemSku']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
      packagingLevel: json['packagingLevel']?.toString() ?? 'UNIT',
      packagingName: json['packagingName']?.toString(),
      conversionFactor: (json['conversionFactor'] as num?)?.toDouble() ?? 1.0,
      uomName: json['uomName']?.toString(),
      mrp: (json['mrp'] as num?)?.toDouble(),
      salePrice: (json['salePrice'] as num?)?.toDouble(),
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
      isPrimary: json['isPrimary'] == true,
      notes: json['notes']?.toString(),
    );
  }
}

class ResolvedBarcodeModel {
  final String itemId;
  final String itemName;
  final String sku;
  final String? itemBarcode;
  final String scannedBarcode;
  final String packagingLevel;
  final String packagingName;
  final double conversionFactor;
  final double quantityMultiplier;
  final double unitPrice;
  final String uomName;
  final bool isHierarchyMatch;

  const ResolvedBarcodeModel({
    required this.itemId,
    required this.itemName,
    required this.sku,
    this.itemBarcode,
    required this.scannedBarcode,
    required this.packagingLevel,
    required this.packagingName,
    required this.conversionFactor,
    required this.quantityMultiplier,
    required this.unitPrice,
    required this.uomName,
    required this.isHierarchyMatch,
  });

  factory ResolvedBarcodeModel.fromJson(Map<String, dynamic> json) {
    return ResolvedBarcodeModel(
      itemId: json['itemId']?.toString() ?? '',
      itemName: json['itemName']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      itemBarcode: json['itemBarcode']?.toString(),
      scannedBarcode: json['scannedBarcode']?.toString() ?? '',
      packagingLevel: json['packagingLevel']?.toString() ?? 'UNIT',
      packagingName: json['packagingName']?.toString() ?? 'Base Unit',
      conversionFactor: (json['conversionFactor'] as num?)?.toDouble() ?? 1.0,
      quantityMultiplier: (json['quantityMultiplier'] as num?)?.toDouble() ?? 1.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      uomName: json['uomName']?.toString() ?? 'PCS',
      isHierarchyMatch: json['isHierarchyMatch'] == true,
    );
  }
}

class CreatePackagingBarcodeRequest {
  final String barcode;
  final String packagingLevel;
  final String? packagingName;
  final double conversionFactor;
  final String? uomName;
  final double? mrp;
  final double? salePrice;
  final double? purchasePrice;
  final bool isPrimary;
  final String? notes;

  const CreatePackagingBarcodeRequest({
    required this.barcode,
    this.packagingLevel = 'UNIT',
    this.packagingName,
    this.conversionFactor = 1.0,
    this.uomName,
    this.mrp,
    this.salePrice,
    this.purchasePrice,
    this.isPrimary = false,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'packagingLevel': packagingLevel,
        if (packagingName != null) 'packagingName': packagingName,
        'conversionFactor': conversionFactor,
        if (uomName != null) 'uomName': uomName,
        if (mrp != null) 'mrp': mrp,
        if (salePrice != null) 'salePrice': salePrice,
        if (purchasePrice != null) 'purchasePrice': purchasePrice,
        'isPrimary': isPrimary,
        if (notes != null) 'notes': notes,
      };
}
