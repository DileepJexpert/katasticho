import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import 'dashboard_models.dart';

/// Date range + optional branch filter used by every dashboard widget.
/// Kept as a value type so Riverpod providers can key off of it and
/// auto-refresh when the user changes the picker.
class DashboardFilter {
  final DateTime from;
  final DateTime to;
  final String? branchId;

  const DashboardFilter({
    required this.from,
    required this.to,
    this.branchId,
  });

  factory DashboardFilter.today() {
    final now = DateTime.now();
    final d = DateTime(now.year, now.month, now.day);
    return DashboardFilter(from: d, to: d);
  }

  DashboardFilter copyWith({
    DateTime? from,
    DateTime? to,
    Object? branchId = _sentinel,
  }) {
    return DashboardFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      branchId: identical(branchId, _sentinel) ? this.branchId : branchId as String?,
    );
  }

  static const _sentinel = Object();

  @override
  bool operator ==(Object other) =>
      other is DashboardFilter &&
      other.from == from &&
      other.to == to &&
      other.branchId == branchId;

  @override
  int get hashCode => Object.hash(from, to, branchId);
}

String _fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Unwraps the common `{success, data, error}` API envelope. If the
/// backend ever returns the raw payload directly (older endpoints), we
/// fall through to the original map so callers never have to care.
Map<String, dynamic> _unwrap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return raw;
  }
  return <String, dynamic>{};
}

List<dynamic> _unwrapList(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    final data = raw['data'];
    if (data is List) return data;
    if (data is Map && data['content'] is List) {
      return data['content'] as List;
    }
  }
  if (raw is List) return raw;
  return const [];
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(apiClientProvider));
});

class DashboardRepository {
  final ApiClient _api;

  DashboardRepository(this._api);

  Future<TodaySalesData> getTodaySales(DashboardFilter filter) async {
    final response = await _api.get(
      ApiConfig.dashboardTodaySales,
      queryParameters: {
        'from': _fmtDate(filter.from),
        'to': _fmtDate(filter.to),
        if (filter.branchId != null) 'branchId': filter.branchId,
      },
    );
    return TodaySalesData.fromJson(_unwrap(response.data));
  }

  Future<List<TopSellingItem>> getTopSelling(
    DashboardFilter filter, {
    int limit = 5,
  }) async {
    final response = await _api.get(
      ApiConfig.dashboardTopSelling,
      queryParameters: {
        'from': _fmtDate(filter.from),
        'to': _fmtDate(filter.to),
        'limit': limit,
      },
    );
    return _unwrapList(response.data)
        .map((e) => TopSellingItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BranchSummary>> listBranches() async {
    final response = await _api.get(ApiConfig.branches);
    return _unwrapList(response.data)
        .map((e) => BranchSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ApSummaryData> getApSummary(DashboardFilter filter) async {
    final response = await _api.get(
      ApiConfig.dashboardApSummary,
      queryParameters: {
        'from': _fmtDate(filter.from),
        'to': _fmtDate(filter.to),
        if (filter.branchId != null) 'branchId': filter.branchId,
      },
    );
    return ApSummaryData.fromJson(_unwrap(response.data));
  }

  Future<List<RecentBillData>> getRecentBills({int limit = 5}) async {
    final response = await _api.get(
      ApiConfig.dashboardRecentBills,
      queryParameters: {'limit': limit},
    );
    return _unwrapList(response.data)
        .map((e) => RecentBillData.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ArSummaryData> getArSummary() async {
    final response = await _api.get(ApiConfig.dashboardReceivables);
    return ArSummaryData.fromJson(_unwrap(response.data));
  }

  Future<MonthlyProfitData> getMonthlyProfit(DashboardFilter filter) async {
    final response = await _api.get(
      ApiConfig.dashboardMonthlyProfit,
      queryParameters: {
        'from': _fmtDate(filter.from),
        'to': _fmtDate(filter.to),
      },
    );
    return MonthlyProfitData.fromJson(_unwrap(response.data));
  }

  Future<Map<String, dynamic>> seedSharmaMedical() async {
    final response = await _api.post(ApiConfig.demoSeedSharmaMedical);
    return _unwrap(response.data);
  }
}

// ─── Providers ──────────────────────────────────────────────────────

/// Global filter state: date range + selected branch. Mutating this via
/// `ref.read(dashboardFilterProvider.notifier).state = …` causes every
/// downstream provider below to re-fetch.
final dashboardFilterProvider =
    StateProvider<DashboardFilter>((ref) => DashboardFilter.today());

final todaySalesProvider =
    FutureProvider.autoDispose<TodaySalesData>((ref) async {
  final filter = ref.watch(dashboardFilterProvider);
  return ref.watch(dashboardRepositoryProvider).getTodaySales(filter);
});

final topSellingProvider =
    FutureProvider.autoDispose<List<TopSellingItem>>((ref) async {
  final filter = ref.watch(dashboardFilterProvider);
  return ref.watch(dashboardRepositoryProvider).getTopSelling(filter);
});

final branchesProvider =
    FutureProvider.autoDispose<List<BranchSummary>>((ref) async {
  return ref.watch(dashboardRepositoryProvider).listBranches();
});

final apSummaryProvider =
    FutureProvider.autoDispose<ApSummaryData>((ref) async {
  final filter = ref.watch(dashboardFilterProvider);
  return ref.watch(dashboardRepositoryProvider).getApSummary(filter);
});

final recentBillsProvider =
    FutureProvider.autoDispose<List<RecentBillData>>((ref) async {
  return ref.watch(dashboardRepositoryProvider).getRecentBills();
});

final arSummaryProvider =
    FutureProvider.autoDispose<ArSummaryData>((ref) async {
  return ref.watch(dashboardRepositoryProvider).getArSummary();
});

final monthlyProfitProvider =
    FutureProvider.autoDispose<MonthlyProfitData>((ref) async {
  final filter = ref.watch(dashboardFilterProvider);
  return ref.watch(dashboardRepositoryProvider).getMonthlyProfit(filter);
});
