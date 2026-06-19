import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final routingRepositoryProvider = Provider((ref) {
  return RoutingRepository(ref.watch(apiClientProvider));
});

final workstationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(routingRepositoryProvider).listWorkstations();
});

final operationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(routingRepositoryProvider).listOperations();
});

final routingsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(routingRepositoryProvider).listRoutings();
});

final routingDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) {
  return ref.watch(routingRepositoryProvider).getRouting(id);
});

final jobCardsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, workOrderId) {
  return ref.watch(routingRepositoryProvider).listJobCards(workOrderId);
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class RoutingRepository {
  RoutingRepository(this._api);
  final ApiClient _api;

  // ---- Workstations --------------------------------------------------------

  Future<List<Map<String, dynamic>>> listWorkstations() async {
    final res = await _api.get('/api/v1/manufacturing/workstations');
    return _unwrapList(res.data);
  }

  Future<Map<String, dynamic>> createWorkstation({
    required String code,
    required String name,
    String? description,
    double? hourlyRate,
    double? capacityHours,
  }) async {
    final res = await _api.post('/api/v1/manufacturing/workstations', data: {
      'code': code,
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      if (capacityHours != null) 'capacityHours': capacityHours,
    });
    return _unwrap(res.data);
  }

  // ---- Operations ----------------------------------------------------------

  Future<List<Map<String, dynamic>>> listOperations() async {
    final res = await _api.get('/api/v1/manufacturing/operations');
    return _unwrapList(res.data);
  }

  Future<Map<String, dynamic>> createOperation({
    required String code,
    required String name,
    String? description,
    String? defaultWorkstationId,
    int? setupTimeMinutes,
    double? runTimePerUnit,
  }) async {
    final res = await _api.post('/api/v1/manufacturing/operations', data: {
      'code': code,
      'name': name,
      if (description != null && description.isNotEmpty) 'description': description,
      if (defaultWorkstationId != null && defaultWorkstationId.isNotEmpty)
        'defaultWorkstationId': defaultWorkstationId,
      if (setupTimeMinutes != null) 'setupTimeMinutes': setupTimeMinutes,
      if (runTimePerUnit != null) 'runTimePerUnit': runTimePerUnit,
    });
    return _unwrap(res.data);
  }

  // ---- Operation work instructions (tracker #13) ---------------------------

  Future<List<Map<String, dynamic>>> listOperationAttachments(String operationId) async {
    final res = await _api.get(ApiConfig.manufacturingOperationAttachments(operationId));
    return _unwrapList(res.data);
  }

  Future<Map<String, dynamic>> uploadOperationAttachment(
      String operationId, List<int> bytes, String filename) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _api.post(
      ApiConfig.manufacturingOperationAttachments(operationId),
      data: form,
    );
    return _unwrap(res.data);
  }

  Future<void> deleteOperationAttachment(String attachmentId) async {
    await _api.delete(ApiConfig.manufacturingOperationAttachment(attachmentId));
  }

  // ---- Routings ------------------------------------------------------------

  Future<List<Map<String, dynamic>>> listRoutings() async {
    final res = await _api.get('/api/v1/manufacturing/routings');
    return _unwrapList(res.data);
  }

  Future<Map<String, dynamic>> getRouting(String id) async {
    final res = await _api.get('/api/v1/manufacturing/routings/$id');
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> createRouting({
    required String name,
    required String itemId,
    required bool isDefault,
    required List<Map<String, dynamic>> operations,
  }) async {
    final res = await _api.post('/api/v1/manufacturing/routings', data: {
      'name': name,
      'itemId': itemId,
      'isDefault': isDefault,
      'operations': operations,
    });
    return _unwrap(res.data);
  }

  // ---- Job Cards -----------------------------------------------------------

  Future<List<Map<String, dynamic>>> listJobCards(String workOrderId) async {
    final res =
        await _api.get('/api/v1/manufacturing/work-orders/$workOrderId/job-cards');
    return _unwrapList(res.data);
  }

  Future<List<Map<String, dynamic>>> createJobCards({
    required String workOrderId,
    required String routingId,
    required double qty,
  }) async {
    final res = await _api.post(
      '/api/v1/manufacturing/work-orders/$workOrderId/job-cards',
      data: {'routingId': routingId, 'qty': qty},
    );
    return _unwrapList(res.data);
  }

  Future<Map<String, dynamic>> startJobCard(String jobCardId) async {
    final res =
        await _api.post('/api/v1/manufacturing/job-cards/$jobCardId/start');
    return _unwrap(res.data);
  }

  Future<Map<String, dynamic>> completeJobCard(
    String jobCardId, {
    required double completedQty,
    double? scrapQty,
    int? timeLoggedMinutes,
    String? notes,
  }) async {
    final res = await _api.post(
      '/api/v1/manufacturing/job-cards/$jobCardId/complete',
      data: {
        'completedQty': completedQty,
        if (scrapQty != null) 'scrapQty': scrapQty,
        if (timeLoggedMinutes != null) 'timeLoggedMinutes': timeLoggedMinutes,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return _unwrap(res.data);
  }

  // ---- Helpers -------------------------------------------------------------

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is Map<String, dynamic>) return data;
      return raw;
    }
    return {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map) {
        final content = data['content'];
        if (content is List) {
          return content.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return [];
  }
}
