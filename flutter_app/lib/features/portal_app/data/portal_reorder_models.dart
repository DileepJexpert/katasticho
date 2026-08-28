class PortalCatalogItem {
  final String id;
  final String name;
  final String sku;
  final String? brand;
  final String? category;
  final String? composition;
  final String? packSize;
  final String unitOfMeasure;
  final double mrp;
  final double salePrice;
  final double gstRate;
  final bool trackInventory;
  final bool inStock;
  final double stockQuantity;
  final String? schemeDescription;
  final String? schemeType;
  final double schemeDiscountPercent;

  const PortalCatalogItem({
    required this.id,
    required this.name,
    required this.sku,
    this.brand,
    this.category,
    this.composition,
    this.packSize,
    required this.unitOfMeasure,
    required this.mrp,
    required this.salePrice,
    required this.gstRate,
    required this.trackInventory,
    required this.inStock,
    required this.stockQuantity,
    this.schemeDescription,
    this.schemeType,
    this.schemeDiscountPercent = 0.0,
  });

  factory PortalCatalogItem.fromJson(Map<String, dynamic> json) {
    return PortalCatalogItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      brand: json['brand'] as String?,
      category: json['category'] as String?,
      composition: json['composition'] as String?,
      packSize: json['packSize'] as String?,
      unitOfMeasure: (json['unitOfMeasure'] ?? 'PCS').toString(),
      mrp: _toDouble(json['mrp']),
      salePrice: _toDouble(json['salePrice']),
      gstRate: _toDouble(json['gstRate']),
      trackInventory: json['trackInventory'] as bool? ?? true,
      inStock: json['inStock'] as bool? ?? true,
      stockQuantity: _toDouble(json['stockQuantity']),
      schemeDescription: json['schemeDescription'] as String?,
      schemeType: json['schemeType'] as String?,
      schemeDiscountPercent: _toDouble(json['schemeDiscountPercent']),
    );
  }

  static double _toDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }
}

class PortalCartItem {
  final PortalCatalogItem item;
  double quantity;

  PortalCartItem({
    required this.item,
    required this.quantity,
  });

  double get unitEffectiveRate {
    if (item.schemeDiscountPercent > 0) {
      return item.salePrice * (1.0 - (item.schemeDiscountPercent / 100.0));
    }
    return item.salePrice;
  }

  double get lineSubtotal => unitEffectiveRate * quantity;

  double get lineTax => lineSubtotal * (item.gstRate / 100.0);

  double get lineTotal => lineSubtotal + lineTax;

  double get mrpSavings {
    if (item.mrp > item.salePrice) {
      return (item.mrp - unitEffectiveRate) * quantity;
    }
    return (item.salePrice - unitEffectiveRate) * quantity;
  }
}

class PortalOrderLineSummary {
  final String id;
  final String? itemId;
  final String description;
  final double quantity;
  final double quantityShipped;
  final double quantityInvoiced;
  final String? unit;
  final double rate;
  final double discountPct;
  final double taxRate;
  final double amount;

  const PortalOrderLineSummary({
    required this.id,
    this.itemId,
    required this.description,
    required this.quantity,
    required this.quantityShipped,
    required this.quantityInvoiced,
    this.unit,
    required this.rate,
    required this.discountPct,
    required this.taxRate,
    required this.amount,
  });

  factory PortalOrderLineSummary.fromJson(Map<String, dynamic> json) {
    return PortalOrderLineSummary(
      id: (json['id'] ?? '').toString(),
      itemId: json['itemId']?.toString(),
      description: (json['description'] ?? '').toString(),
      quantity: PortalCatalogItem._toDouble(json['quantity']),
      quantityShipped: PortalCatalogItem._toDouble(json['quantityShipped']),
      quantityInvoiced: PortalCatalogItem._toDouble(json['quantityInvoiced']),
      unit: json['unit'] as String?,
      rate: PortalCatalogItem._toDouble(json['rate']),
      discountPct: PortalCatalogItem._toDouble(json['discountPct']),
      taxRate: PortalCatalogItem._toDouble(json['taxRate']),
      amount: PortalCatalogItem._toDouble(json['amount']),
    );
  }
}

class PortalOrderSummary {
  final String id;
  final String number;
  final String? referenceNumber;
  final String date;
  final String? expectedShipmentDate;
  final double total;
  final double subtotal;
  final double taxAmount;
  final String status;
  final String shippedStatus;
  final String invoicedStatus;
  final int itemCount;
  final String? notes;
  final List<PortalOrderLineSummary> lines;

  const PortalOrderSummary({
    required this.id,
    required this.number,
    this.referenceNumber,
    required this.date,
    this.expectedShipmentDate,
    required this.total,
    required this.subtotal,
    required this.taxAmount,
    required this.status,
    required this.shippedStatus,
    required this.invoicedStatus,
    required this.itemCount,
    this.notes,
    this.lines = const [],
  });

  factory PortalOrderSummary.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List?;
    final parsedLines = rawLines != null
        ? rawLines.map((e) => PortalOrderLineSummary.fromJson((e as Map).cast<String, dynamic>())).toList()
        : <PortalOrderLineSummary>[];

    return PortalOrderSummary(
      id: (json['id'] ?? '').toString(),
      number: (json['number'] ?? '—').toString(),
      referenceNumber: json['referenceNumber'] as String?,
      date: (json['date'] ?? '').toString(),
      expectedShipmentDate: json['expectedShipmentDate'] as String?,
      total: PortalCatalogItem._toDouble(json['total']),
      subtotal: PortalCatalogItem._toDouble(json['subtotal']),
      taxAmount: PortalCatalogItem._toDouble(json['taxAmount']),
      status: (json['status'] ?? 'DRAFT').toString(),
      shippedStatus: (json['shippedStatus'] ?? 'NOT_SHIPPED').toString(),
      invoicedStatus: (json['invoicedStatus'] ?? 'NOT_INVOICED').toString(),
      itemCount: json['itemCount'] is int ? json['itemCount'] as int : parsedLines.length,
      notes: json['notes'] as String?,
      lines: parsedLines,
    );
  }
}
