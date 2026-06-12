import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final fieldSalesRepositoryProvider = Provider<FieldSalesRepository>((ref) {
  return FieldSalesRepository(ref.watch(apiClientProvider));
});

class FieldSalesRepository {
  final ApiClient _api;
  FieldSalesRepository(this._api);

  // -- Beats --
  Future<List<Map<String, dynamic>>> listBeats() async {
    final response = await _api.get(ApiConfig.fieldSalesBeats);
    final data = response.data['data'] ?? response.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : data;
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> createBeat(Map<String, dynamic> payload) async {
    final response =
        await _api.post(ApiConfig.fieldSalesBeats, data: payload);
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBeat(String id) async {
    final response = await _api.get(ApiConfig.fieldSalesBeatById(id));
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getBeatCustomers(String beatId) async {
    final response =
        await _api.get(ApiConfig.fieldSalesBeatCustomers(beatId));
    final data = response.data['data'] ?? response.data;
    final content = data is List
        ? data
        : (data is Map ? (data['content'] as List?) ?? [] : []);
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  // -- Routes --
  Future<List<Map<String, dynamic>>> listRoutes() async {
    final response = await _api.get(ApiConfig.fieldSalesRoutes);
    final data = response.data['data'] ?? response.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : data;
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> createRoute(
      Map<String, dynamic> payload) async {
    final response =
        await _api.post(ApiConfig.fieldSalesRoutes, data: payload);
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  // -- Vans --
  Future<List<Map<String, dynamic>>> listVans() async {
    final response = await _api.get(ApiConfig.fieldSalesVans);
    final data = response.data['data'] ?? response.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : data;
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> createVan(Map<String, dynamic> payload) async {
    final response = await _api.post(ApiConfig.fieldSalesVans, data: payload);
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getVanStock(String vanId) async {
    final response = await _api.get(ApiConfig.fieldSalesVanStock(vanId));
    final data = response.data['data'] ?? response.data;
    final content = data is List
        ? data
        : (data is Map ? (data['content'] as List?) ?? [] : []);
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  // -- Route Executions --
  Future<List<Map<String, dynamic>>> listExecutions({String? date}) async {
    final path = date != null
        ? ApiConfig.fieldSalesExecutionsByDate(date)
        : ApiConfig.fieldSalesExecutions;
    final response = await _api.get(path);
    final data = response.data['data'] ?? response.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : data;
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> createExecution(
      Map<String, dynamic> payload) async {
    final response =
        await _api.post(ApiConfig.fieldSalesExecutions, data: payload);
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getExecution(String id) async {
    final response = await _api.get(ApiConfig.fieldSalesExecutionById(id));
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<void> startExecution(String id) async {
    await _api.post(ApiConfig.fieldSalesExecutionStart(id));
  }

  Future<void> completeExecution(String id) async {
    await _api.post(ApiConfig.fieldSalesExecutionComplete(id));
  }

  Future<List<Map<String, dynamic>>> getVisits(String executionId) async {
    final response =
        await _api.get(ApiConfig.fieldSalesExecutionVisits(executionId));
    final data = response.data['data'] ?? response.data;
    final content = data is List
        ? data
        : (data is Map ? (data['content'] as List?) ?? [] : []);
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<void> checkIn(String visitId, double lat, double lng) async {
    await _api.post(
      ApiConfig.fieldSalesVisitCheckIn(visitId),
      data: {'latitude': lat, 'longitude': lng},
    );
  }

  Future<void> checkOut(String visitId, double lat, double lng,
      {String? notes}) async {
    await _api.post(
      ApiConfig.fieldSalesVisitCheckOut(visitId),
      data: {
        'latitude': lat,
        'longitude': lng,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  Future<void> skipVisit(String visitId, String reason) async {
    await _api.post(
      ApiConfig.fieldSalesVisitSkip(visitId),
      data: {'reason': reason},
    );
  }

  Future<void> recordOrder(
      String visitId, String salesOrderId, double orderValue) async {
    await _api.post(
      ApiConfig.fieldSalesVisitRecordOrder(visitId),
      data: {'salesOrderId': salesOrderId, 'orderValue': orderValue},
    );
  }

  Future<void> recordCollection(String visitId, double amount) async {
    await _api.post(
      ApiConfig.fieldSalesVisitRecordCollection(visitId),
      data: {'amount': amount},
    );
  }

  // -- Day Close --
  Future<Map<String, dynamic>> initiateDayClose(
      String routeExecutionId) async {
    final response = await _api
        .post(ApiConfig.fieldSalesDayCloseInitiate(routeExecutionId));
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDayClose(String id) async {
    final response = await _api.get(ApiConfig.fieldSalesDayCloseById(id));
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<void> submitDayClose(
      String id, Map<String, dynamic> payload) async {
    await _api.post(ApiConfig.fieldSalesDayCloseSubmit(id), data: payload);
  }

  Future<void> approveDayClose(String id) async {
    await _api.post(ApiConfig.fieldSalesDayCloseApprove(id));
  }

  Future<void> rejectDayClose(String id) async {
    await _api.post(ApiConfig.fieldSalesDayCloseReject(id));
  }

  // -- Targets --
  Future<List<Map<String, dynamic>>> listTargets() async {
    final response = await _api.get(ApiConfig.fieldSalesTargets);
    final data = response.data['data'] ?? response.data;
    final content = data is List
        ? data
        : (data is Map ? (data['content'] as List?) ?? [] : []);
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> getTargetAchievement(
      String targetId) async {
    final response =
        await _api.get(ApiConfig.fieldSalesTargetAchievement(targetId));
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  // -- Dashboard --
  Future<Map<String, dynamic>> getDashboard({String? from, String? to}) async {
    final queryParams = <String, String>{};
    if (from != null) queryParams['from'] = from;
    if (to != null) queryParams['to'] = to;
    final uri = Uri.parse(ApiConfig.fieldSalesDashboard)
        .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await _api.get(uri.toString());
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  // -- Live tracking --
  Future<List<Map<String, dynamic>>> getLiveLocations() async {
    final response = await _api.get(ApiConfig.fieldSalesLiveLocations);
    final data = response.data['data'] ?? response.data;
    return (data as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> getLocationTrail(String executionId) async {
    final response =
        await _api.get(ApiConfig.fieldSalesLocationTrail(executionId));
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }
}
