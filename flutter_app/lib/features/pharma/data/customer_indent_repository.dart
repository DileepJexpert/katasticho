import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

class CustomerIndentRepository {
  final ApiClient _api;

  CustomerIndentRepository(this._api);

  Future<List<Map<String, dynamic>>> list({
    String? status,
    int page = 0,
    int size = 50,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    debugPrint('[CustomerIndentRepo] list params=$params');
    final res = await _api.get(
      ApiConfig.customerIndents,
      queryParameters: params,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is List) return inner.cast<Map<String, dynamic>>();
      if (inner is Map) {
        final content = inner['content'];
        if (content is List) return content.cast<Map<String, dynamic>>();
      }
    }
    return const [];
  }

  Future<Map<String, dynamic>> getById(String id) async {
    final res = await _api.get(ApiConfig.customerIndentById(id));
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return {};
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    debugPrint('[CustomerIndentRepo] create body=$body');
    final res = await _api.post(ApiConfig.customerIndents, data: body);
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return {};
  }

  Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    final res = await _api.post(
      ApiConfig.customerIndentStatus(id),
      data: {'status': status},
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return {};
  }

  Future<void> cancel(String id) async {
    await _api.delete(ApiConfig.customerIndentById(id));
  }
}

final customerIndentRepositoryProvider =
    Provider<CustomerIndentRepository>((ref) {
  return CustomerIndentRepository(ref.watch(apiClientProvider));
});

final customerIndentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(customerIndentRepositoryProvider).list();
});

final customerIndentDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) => ref.watch(customerIndentRepositoryProvider).getById(id),
);
