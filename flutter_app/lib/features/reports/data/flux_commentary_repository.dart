import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

class AccountFluxLineModel {
  final String accountId;
  final String accountCode;
  final String accountName;
  final String accountType;
  final double basePeriodAmount;
  final double comparisonPeriodAmount;
  final double varianceAmount;
  final double variancePercent;
  final String fluxDriver;
  final bool isMaterial;
  final String commentary;

  AccountFluxLineModel({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.accountType,
    required this.basePeriodAmount,
    required this.comparisonPeriodAmount,
    required this.varianceAmount,
    required this.variancePercent,
    required this.fluxDriver,
    required this.isMaterial,
    required this.commentary,
  });

  factory AccountFluxLineModel.fromJson(Map<String, dynamic> json) {
    return AccountFluxLineModel(
      accountId: json['accountId']?.toString() ?? '',
      accountCode: json['accountCode']?.toString() ?? '--',
      accountName: json['accountName']?.toString() ?? '',
      accountType: json['accountType']?.toString() ?? 'EXPENSE',
      basePeriodAmount: (json['basePeriodAmount'] as num?)?.toDouble() ?? 0.0,
      comparisonPeriodAmount: (json['comparisonPeriodAmount'] as num?)?.toDouble() ?? 0.0,
      varianceAmount: (json['varianceAmount'] as num?)?.toDouble() ?? 0.0,
      variancePercent: (json['variancePercent'] as num?)?.toDouble() ?? 0.0,
      fluxDriver: json['fluxDriver']?.toString() ?? 'NORMAL_VARIANCE',
      isMaterial: json['material'] == true,
      commentary: json['commentary']?.toString() ?? '',
    );
  }
}

class FinancialFluxReportModel {
  final String periodType;
  final String basePeriodLabel;
  final String? baseStartDate;
  final String? baseEndDate;
  final String comparisonPeriodLabel;
  final String? comparisonStartDate;
  final String? comparisonEndDate;
  final String currency;

  final double totalRevenueBase;
  final double totalRevenueComp;
  final double revenueVarianceAmount;
  final double revenueVariancePercent;

  final double totalExpenseBase;
  final double totalExpenseComp;
  final double expenseVarianceAmount;
  final double expenseVariancePercent;

  final double netProfitBase;
  final double netProfitComp;
  final double netProfitVarianceAmount;
  final double netProfitVariancePercent;

  final List<AccountFluxLineModel> topDrivers;
  final List<AccountFluxLineModel> accountLines;
  final String executiveSummary;

  FinancialFluxReportModel({
    required this.periodType,
    required this.basePeriodLabel,
    this.baseStartDate,
    this.baseEndDate,
    required this.comparisonPeriodLabel,
    this.comparisonStartDate,
    this.comparisonEndDate,
    required this.currency,
    required this.totalRevenueBase,
    required this.totalRevenueComp,
    required this.revenueVarianceAmount,
    required this.revenueVariancePercent,
    required this.totalExpenseBase,
    required this.totalExpenseComp,
    required this.expenseVarianceAmount,
    required this.expenseVariancePercent,
    required this.netProfitBase,
    required this.netProfitComp,
    required this.netProfitVarianceAmount,
    required this.netProfitVariancePercent,
    required this.topDrivers,
    required this.accountLines,
    required this.executiveSummary,
  });

  factory FinancialFluxReportModel.fromJson(Map<String, dynamic> json) {
    return FinancialFluxReportModel(
      periodType: json['periodType']?.toString() ?? 'MOM',
      basePeriodLabel: json['basePeriodLabel']?.toString() ?? 'Base Period',
      baseStartDate: json['baseStartDate']?.toString(),
      baseEndDate: json['baseEndDate']?.toString(),
      comparisonPeriodLabel: json['comparisonPeriodLabel']?.toString() ?? 'Comparison Period',
      comparisonStartDate: json['comparisonStartDate']?.toString(),
      comparisonEndDate: json['comparisonEndDate']?.toString(),
      currency: json['currency']?.toString() ?? 'INR',
      totalRevenueBase: (json['totalRevenueBase'] as num?)?.toDouble() ?? 0.0,
      totalRevenueComp: (json['totalRevenueComp'] as num?)?.toDouble() ?? 0.0,
      revenueVarianceAmount: (json['revenueVarianceAmount'] as num?)?.toDouble() ?? 0.0,
      revenueVariancePercent: (json['revenueVariancePercent'] as num?)?.toDouble() ?? 0.0,
      totalExpenseBase: (json['totalExpenseBase'] as num?)?.toDouble() ?? 0.0,
      totalExpenseComp: (json['totalExpenseComp'] as num?)?.toDouble() ?? 0.0,
      expenseVarianceAmount: (json['expenseVarianceAmount'] as num?)?.toDouble() ?? 0.0,
      expenseVariancePercent: (json['expenseVariancePercent'] as num?)?.toDouble() ?? 0.0,
      netProfitBase: (json['netProfitBase'] as num?)?.toDouble() ?? 0.0,
      netProfitComp: (json['netProfitComp'] as num?)?.toDouble() ?? 0.0,
      netProfitVarianceAmount: (json['netProfitVarianceAmount'] as num?)?.toDouble() ?? 0.0,
      netProfitVariancePercent: (json['netProfitVariancePercent'] as num?)?.toDouble() ?? 0.0,
      topDrivers: (json['topDrivers'] as List? ?? [])
          .map((item) => AccountFluxLineModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      accountLines: (json['accountLines'] as List? ?? [])
          .map((item) => AccountFluxLineModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      executiveSummary: json['executiveSummary']?.toString() ?? '',
    );
  }
}

class FluxCommentaryRepository {
  final ApiClient _client;
  FluxCommentaryRepository(this._client);

  Future<FinancialFluxReportModel> getFluxReport({
    String periodType = 'MOM',
    String? baseStart,
    String? baseEnd,
    String? compStart,
    String? compEnd,
    double? minMaterialAmount,
    double? minMaterialPercent,
  }) async {
    final queryParams = <String, dynamic>{
      'periodType': periodType,
    };
    if (baseStart != null) queryParams['baseStart'] = baseStart;
    if (baseEnd != null) queryParams['baseEnd'] = baseEnd;
    if (compStart != null) queryParams['compStart'] = compStart;
    if (compEnd != null) queryParams['compEnd'] = compEnd;
    if (minMaterialAmount != null) queryParams['minMaterialAmount'] = minMaterialAmount;
    if (minMaterialPercent != null) queryParams['minMaterialPercent'] = minMaterialPercent;

    final res = await _client.get(
      ApiConfig.fluxCommentary,
      queryParameters: queryParams,
    );
    final data = res.data['data'] as Map<String, dynamic>;
    return FinancialFluxReportModel.fromJson(data);
  }
}

final fluxCommentaryRepositoryProvider = Provider<FluxCommentaryRepository>((ref) {
  return FluxCommentaryRepository(ref.watch(apiClientProvider));
});

final fluxReportQueryProvider = FutureProvider.family<FinancialFluxReportModel, Map<String, dynamic>>((ref, params) async {
  final repo = ref.watch(fluxCommentaryRepositoryProvider);
  return repo.getFluxReport(
    periodType: params['periodType'] ?? 'MOM',
    baseStart: params['baseStart'],
    baseEnd: params['baseEnd'],
    compStart: params['compStart'],
    compEnd: params['compEnd'],
  );
});