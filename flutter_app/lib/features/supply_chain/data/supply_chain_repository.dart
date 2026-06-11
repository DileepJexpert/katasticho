import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final supplyChainRepositoryProvider = Provider<SupplyChainRepository>((ref) {
  return SupplyChainRepository(ref.watch(apiClientProvider));
});

class SupplyChainRepository {
  final ApiClient _api;
  SupplyChainRepository(this._api);

  // ── Item-Supplier ──

  Future<List<dynamic>> getItemSuppliers(String itemId) async {
    final res = await _api.get(ApiConfig.supplyChainItemSuppliersByItem(itemId));
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getSupplierItems(String supplierId) async {
    final res = await _api.get(ApiConfig.supplyChainItemSuppliersBySupplier(supplierId));
    return res.data['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> addItemSupplier(Map<String, dynamic> body) async {
    final res = await _api.post(ApiConfig.supplyChainItemSuppliers, data: body);
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> setPreferredSupplier(String itemId, String supplierId) async {
    await _api.post(ApiConfig.supplyChainSetPreferred(itemId, supplierId));
  }

  Future<void> removeItemSupplier(String id) async {
    await _api.delete('${ApiConfig.supplyChainItemSuppliers}/$id');
  }

  // ── Demand Forecast ──

  Future<List<dynamic>> generateForecast({int monthsAhead = 3, int historyMonths = 6}) async {
    final res = await _api.post(
      '${ApiConfig.supplyChainForecastGenerate}?monthsAhead=$monthsAhead&historyMonths=$historyMonths',
    );
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getForecastsByItem(String itemId) async {
    final res = await _api.get(ApiConfig.supplyChainForecastsByItem(itemId));
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getForecasts(String from, String to) async {
    final res = await _api.get('${ApiConfig.supplyChainForecasts}?from=$from&to=$to');
    return res.data['data'] as List<dynamic>;
  }

  // ── ABC / Reorder ──

  Future<List<dynamic>> runAbcClassification() async {
    final res = await _api.post(ApiConfig.supplyChainAbcRun);
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getReorderPolicies() async {
    final res = await _api.get(ApiConfig.supplyChainReorderPolicies);
    return res.data['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> calculateReorderParams(String itemId, {String? warehouseId}) async {
    String url = ApiConfig.supplyChainReorderParams(itemId);
    if (warehouseId != null) url += '?warehouseId=$warehouseId';
    final res = await _api.post(url);
    return res.data['data'] as Map<String, dynamic>;
  }

  // ── Purchase Requisition ──

  Future<Map<String, dynamic>> createRequisition(Map<String, dynamic> body) async {
    final res = await _api.post(ApiConfig.supplyChainRequisitions, data: body);
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> autoCreateRequisition() async {
    final res = await _api.post(ApiConfig.supplyChainRequisitionsAuto);
    return res.data['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> listRequisitions({String? status, int page = 0, int size = 20}) async {
    String url = '${ApiConfig.supplyChainRequisitions}?page=$page&size=$size';
    if (status != null) url += '&status=$status';
    final res = await _api.get(url);
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRequisition(String id) async {
    final res = await _api.get(ApiConfig.supplyChainRequisition(id));
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> submitRequisition(String id) async {
    await _api.post(ApiConfig.supplyChainRequisitionSubmit(id));
  }

  Future<void> approveRequisition(String id) async {
    await _api.post(ApiConfig.supplyChainRequisitionApprove(id));
  }

  Future<void> rejectRequisition(String id) async {
    await _api.post(ApiConfig.supplyChainRequisitionReject(id));
  }

  // ── Return Orders ──

  Future<Map<String, dynamic>> createReturnOrder(Map<String, dynamic> body) async {
    final res = await _api.post(ApiConfig.supplyChainReturns, data: body);
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listReturnOrders({String? status, String? returnType, int page = 0, int size = 20}) async {
    String url = '${ApiConfig.supplyChainReturns}?page=$page&size=$size';
    if (status != null) url += '&status=$status';
    if (returnType != null) url += '&returnType=$returnType';
    final res = await _api.get(url);
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReturnOrder(String id) async {
    final res = await _api.get(ApiConfig.supplyChainReturn(id));
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> approveReturn(String id) async {
    await _api.post(ApiConfig.supplyChainReturnApprove(id));
  }

  Future<void> processReturn(String id) async {
    await _api.post(ApiConfig.supplyChainReturnProcess(id));
  }

  Future<void> cancelReturn(String id) async {
    await _api.post(ApiConfig.supplyChainReturnCancel(id));
  }

  // ── Alerts ──

  Future<Map<String, dynamic>> listAlerts({String? status, int page = 0, int size = 20}) async {
    String url = '${ApiConfig.supplyChainAlerts}?page=$page&size=$size';
    if (status != null) url += '&status=$status';
    final res = await _api.get(url);
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> resolveAlert(String id) async {
    await _api.post(ApiConfig.supplyChainAlertResolve(id));
  }

  Future<List<dynamic>> runAlertScan() async {
    final res = await _api.post(ApiConfig.supplyChainAlertScan);
    return res.data['data'] as List<dynamic>;
  }

  // ── Supplier Performance ──

  Future<List<dynamic>> getSupplierScorecard(String supplierId) async {
    final res = await _api.get(ApiConfig.supplyChainSupplierPerformance(supplierId));
    return res.data['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getSupplierRankings() async {
    final res = await _api.get(ApiConfig.supplyChainSupplierRankings);
    return res.data['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> calculateSupplierPerformance(String supplierId, String from, String to) async {
    final res = await _api.post(
      '${ApiConfig.supplyChainSupplierPerformanceCalc(supplierId)}?from=$from&to=$to',
    );
    return res.data['data'] as Map<String, dynamic>;
  }

  // ── Analytics ──

  Future<List<dynamic>> getInventoryTurnover({int months = 12}) async {
    final res = await _api.get('${ApiConfig.supplyChainTurnover}?months=$months');
    return res.data['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final res = await _api.get(ApiConfig.supplyChainDashboard);
    return res.data['data'] as Map<String, dynamic>;
  }
}
