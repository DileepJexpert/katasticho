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

/// AP summary for the dashboard — total outstanding payables, overdue count,
/// bills due within the next 7 days.
class ApSummaryData {
  final double totalOutstanding;
  final int overdueCount;
  final double dueThisWeek;
  final int dueThisWeekCount;
  final List<BranchPurchaseRow> byBranch;

  const ApSummaryData({
    required this.totalOutstanding,
    required this.overdueCount,
    required this.dueThisWeek,
    required this.dueThisWeekCount,
    required this.byBranch,
  });

  factory ApSummaryData.fromJson(Map<String, dynamic> json) => ApSummaryData(
        totalOutstanding:
            (json['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
        overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
        dueThisWeek: (json['dueThisWeek'] as num?)?.toDouble() ?? 0.0,
        dueThisWeekCount:
            (json['dueThisWeekCount'] as num?)?.toInt() ?? 0,
        byBranch: ((json['byBranch'] as List?) ?? const [])
            .map((e) =>
                BranchPurchaseRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class BranchPurchaseRow {
  final String branchId;
  final String branchCode;
  final String branchName;
  final double purchases;
  final double sharePercent;

  const BranchPurchaseRow({
    required this.branchId,
    required this.branchCode,
    required this.branchName,
    required this.purchases,
    required this.sharePercent,
  });

  factory BranchPurchaseRow.fromJson(Map<String, dynamic> json) =>
      BranchPurchaseRow(
        branchId: json['branchId']?.toString() ?? '',
        branchCode: json['branchCode']?.toString() ?? '',
        branchName: json['branchName']?.toString() ?? '',
        purchases: (json['purchases'] as num?)?.toDouble() ?? 0.0,
        sharePercent: (json['sharePercent'] as num?)?.toDouble() ?? 0.0,
      );
}

/// A recent bill for the dashboard activity feed.
class RecentBillData {
  final String id;
  final String billNumber;
  final String vendorName;
  final String status;
  final double totalAmount;
  final String billDate;

  const RecentBillData({
    required this.id,
    required this.billNumber,
    required this.vendorName,
    required this.status,
    required this.totalAmount,
    required this.billDate,
  });

  factory RecentBillData.fromJson(Map<String, dynamic> json) =>
      RecentBillData(
        id: json['id']?.toString() ?? '',
        billNumber: json['billNumber']?.toString() ?? '--',
        vendorName: json['vendorName']?.toString() ?? 'Unknown',
        status: json['status']?.toString() ?? 'DRAFT',
        totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
        billDate: json['billDate']?.toString() ?? '',
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
