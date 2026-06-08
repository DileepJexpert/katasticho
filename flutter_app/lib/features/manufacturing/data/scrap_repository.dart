import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final scrapRepositoryProvider = Provider((ref) {
  return ScrapRepository(ref.watch(apiClientProvider));
});

final scrapListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(scrapRepositoryProvider).listScrap();
});

final scrapReasonCodesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(scrapRepositoryProvider).listReasonCodes();
});

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class ScrapRepository {
  ScrapRepository(this._api);
  final ApiClient _api;

  static const _base = '/api/v1/manufacturing/scrap';

  Future<List<Map<String, dynamic>>> listScrap() async {
    final res = await _api.get(_base);
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> recordScrap({
    required String workOrderId,
    required String itemId,
    required double scrapQty,
    required String reasonCodeId,
    String? jobCardId,
    String? notes,
  }) async {
    final res = await _api.post(_base, data: {
      'workOrderId': workOrderId,
      'itemId': itemId,
      'scrapQty': scrapQty,
      'reasonCodeId': reasonCodeId,
      if (jobCardId != null && jobCardId.isNotEmpty) 'jobCardId': jobCardId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    return _unwrap(res);
  }

  Future<List<Map<String, dynamic>>> listScrapForWorkOrder(String workOrderId) async {
    final res = await _api.get('/api/v1/manufacturing/work-orders/$workOrderId/scrap');
    return _unwrapList(res);
  }

  Future<List<Map<String, dynamic>>> listReasonCodes() async {
    final res = await _api.get('$_base/reason-codes');
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> createReasonCode({
    required String code,
    required String description,
  }) async {
    final res = await _api.post('$_base/reason-codes', data: {
      'code': code,
      'description': description,
    });
    return _unwrap(res);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
