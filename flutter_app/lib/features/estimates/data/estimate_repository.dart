import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final estimateRepositoryProvider = Provider<EstimateRepository>((ref) {
  return EstimateRepository(ref.watch(apiClientProvider));
});

/// Filter bundle for the list provider. Immutable + value equality so
/// Riverpod can cache based on it.
class EstimateFilters {
  final String? status;
  final String? contactId;

  const EstimateFilters({this.status, this.contactId});

  @override
  bool operator ==(Object other) =>
      other is EstimateFilters &&
      other.status == status &&
      other.contactId == contactId;

  @override
  int get hashCode => Object.hash(status, contactId);
}

class EstimateRepository {
  final ApiClient _api;

  EstimateRepository(this._api);

  Future<Map<String, dynamic>> listEstimates({
    int page = 0,
    int size = 20,
    String? status,
    String? contactId,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null && status.isNotEmpty) 'status': status,
      if (contactId != null) 'contactId': contactId,
    };
    debugPrint('[EstimateRepo] listEstimates params: $params');
    final response = await _api.get(ApiConfig.estimates, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEstimate(String id) async {
    debugPrint('[EstimateRepo] getEstimate id: $id');
    final response = await _api.get(ApiConfig.estimateById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEstimate(Map<String, dynamic> data) async {
    debugPrint('[EstimateRepo] createEstimate: $data');
    final response = await _api.post(ApiConfig.estimates, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEstimate(
      String id, Map<String, dynamic> data) async {
    debugPrint('[EstimateRepo] updateEstimate id: $id');
    final response = await _api.put(ApiConfig.estimateById(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteEstimate(String id) async {
    debugPrint('[EstimateRepo] deleteEstimate id: $id');
    await _api.delete(ApiConfig.estimateById(id));
  }

  Future<Map<String, dynamic>> sendEstimate(String id) async {
    final response = await _api.post(ApiConfig.sendEstimate(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptEstimate(String id) async {
    final response = await _api.post(ApiConfig.acceptEstimate(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> declineEstimate(String id) async {
    final response = await _api.post(ApiConfig.declineEstimate(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> convertToInvoice(String id) async {
    final response = await _api.post(ApiConfig.convertEstimate(id));
    return response.data as Map<String, dynamic>;
  }
}

// ── Providers ──

final estimateListProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, EstimateFilters>(
  (ref, filters) async {
    final repo = ref.watch(estimateRepositoryProvider);
    return repo.listEstimates(status: filters.status, contactId: filters.contactId);
  },
);

final estimateDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(estimateRepositoryProvider);
    return repo.getEstimate(id);
  },
);
