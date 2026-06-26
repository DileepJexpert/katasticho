import 'package:dio/dio.dart';
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

/// Non-Conformance Reports, optionally filtered by status (''/OPEN/IN_PROGRESS/CLOSED).
final ncrsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, status) => ref
      .watch(qcRepositoryProvider)
      .listNcrs(status: status.isEmpty ? null : status),
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

  // ── Disposition + CoA ─────────────────────────────────────────────────────

  /// ACCEPT / REJECT / HOLD a finalized inspection (V65). REJECT writes a
  /// negative ADJUSTMENT movement + auto-opens an NCR; HOLD needs a
  /// quarantine zone.
  Future<Map<String, dynamic>> recordDisposition(
    String id, {
    required String decision,
    double? acceptedQty,
    double? rejectedQty,
    double? holdQty,
    String? quarantineZoneId,
    String? notes,
  }) async {
    final res = await _api.post(
      '/api/v1/manufacturing/qc-inspections/$id/disposition',
      data: {
        'decision': decision,
        if (acceptedQty != null) 'acceptedQty': acceptedQty,
        if (rejectedQty != null) 'rejectedQty': rejectedQty,
        if (holdQty != null) 'holdQty': holdQty,
        if (quarantineZoneId != null && quarantineZoneId.isNotEmpty)
          'quarantineZoneId': quarantineZoneId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return _unwrap(res);
  }

  /// Certificate of Analysis JSON for a finalized inspection.
  Future<Map<String, dynamic>> getCoa(String id) async {
    final res = await _api.get('/api/v1/manufacturing/qc-inspections/$id/coa');
    return _unwrap(res);
  }

  // ── Non-Conformance Reports ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listNcrs({String? status}) async {
    final res = await _api.get(
      '/api/v1/manufacturing/qc/ncrs',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> getNcr(String id) async {
    final res = await _api.get('/api/v1/manufacturing/qc/ncrs/$id');
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> createNcr({
    String? qcInspectionId,
    required String itemId,
    String? batchNumber,
    required String severity,
    required String reason,
    String? description,
  }) async {
    final res = await _api.post(
      '/api/v1/manufacturing/qc/ncrs',
      data: {
        if (qcInspectionId != null && qcInspectionId.isNotEmpty)
          'qcInspectionId': qcInspectionId,
        'itemId': itemId,
        if (batchNumber != null && batchNumber.isNotEmpty)
          'batchNumber': batchNumber,
        'severity': severity,
        'reason': reason,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> updateNcr(
    String id, {
    String? correctiveAction,
    String? rootCause,
    String? status,
  }) async {
    final res = await _api.put(
      '/api/v1/manufacturing/qc/ncrs/$id',
      data: {
        if (correctiveAction != null) 'correctiveAction': correctiveAction,
        if (rootCause != null) 'rootCause': rootCause,
        if (status != null) 'status': status,
      },
    );
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> closeNcr(String id) async {
    final res = await _api.post('/api/v1/manufacturing/qc/ncrs/$id/close');
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

  // NOTE: ApiClient.get/post return a Dio Response, so the body lives under
  // `.data`. The old helpers checked `res is Map` (always false for a
  // Response) and silently returned empty — every QC fetch came back blank.
  Map<String, dynamic> _unwrap(dynamic res) {
    final body = res is Response ? res.data : res;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    return {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic res) {
    final body = res is Response ? res.data : res;
    if (body is Map) {
      final data = body['data'];
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
