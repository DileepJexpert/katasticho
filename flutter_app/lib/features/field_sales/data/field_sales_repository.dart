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
  Future<List<Map<String, dynamic>>> listBeats({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _api.get(
      ApiConfig.fieldSalesBeats,
      queryParameters: {'page': page, 'size': size},
    );
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

  Future<Map<String, dynamic>> updateBeat(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _api.put(
      ApiConfig.fieldSalesBeatById(id),
      data: payload,
    );
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getBeatCustomers(String beatId) async {
    final response =
        await _api.get(ApiConfig.fieldSalesBeatCustomers(beatId));
    final data = response.data['data'] ?? response.data;
    final content = data is List
        ? data
        : (data is Map ? (data['content'] as List?) ?? [] : []);
    return (content)
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

  Future<Map<String, dynamic>> updateRoute(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final response = await _api.put(
      ApiConfig.fieldSalesRouteById(id),
      data: payload,
    );
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getRouteBeats(String routeId) async {
    final response = await _api.get(ApiConfig.fieldSalesRouteBeats(routeId));
    final data = response.data['data'] ?? response.data;
    final content = data is List
        ? data
        : (data is Map ? (data['content'] as List?) ?? [] : []);
    return content
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .toList();
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
    return (content)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  // -- Assignments --
  Future<List<Map<String, dynamic>>> listAssignments({
    bool includeInactive = false,
    String? effectiveOn,
  }) async {
    final queryParams = <String, dynamic>{
      if (includeInactive) 'includeInactive': true,
      if (effectiveOn != null) 'effectiveOn': effectiveOn,
    };
    final response = await _api.get(
      ApiConfig.fieldSalesAssignments,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final data = response.data['data'] ?? response.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : data;
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> createAssignment(
      Map<String, dynamic> payload) async {
    final response =
        await _api.post(ApiConfig.fieldSalesAssignments, data: payload);
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAssignment(
      String id, Map<String, dynamic> payload) async {
    final response =
        await _api.put(ApiConfig.fieldSalesAssignmentById(id), data: payload);
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> endAssignment(
      String id, {String? endDate}) async {
    final response = await _api.post(
      ApiConfig.fieldSalesAssignmentEnd(id),
      data: endDate != null ? {'endDate': endDate} : {},
    );
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<void> deleteAssignment(String id) async {
    await _api.delete(ApiConfig.fieldSalesAssignmentById(id));
  }

  Future<List<Map<String, dynamic>>> getAssignmentsForSalesperson(
      String salespersonId) async {
    final response = await _api
        .get(ApiConfig.fieldSalesAssignmentsBySalesperson(salespersonId));
    final data = response.data['data'] ?? response.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : data;
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMyAssignments(
      {String? effectiveOn}) async {
    final queryParams = <String, dynamic>{
      if (effectiveOn != null) 'effectiveOn': effectiveOn,
    };
    final response = await _api.get(
      ApiConfig.fieldSalesAssignmentsMe,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final data = response.data['data'] ?? response.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : data;
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
    return (content)
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
      data: {'skipReason': reason},
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
      data: {'collectionAmount': amount},
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
    return (content)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  // POST /targets — set a sales target for a salesperson over a period.
  Future<Map<String, dynamic>> createTarget(Map<String, dynamic> payload) async {
    final response =
        await _api.post(ApiConfig.fieldSalesTargets, data: payload);
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  // Backend exposes PUT /targets/{id}/achievement (no GET). Records the
  // achieved value against a target and returns the updated row.
  Future<Map<String, dynamic>> updateTargetAchievement(
      String targetId, double achievedValue) async {
    final response = await _api.put(
      ApiConfig.fieldSalesTargetAchievement(targetId),
      data: {'achievedValue': achievedValue},
    );
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

  // -- MR reporting (tour plans + DCR) --
  Future<List<Map<String, dynamic>>> myTourPlans() async {
    final response = await _api.get(ApiConfig.mrTourPlansMe);
    return _asList(response.data['data'] ?? response.data);
  }

  Future<Map<String, dynamic>> createTourPlan(String planMonth, {String? notes}) async {
    final response = await _api.post(ApiConfig.mrTourPlans, data: {
      'planMonth': planMonth,
      if (notes != null) 'notes': notes,
    });
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addTourPlanEntry(String planId, Map<String, dynamic> entry) async {
    final response = await _api.post(ApiConfig.mrTourPlanEntries(planId), data: entry);
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<void> removeTourPlanEntry(String entryId) async {
    await _api.delete(ApiConfig.mrTourPlanEntryDelete(entryId));
  }

  Future<Map<String, dynamic>> submitTourPlan(String planId) async {
    final response = await _api.post(ApiConfig.mrTourPlanSubmit(planId));
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> pendingTourPlans() async {
    final response = await _api.get(ApiConfig.mrTourPlansPending);
    return _asList(response.data['data'] ?? response.data);
  }

  Future<Map<String, dynamic>> getTourPlan(String id) async {
    final response = await _api.get(ApiConfig.mrTourPlanById(id));
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<void> approveTourPlan(String id) async {
    await _api.post(ApiConfig.mrTourPlanApprove(id));
  }

  Future<void> rejectTourPlan(String id, String reason) async {
    await _api.post(ApiConfig.mrTourPlanReject(id), data: {'reason': reason});
  }

  Future<Map<String, dynamic>> buildDcr({String? date, String? workType}) async {
    final response = await _api.post(ApiConfig.mrDcrBuild, data: {
      if (date != null) 'date': date,
      if (workType != null) 'workType': workType,
    });
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitDcr({String? date, String? workType, String? remarks}) async {
    final response = await _api.post(ApiConfig.mrDcrSubmit, data: {
      if (date != null) 'date': date,
      if (workType != null) 'workType': workType,
      if (remarks != null) 'remarks': remarks,
    });
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> myDcrs({String? from, String? to}) async {
    final query = from != null && to != null ? '?from=$from&to=$to' : '';
    final response = await _api.get('${ApiConfig.mrDcrMe}$query');
    return _asList(response.data['data'] ?? response.data);
  }

  Future<List<Map<String, dynamic>>> pendingDcrs() async {
    final response = await _api.get(ApiConfig.mrDcrPending);
    return _asList(response.data['data'] ?? response.data);
  }

  Future<void> approveDcr(String id) async {
    await _api.post(ApiConfig.mrDcrApprove(id));
  }

  Future<void> rejectDcr(String id, String reason) async {
    await _api.post(ApiConfig.mrDcrReject(id), data: {'reason': reason});
  }

  Future<List<Map<String, dynamic>>> logVisitProducts(String visitId, List<Map<String, dynamic>> products) async {
    final response = await _api.put(ApiConfig.mrVisitProducts(visitId), data: {'products': products});
    return _asList(response.data['data'] ?? response.data);
  }

  Future<List<Map<String, dynamic>>> getVisitProducts(String visitId) async {
    final response = await _api.get(ApiConfig.mrVisitProducts(visitId));
    return _asList(response.data['data'] ?? response.data);
  }

  Future<Map<String, dynamic>> markJointVisit(String visitId, {String? userId}) async {
    final response = await _api.post(ApiConfig.mrVisitJoint(visitId), data: {
      if (userId != null) 'userId': userId,
    });
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> activeDetailAids() async {
    final response = await _api.get(ApiConfig.mrDetailAids);
    return _asList(response.data['data'] ?? response.data);
  }

  // -- Field samples (all verticals) --
  Future<List<Map<String, dynamic>>> sampleBalance(String salespersonId) async {
    final response =
        await _api.get(ApiConfig.fieldSamplesBalance(salespersonId));
    return _asList(response.data['data'] ?? response.data);
  }

  Future<List<Map<String, dynamic>>> sampleTransactions(
      String salespersonId) async {
    final response =
        await _api.get(ApiConfig.fieldSamplesTransactions(salespersonId));
    return _asList(response.data['data'] ?? response.data);
  }

  Future<void> recordSampleTxn({
    required bool isIssue,
    required String salespersonId,
    required String productName,
    required int quantity,
    String? notes,
  }) async {
    await _api.post(
      isIssue ? ApiConfig.fieldSamplesIssue : ApiConfig.fieldSamplesReturn,
      data: {
        'salespersonId': salespersonId,
        'productName': productName,
        'quantity': quantity,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  // -- Coverage reports --
  Future<List<Map<String, dynamic>>> teamDashboard(
      String from, String to) async {
    final response = await _api.get(
        '${ApiConfig.mrTeamDashboard}?from=$from&to=$to');
    return _asList(response.data['data'] ?? response.data);
  }

  Future<Map<String, dynamic>> deviationReport(
      String month, String salespersonId) async {
    final response = await _api.get(
        '${ApiConfig.mrDeviationReport}?month=$month&salespersonId=$salespersonId');
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> frequencyCompliance(String month,
      {String? salespersonId}) async {
    final query = salespersonId != null
        ? '?month=$month&salespersonId=$salespersonId'
        : '?month=$month';
    final response =
        await _api.get('${ApiConfig.mrFrequencyCompliance}$query');
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  // -- Attendance + leave (manager) --
  Future<List<Map<String, dynamic>>> teamAttendance(String date) async {
    final response = await _api.get('${ApiConfig.attendanceTeam}?date=$date');
    return _asList(response.data['data'] ?? response.data);
  }

  Future<List<Map<String, dynamic>>> pendingLeaves() async {
    final response = await _api.get(ApiConfig.attendanceLeavePending);
    return _asList(response.data['data'] ?? response.data);
  }

  Future<void> approveLeave(String id) async {
    await _api.post(ApiConfig.attendanceLeaveApprove(id));
  }

  Future<void> rejectLeave(String id, String reason) async {
    await _api.post(ApiConfig.attendanceLeaveReject(id),
        data: {'reason': reason});
  }

  // -- Merchandising & Shelf Audits (Step 4.4) --
  Future<Map<String, dynamic>> recordMerchandisingAudit(
      Map<String, dynamic> data) async {
    final response =
        await _api.post(ApiConfig.fieldSalesMerchandising, data: data);
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMerchandisingByVisit(
      String visitId) async {
    final response =
        await _api.get(ApiConfig.fieldSalesMerchandisingByVisit(visitId));
    return _asList(response.data['data'] ?? response.data);
  }

  Future<List<Map<String, dynamic>>> getMerchandisingByExecution(
      String executionId) async {
    final response = await _api
        .get(ApiConfig.fieldSalesMerchandisingByExecution(executionId));
    return _asList(response.data['data'] ?? response.data);
  }

  Future<List<Map<String, dynamic>>> getRecentMerchandising(
      {String? from, String? to}) async {
    final query = from != null && to != null ? '?from=$from&to=$to' : '';
    final response =
        await _api.get('${ApiConfig.fieldSalesMerchandisingRecent}$query');
    return _asList(response.data['data'] ?? response.data);
  }

  Future<Map<String, dynamic>> getMerchandisingSummary(
      {String? from, String? to}) async {
    final query = from != null && to != null ? '?from=$from&to=$to' : '';
    final response =
        await _api.get('${ApiConfig.fieldSalesMerchandisingSummary}$query');
    return (response.data['data'] ?? response.data) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> _asList(dynamic data) {
    final content = data is Map ? (data['content'] as List?) ?? [] : data;
    return (content as List)
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }
}
