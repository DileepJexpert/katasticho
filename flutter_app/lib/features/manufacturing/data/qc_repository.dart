import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final qcRepositoryProvider = Provider((ref) {
  return QcRepository(ref.watch(apiClientProvider));
});

final qcInspectionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, InspectionFilter>(
  (ref, filter) => ref
      .watch(qcRepositoryProvider)
      .listInspections(status: filter.status, inspectionType: filter.type),
);

final qcInspectionDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, id) => ref.watch(qcRepositoryProvider).getInspection(id),
);

final qcTemplatesProvider = FutureProvider<List<Map<String, dynamic>>>(
  (ref) => ref.watch(qcRepositoryProvider).listTemplates(),
);

// Simple filter value object — used as the family key.
class InspectionFilter {
  const InspectionFilter({this.status, this.type});
  final String? status;
  final String? type;

  @override
  bool operator ==(Object other) =>
      other is InspectionFilter && other.status == status && other.type == type;

  @override
  int get hashCode => Object.hash(status, type);
}

// Convenience constructor exposed to callers.
InspectionFilter inspectionFilter({String? status, String? type}) =>
    InspectionFilter(status: status, type: type);

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class QcRepository {
  QcRepository(this._api);
  final ApiClient _api;

  // ── Inspections ──────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listInspections({
    String? status,
    String? inspectionType,
  }) async {
    final res = await _api.get(
      '/api/v1/manufacturing/qc/inspections',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (inspectionType != null && inspectionType.isNotEmpty)
          'inspectionType': inspectionType,
      },
    );
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> createInspection({
    String? templateId,
    required String inspectionType,
    String? referenceType,
    String? referenceId,
    required String itemId,
    String? batchId,
    required double inspectedQty,
  }) async {
    final res = await _api.post(
      '/api/v1/manufacturing/qc/inspections',
      data: {
        if (templateId != null && templateId.isNotEmpty)
          'templateId': templateId,
        'inspectionType': inspectionType,
        if (referenceType != null && referenceType.isNotEmpty)
          'referenceType': referenceType,
        if (referenceId != null && referenceId.isNotEmpty)
          'referenceId': referenceId,
        'itemId': itemId,
        if (batchId != null && batchId.isNotEmpty) 'batchId': batchId,
        'inspectedQty': inspectedQty,
      },
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> getInspection(String id) async {
    final res =
        await _api.get('/api/v1/manufacturing/qc/inspections/$id');
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> recordResults(
    String id,
    List<Map<String, dynamic>> results,
  ) async {
    final res = await _api.post(
      '/api/v1/manufacturing/qc/inspections/$id/results',
      data: {'results': results},
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> finalizeInspection(
    String id, {
    required double acceptedQty,
    required double rejectedQty,
    String? notes,
  }) async {
    final res = await _api.post(
      '/api/v1/manufacturing/qc/inspections/$id/finalize',
      data: {
        'acceptedQty': acceptedQty,
        'rejectedQty': rejectedQty,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return _unwrap(res);
  }

  // ── Templates ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listTemplates() async {
    final res = await _api.get('/api/v1/manufacturing/qc/templates');
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> createTemplate({
    required String name,
    String? itemId,
    required String inspectionType,
    List<Map<String, dynamic>> parameters = const [],
  }) async {
    final res = await _api.post(
      '/api/v1/manufacturing/qc/templates',
      data: {
        'name': name,
        if (itemId != null && itemId.isNotEmpty) 'itemId': itemId,
        'inspectionType': inspectionType,
        'parameters': parameters,
      },
    );
    return _unwrap(res);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

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
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
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
