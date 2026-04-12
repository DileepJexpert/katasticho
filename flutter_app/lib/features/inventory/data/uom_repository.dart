import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// Thin client over the UoM REST endpoints. Kept read-only for now —
/// every v2 screen that touches quantities (BOM, FEFO selling, price
/// lists, stock counts) will pull its UoM dropdowns through here so we
/// never rebuild the lookup logic feature-by-feature.
final uomRepositoryProvider = Provider<UomRepository>((ref) {
  return UomRepository(ref.watch(apiClientProvider));
});

class UomRepository {
  final ApiClient _api;

  UomRepository(this._api);

  /// Lists UoMs for the current org. Optionally filtered by category
  /// (e.g. only WEIGHT units when the user is entering a grams/kg field).
  Future<List<Map<String, dynamic>>> listUoms({String? category}) async {
    final params = <String, dynamic>{
      if (category != null && category.isNotEmpty) 'category': category,
    };
    debugPrint('[UomRepo] listUoms params=$params');
    try {
      final response = await _api.get(ApiConfig.uoms, queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final payload = data['data'];
      if (payload is List) {
        return payload.cast<Map<String, dynamic>>();
      }
      return const [];
    } on DioException catch (e, st) {
      debugPrint('[UomRepo] listUoms FAILED: ${e.message}\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getUom(String id) async {
    final response = await _api.get(ApiConfig.uomById(id));
    return response.data as Map<String, dynamic>;
  }
}
