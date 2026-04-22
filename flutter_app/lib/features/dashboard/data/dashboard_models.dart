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
  final double totalSales;
  final double cashUpiTotal;
  final double creditTotal;
  final int transactionCount;
  final String currency;
  final List<BranchSalesRow> byBranch;

  const TodaySalesData({
    required this.from,
    required this.to,
    required this.branchFilter,
    required this.totalSales,
    required this.cashUpiTotal,
    required this.creditTotal,
    required this.transactionCount,
    required this.currency,
    required this.byBranch,
  });

  factory TodaySalesData.fromJson(Map<String, dynamic> json) => TodaySalesData(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        branchFilter: json['branchFilter']?.toString(),
        totalSales: (json['totalSales'] as num?)?.toDouble() ?? 0.0,
        cashUpiTotal: (json['cashUpiTotal'] as num?)?.toDouble() ?? 0.0,
        creditTotal: (json['creditTotal'] as num?)?.toDouble() ?? 0.0,
        transactionCount: (json['transactionCount'] as num?)?.toInt() ?? 0,
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

/// AR aging breakdown for the expandable receivables card.
class ArAgingData {
  final double totalOutstanding;
  final double current;
  final double days1to30;
  final double days31to60;
  final double days61to90;
  final double days90plus;

  const ArAgingData({
    required this.totalOutstanding,
    required this.current,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.days90plus,
  });

  factory ArAgingData.fromJson(Map<String, dynamic> json) => ArAgingData(
        totalOutstanding:
            (json['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
        current: (json['current'] as num?)?.toDouble() ?? 0.0,
        days1to30: (json['days1to30'] as num?)?.toDouble() ?? 0.0,
        days31to60: (json['days31to60'] as num?)?.toDouble() ?? 0.0,
        days61to90: (json['days61to90'] as num?)?.toDouble() ?? 0.0,
        days90plus: (json['days90plus'] as num?)?.toDouble() ?? 0.0,
      );
}

/// AP aging breakdown for the expandable payables card.
class ApAgingData {
  final double totalOutstanding;
  final double current;
  final double days1to30;
  final double days31to60;
  final double days61to90;
  final double days90plus;

  const ApAgingData({
    required this.totalOutstanding,
    required this.current,
    required this.days1to30,
    required this.days31to60,
    required this.days61to90,
    required this.days90plus,
  });

  factory ApAgingData.fromJson(Map<String, dynamic> json) => ApAgingData(
        totalOutstanding:
            (json['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
        current: (json['current'] as num?)?.toDouble() ?? 0.0,
        days1to30: (json['days1to30'] as num?)?.toDouble() ?? 0.0,
        days31to60: (json['days31to60'] as num?)?.toDouble() ?? 0.0,
        days61to90: (json['days61to90'] as num?)?.toDouble() ?? 0.0,
        days90plus: (json['days90plus'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Daily revenue point for the trend chart.
class DailyRevenue {
  final DateTime date;
  final double revenue;

  const DailyRevenue({required this.date, required this.revenue});

  factory DailyRevenue.fromJson(Map<String, dynamic> json) => DailyRevenue(
        date: DateTime.parse(json['date'] as String),
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Revenue trend for the bar chart widget.
class RevenueTrendData {
  final DateTime from;
  final DateTime to;
  final int days;
  final double totalRevenue;
  final String currency;
  final List<DailyRevenue> trend;

  const RevenueTrendData({
    required this.from,
    required this.to,
    required this.days,
    required this.totalRevenue,
    required this.currency,
    required this.trend,
  });

  factory RevenueTrendData.fromJson(Map<String, dynamic> json) =>
      RevenueTrendData(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        days: (json['days'] as num?)?.toInt() ?? 30,
        totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency']?.toString() ?? 'INR',
        trend: ((json['trend'] as List?) ?? const [])
            .map((e) => DailyRevenue.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// AR summary for the dashboard — total outstanding receivables, overdue
/// invoice count, invoices due in the next 7 days.
class ArSummaryData {
  final double totalOutstanding;
  final int overdueCount;
  final double dueThisWeek;
  final int dueThisWeekCount;
  final String currency;

  const ArSummaryData({
    required this.totalOutstanding,
    required this.overdueCount,
    required this.dueThisWeek,
    required this.dueThisWeekCount,
    required this.currency,
  });

  factory ArSummaryData.fromJson(Map<String, dynamic> json) => ArSummaryData(
        totalOutstanding:
            (json['totalOutstanding'] as num?)?.toDouble() ?? 0.0,
        overdueCount: (json['overdueCount'] as num?)?.toInt() ?? 0,
        dueThisWeek: (json['dueThisWeek'] as num?)?.toDouble() ?? 0.0,
        dueThisWeekCount: (json['dueThisWeekCount'] as num?)?.toInt() ?? 0,
        currency: json['currency']?.toString() ?? 'INR',
      );
}

/// Monthly profit (revenue − COGS) for the dashboard tile.
class MonthlyProfitData {
  final DateTime from;
  final DateTime to;
  final double revenue;
  final double cogs;
  final double grossProfit;
  final String currency;

  const MonthlyProfitData({
    required this.from,
    required this.to,
    required this.revenue,
    required this.cogs,
    required this.grossProfit,
    required this.currency,
  });

  factory MonthlyProfitData.fromJson(Map<String, dynamic> json) =>
      MonthlyProfitData(
        from: DateTime.parse(json['from'] as String),
        to: DateTime.parse(json['to'] as String),
        revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
        cogs: (json['cogs'] as num?)?.toDouble() ?? 0.0,
        grossProfit: (json['grossProfit'] as num?)?.toDouble() ?? 0.0,
        currency: json['currency']?.toString() ?? 'INR',
      );
}

class DailySummaryData {
  final TodaySnapshot today;
  final List<DailySummaryRow> daily;
  final WeekComparison thisWeek;
  final String currency;

  const DailySummaryData({
    required this.today,
    required this.daily,
    required this.thisWeek,
    required this.currency,
  });

  factory DailySummaryData.fromJson(Map<String, dynamic> json) =>
      DailySummaryData(
        today: TodaySnapshot.fromJson(
            json['today'] as Map<String, dynamic>? ?? const {}),
        daily: ((json['daily'] as List?) ?? const [])
            .map((e) => DailySummaryRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        thisWeek: WeekComparison.fromJson(
            json['thisWeek'] as Map<String, dynamic>? ?? const {}),
        currency: json['currency']?.toString() ?? 'INR',
      );
}

class TodaySnapshot {
  final double totalSale;
  final double totalCost;
  final double earning;
  final double cashUpiIn;
  final double creditSale;
  final int billCount;

  const TodaySnapshot({
    required this.totalSale,
    required this.totalCost,
    required this.earning,
    required this.cashUpiIn,
    required this.creditSale,
    required this.billCount,
  });

  factory TodaySnapshot.fromJson(Map<String, dynamic> json) => TodaySnapshot(
        totalSale: (json['totalSale'] as num?)?.toDouble() ?? 0.0,
        totalCost: (json['totalCost'] as num?)?.toDouble() ?? 0.0,
        earning: (json['earning'] as num?)?.toDouble() ?? 0.0,
        cashUpiIn: (json['cashUpiIn'] as num?)?.toDouble() ?? 0.0,
        creditSale: (json['creditSale'] as num?)?.toDouble() ?? 0.0,
        billCount: (json['billCount'] as num?)?.toInt() ?? 0,
      );
}

class DailySummaryRow {
  final DateTime date;
  final double sale;
  final double cost;
  final double earning;

  const DailySummaryRow({
    required this.date,
    required this.sale,
    required this.cost,
    required this.earning,
  });

  factory DailySummaryRow.fromJson(Map<String, dynamic> json) =>
      DailySummaryRow(
        date: DateTime.parse(json['date'] as String),
        sale: (json['sale'] as num?)?.toDouble() ?? 0.0,
        cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
        earning: (json['earning'] as num?)?.toDouble() ?? 0.0,
      );
}

class WeekComparison {
  final double totalSale;
  final double totalEarning;
  final double vsLastWeekSalePct;
  final double vsLastWeekEarningPct;

  const WeekComparison({
    required this.totalSale,
    required this.totalEarning,
    required this.vsLastWeekSalePct,
    required this.vsLastWeekEarningPct,
  });

  factory WeekComparison.fromJson(Map<String, dynamic> json) =>
      WeekComparison(
        totalSale: (json['totalSale'] as num?)?.toDouble() ?? 0.0,
        totalEarning: (json['totalEarning'] as num?)?.toDouble() ?? 0.0,
        vsLastWeekSalePct:
            (json['vsLastWeekSalePct'] as num?)?.toDouble() ?? 0.0,
        vsLastWeekEarningPct:
            (json['vsLastWeekEarningPct'] as num?)?.toDouble() ?? 0.0,
      );
}

class ExpiringSoonItem {
  final String itemId;
  final String itemName;
  final String? sku;
  final String batchNumber;
  final DateTime expiryDate;
  final int daysLeft;
  final double quantityOnHand;

  const ExpiringSoonItem({
    required this.itemId,
    required this.itemName,
    required this.sku,
    required this.batchNumber,
    required this.expiryDate,
    required this.daysLeft,
    required this.quantityOnHand,
  });

  factory ExpiringSoonItem.fromJson(Map<String, dynamic> json) =>
      ExpiringSoonItem(
        itemId: json['itemId']?.toString() ?? '',
        itemName: json['itemName']?.toString() ?? '',
        sku: json['sku']?.toString(),
        batchNumber: json['batchNumber']?.toString() ?? '',
        expiryDate: DateTime.parse(json['expiryDate'] as String),
        daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 0,
        quantityOnHand:
            (json['quantityOnHand'] as num?)?.toDouble() ?? 0.0,
      );
}
