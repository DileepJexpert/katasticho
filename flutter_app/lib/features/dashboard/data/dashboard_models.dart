/// Plain-value models for the dashboard aggregation endpoints.
///
/// These are deliberately thin — no code generation, no freezed — because
/// every dashboard call is read-only and small. The `fromJson` factories
/// are defensive: backend envelopes vary between `{data: {...}}` and
/// raw-payload shapes so the repository layer unwraps once and hands
/// clean maps to these constructors.

class BranchSalesRow {
  final String branchId;
  final String branchCode;
  final String branchName;
  final double revenue;
  final double sharePercent;

  const BranchSalesRow({
    required this.branchId,
    required this.branchCode,
    required this.branchName,
    required this.revenue,
    required this.sharePercent,
  });

  factory BranchSalesRow.fromJson(Map<String, dynamic> json) => BranchSalesRow(
        branchId: json['branchId']?.toString() ?? '',
        branchCode: json['branchCode']?.toString() ?? '',
        branchName: json['branchName']?.toString() ?? '',
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
        sharePercent: (json['sharePercent'] as num?)?.toDouble() ?? 0.0,
      );
}

class TodaySalesData {
  final DateTime from;
  final DateTime to;
  final String? branchFilter;
  final double revenue;
  final double cashCollected;
  final String currency;
  final List<BranchSalesRow> byBranch;

  const TodaySalesData({
    required this.from,
    required this.to,
    required this.branchFilter,
    required this.revenue,
    required this.cashCollected,
    required this.currency,
    required this.byBranch,
  });

  factory TodaySalesData.fromJson(Map<String, dynamic> json) => TodaySalesData(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        branchFilter: json['branchFilter']?.toString(),
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
        cashCollected: (json['cashCollected'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency']?.toString() ?? 'INR',
        byBranch: ((json['byBranch'] as List?) ?? const [])
            .map((e) => BranchSalesRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TopSellingItem {
  final int rank;
  final String itemId;
  final String? sku;
  final String name;
  final String? unit;
  final double quantity;
  final double revenue;

  const TopSellingItem({
    required this.rank,
    required this.itemId,
    required this.sku,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.revenue,
  });

  factory TopSellingItem.fromJson(Map<String, dynamic> json) => TopSellingItem(
        rank: (json['rank'] as num?)?.toInt() ?? 0,
        itemId: json['itemId']?.toString() ?? '',
        sku: json['sku']?.toString(),
        name: json['name']?.toString() ?? '',
        unit: json['unit']?.toString(),
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0.0,
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      );
}

class BranchSummary {
  final String id;
  final String code;
  final String name;
  final bool isDefault;
  final bool active;

  const BranchSummary({
    required this.id,
    required this.code,
    required this.name,
    required this.isDefault,
    required this.active,
  });

  factory BranchSummary.fromJson(Map<String, dynamic> json) => BranchSummary(
        id: json['id']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        isDefault: json['isDefault'] as bool? ?? false,
        active: json['active'] as bool? ?? true,
      );
}
