import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import 'scheme_models.dart';

class SchemeRepository {
  final ApiClient _client;
  SchemeRepository(this._client);

  Future<List<Map<String, dynamic>>> listSchemes() async {
    debugPrint('[SchemeRepo] listSchemes');
    try {
      final res = await _client.get(ApiConfig.schemes);
      final data = (res.data as Map<String, dynamic>)['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return const [];
    } catch (e, st) {
      debugPrint('[SchemeRepo] listSchemes FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createScheme(Map<String, dynamic> body) async {
    debugPrint('[SchemeRepo] createScheme body=$body');
    try {
      final res = await _client.post(ApiConfig.schemes, data: body);
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[SchemeRepo] createScheme FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteScheme(String id) async {
    debugPrint('[SchemeRepo] deleteScheme id=$id');
    try {
      await _client.delete(ApiConfig.schemeById(id));
    } catch (e, st) {
      debugPrint('[SchemeRepo] deleteScheme FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getApplicable(
      String itemId, double qty) async {
    debugPrint('[SchemeRepo] getApplicable itemId=$itemId qty=$qty');
    try {
      final res = await _client.get(
        '/api/v1/schemes/applicable',
        queryParameters: {'itemId': itemId, 'quantity': qty},
      );
      final data = (res.data as Map<String, dynamic>)['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return const [];
    } catch (e, st) {
      debugPrint('[SchemeRepo] getApplicable FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<SchemeCalculationResult> evaluateScheme({
    required String itemId,
    required double quantity,
    required double unitPrice,
    String? schemeId,
  }) async {
    debugPrint('[SchemeRepo] evaluateScheme itemId=$itemId qty=$quantity price=$unitPrice');
    try {
      final res = await _client.post(
        '/api/v1/schemes/evaluate',
        data: {
          'itemId': itemId,
          'quantity': quantity,
          'unitPrice': unitPrice,
          if (schemeId != null) 'schemeId': schemeId,
        },
      );
      final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      return SchemeCalculationResult.fromJson(data);
    } catch (e, st) {
      debugPrint('[SchemeRepo] evaluateScheme FAILED: $e\n$st');
      rethrow;
    }
  }
}

final schemeRepositoryProvider = Provider<SchemeRepository>((ref) {
  return SchemeRepository(ref.watch(apiClientProvider));
});

final schemesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.watch(schemeRepositoryProvider).listSchemes();
});

class ApplicableSchemeLookup {
  final String itemId;
  final double quantity;

  const ApplicableSchemeLookup({
    required this.itemId,
    required this.quantity,
  });

  @override
  bool operator ==(Object other) {
    return other is ApplicableSchemeLookup &&
        other.itemId == itemId &&
        other.quantity == quantity;
  }

  @override
  int get hashCode => Object.hash(itemId, quantity);
}

final applicableSchemesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ApplicableSchemeLookup>((ref, lookup) {
  return ref
      .watch(schemeRepositoryProvider)
      .getApplicable(lookup.itemId, lookup.quantity);
});
