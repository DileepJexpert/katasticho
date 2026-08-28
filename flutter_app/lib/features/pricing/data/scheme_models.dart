enum SchemeType {
  buyXGetY('BUY_X_GET_Y', 'Buy X Get Y Free (10+1)'),
  percentDiscount('PERCENT_DISCOUNT', 'Percentage Trade Discount'),
  halfFullScheme('HALF_FULL_SCHEME', 'Half / Full Slab Scheme'),
  specialNetRate('SPECIAL_NET_RATE', 'Special Company Net Rate');

  final String code;
  final String label;
  const SchemeType(this.code, this.label);

  static SchemeType fromCode(String? code) {
    return SchemeType.values.firstWhere(
      (e) => e.code == (code ?? '').toUpperCase(),
      orElse: () => SchemeType.percentDiscount,
    );
  }
}

class SchemeModel {
  final String id;
  final String name;
  final String schemeType;
  final String? itemId;
  final String? itemName;
  final double? buyQuantity;
  final double? freeQuantity;
  final double? discountPercent;
  final double minOrderQuantity;
  final String? validFrom;
  final String? validTo;
  final String? supplierId;
  final String? supplierName;
  final bool active;
  final bool allowHalfScheme;
  final double? halfSchemeMinQty;
  final double companySubsidyPercent;
  final double? specialNetRate;
  final double? maxFreeQuantityCap;

  const SchemeModel({
    required this.id,
    required this.name,
    required this.schemeType,
    this.itemId,
    this.itemName,
    this.buyQuantity,
    this.freeQuantity,
    this.discountPercent,
    this.minOrderQuantity = 0.0,
    this.validFrom,
    this.validTo,
    this.supplierId,
    this.supplierName,
    this.active = true,
    this.allowHalfScheme = true,
    this.halfSchemeMinQty,
    this.companySubsidyPercent = 100.0,
    this.specialNetRate,
    this.maxFreeQuantityCap,
  });

  factory SchemeModel.fromJson(Map<String, dynamic> json) {
    return SchemeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      schemeType: json['schemeType']?.toString() ?? 'PERCENT_DISCOUNT',
      itemId: json['itemId']?.toString(),
      itemName: json['itemName']?.toString(),
      buyQuantity: (json['buyQuantity'] as num?)?.toDouble(),
      freeQuantity: (json['freeQuantity'] as num?)?.toDouble(),
      discountPercent: (json['discountPercent'] as num?)?.toDouble(),
      minOrderQuantity: (json['minOrderQuantity'] as num?)?.toDouble() ?? 0.0,
      validFrom: json['validFrom']?.toString(),
      validTo: json['validTo']?.toString(),
      supplierId: json['supplierId']?.toString(),
      supplierName: json['supplierName']?.toString(),
      active: json['active'] == true,
      allowHalfScheme: json['allowHalfScheme'] != false,
      halfSchemeMinQty: (json['halfSchemeMinQty'] as num?)?.toDouble(),
      companySubsidyPercent: (json['companySubsidyPercent'] as num?)?.toDouble() ?? 100.0,
      specialNetRate: (json['specialNetRate'] as num?)?.toDouble(),
      maxFreeQuantityCap: (json['maxFreeQuantityCap'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'schemeType': schemeType,
        if (itemId != null) 'itemId': itemId,
        if (buyQuantity != null) 'buyQuantity': buyQuantity,
        if (freeQuantity != null) 'freeQuantity': freeQuantity,
        if (discountPercent != null) 'discountPercent': discountPercent,
        'minOrderQuantity': minOrderQuantity,
        if (validFrom != null) 'validFrom': validFrom,
        if (validTo != null) 'validTo': validTo,
        if (supplierId != null) 'supplierId': supplierId,
        'active': active,
        'allowHalfScheme': allowHalfScheme,
        if (halfSchemeMinQty != null) 'halfSchemeMinQty': halfSchemeMinQty,
        'companySubsidyPercent': companySubsidyPercent,
        if (specialNetRate != null) 'specialNetRate': specialNetRate,
        if (maxFreeQuantityCap != null) 'maxFreeQuantityCap': maxFreeQuantityCap,
      };
}

class SchemeCalculationResult {
  final String? schemeId;
  final String? schemeName;
  final String schemeType;
  final double orderedQuantity;
  final double freeQuantity;
  final double discountPercent;
  final double discountAmount;
  final double baseUnitPrice;
  final double effectiveUnitPrice;
  final double totalLineAmount;
  final double companyFundedAmount;
  final double distributorFundedAmount;
  final bool isHalfSchemeApplied;
  final String explanation;

  const SchemeCalculationResult({
    this.schemeId,
    this.schemeName,
    required this.schemeType,
    required this.orderedQuantity,
    this.freeQuantity = 0.0,
    this.discountPercent = 0.0,
    this.discountAmount = 0.0,
    required this.baseUnitPrice,
    required this.effectiveUnitPrice,
    required this.totalLineAmount,
    this.companyFundedAmount = 0.0,
    this.distributorFundedAmount = 0.0,
    this.isHalfSchemeApplied = false,
    this.explanation = '',
  });

  factory SchemeCalculationResult.fromJson(Map<String, dynamic> json) {
    return SchemeCalculationResult(
      schemeId: json['schemeId']?.toString(),
      schemeName: json['schemeName']?.toString(),
      schemeType: json['schemeType']?.toString() ?? 'NONE',
      orderedQuantity: (json['orderedQuantity'] as num?)?.toDouble() ?? 0.0,
      freeQuantity: (json['freeQuantity'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      baseUnitPrice: (json['baseUnitPrice'] as num?)?.toDouble() ?? 0.0,
      effectiveUnitPrice: (json['effectiveUnitPrice'] as num?)?.toDouble() ?? 0.0,
      totalLineAmount: (json['totalLineAmount'] as num?)?.toDouble() ?? 0.0,
      companyFundedAmount: (json['companyFundedAmount'] as num?)?.toDouble() ?? 0.0,
      distributorFundedAmount: (json['distributorFundedAmount'] as num?)?.toDouble() ?? 0.0,
      isHalfSchemeApplied: json['isHalfSchemeApplied'] == true,
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}
