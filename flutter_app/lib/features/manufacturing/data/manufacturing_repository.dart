import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final manufacturingRepositoryProvider = Provider((ref) {
  return ManufacturingRepository(ref.watch(apiClientProvider));
});

final workOrdersProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, status) {
  return ref.watch(manufacturingRepositoryProvider).listWorkOrders(status: status);
});

final workOrderDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) {
  return ref.watch(manufacturingRepositoryProvider).getWorkOrder(id);
});

final jobWorkOrdersProvider = FutureProvider.family<List<Map<String, dynamic>>, String?>((ref, status) {
  return ref.watch(manufacturingRepositoryProvider).listJobWorkOrders(status: status);
});

final jobWorkOrderDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, id) {
  return ref.watch(manufacturingRepositoryProvider).getJobWorkOrder(id);
});

class ManufacturingRepository {
  ManufacturingRepository(this._api);
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> listWorkOrders({String? status}) async {
    final res = await _api.get(
      ApiConfig.manufacturingWorkOrders,
      queryParameters: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> getWorkOrder(String id) async {
    final res = await _api.get(ApiConfig.manufacturingWorkOrderById(id));
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> createWorkOrder({
    required String finishedGoodId,
    required String warehouseId,
    required double quantityToProduce,
    String? plannedStartDate,
    String? plannedEndDate,
    double? directLaborCost,
    double? overheadCost,
    String? notes,
  }) async {
    final res = await _api.post(ApiConfig.manufacturingWorkOrders, data: {
      'finishedGoodId': finishedGoodId,
      'warehouseId': warehouseId,
      'quantityToProduce': quantityToProduce,
      if (plannedStartDate != null) 'plannedStartDate': plannedStartDate,
      if (plannedEndDate != null) 'plannedEndDate': plannedEndDate,
      if (directLaborCost != null) 'directLaborCost': directLaborCost,
      if (overheadCost != null) 'overheadCost': overheadCost,
      if (notes != null) 'notes': notes,
    });
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> issueToProduction(String id) async {
    final res = await _api.post(ApiConfig.manufacturingWorkOrderIssue(id));
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> receiveFinishedGoods(String id, double quantity) async {
    final res = await _api.post(ApiConfig.manufacturingWorkOrderReceive(id), data: {
      'quantityReceived': quantity,
    });
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> updateCosts(String id, {double? directLaborCost, double? overheadCost}) async {
    final res = await _api.put(ApiConfig.manufacturingWorkOrderCosts(id), data: {
      if (directLaborCost != null) 'directLaborCost': directLaborCost,
      if (overheadCost != null) 'overheadCost': overheadCost,
    });
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> cancelWorkOrder(String id) async {
    final res = await _api.post(ApiConfig.manufacturingWorkOrderCancel(id));
    return _unwrap(res);
  }

  // ---------------------------------------------------------------------------
  // Job Work Orders
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> listJobWorkOrders({String? status}) async {
    final res = await _api.get(
      '/api/v1/manufacturing/job-work',
      queryParameters: {if (status != null && status.isNotEmpty) 'status': status},
    );
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> getJobWorkOrder(String id) async {
    final res = await _api.get('/api/v1/manufacturing/job-work/$id');
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> createJobWorkOrder({
    required String vendorId,
    required String warehouseId,
    required List<Map<String, dynamic>> materials,
    double? processingCharges,
    String? plannedSendDate,
    String? plannedReturnDate,
    String? notes,
  }) async {
    final res = await _api.post('/api/v1/manufacturing/job-work', data: {
      'vendorId': vendorId,
      'warehouseId': warehouseId,
      'materials': materials,
      if (processingCharges != null) 'processingCharges': processingCharges,
      if (plannedSendDate != null) 'plannedSendDate': plannedSendDate,
      if (plannedReturnDate != null) 'plannedReturnDate': plannedReturnDate,
      if (notes != null) 'notes': notes,
    });
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> sendJobWorkMaterials(String id) async {
    final res = await _api.post('/api/v1/manufacturing/job-work/$id/send');
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> receiveJobWorkGoods(
      String id, List<Map<String, dynamic>> receiptLines) async {
    final res = await _api.post(
      '/api/v1/manufacturing/job-work/$id/receive',
      data: {'receiptLines': receiptLines},
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> cancelJobWorkOrder(String id) async {
    final res = await _api.post('/api/v1/manufacturing/job-work/$id/cancel');
    return _unwrap(res);
  }

  Future<List<Map<String, dynamic>>> getJobWorkGstAlerts({int daysBeforeDeadline = 30}) async {
    final res = await _api.get(
      '/api/v1/manufacturing/job-work/gst-alerts',
      queryParameters: {'daysBeforeDeadline': daysBeforeDeadline},
    );
    return _unwrapList(res);
  }

  Map<String, dynamic> _unwrap(dynamic res) {
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      if (data is Map<String, dynamic>) return data;
      return res;
    }
    return {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic res) {
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map) {
        final content = data['content'];
        if (content is List) return content.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }
}
