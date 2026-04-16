import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final posRepositoryProvider = Provider<PosRepository>((ref) {
  return PosRepository(ref.watch(apiClientProvider));
});

class PosRepository {
  final ApiClient _api;

  PosRepository(this._api);

  /// Fast POS item search — ranked: barcode > SKU > name.
  Future<List<Map<String, dynamic>>> posSearch({
    required String query,
    String? branchId,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'q': query,
      'limit': limit,
      if (branchId != null) 'branch_id': branchId,
    };
    final response =
        await _api.get(ApiConfig.posSearch, queryParameters: params);
    final data = response.data as Map<String, dynamic>;
    return (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  /// Create a sales receipt (immediate POS transaction).
  Future<Map<String, dynamic>> createReceipt(
      Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.salesReceipts, data: data);
    return response.data as Map<String, dynamic>;
  }

  /// Get receipt by ID.
  Future<Map<String, dynamic>> getReceipt(String id) async {
    final response = await _api.get(ApiConfig.salesReceiptById(id));
    return response.data as Map<String, dynamic>;
  }

  /// Download receipt PDF bytes (58mm thermal format).
  Future<List<int>> printReceipt(String id) async {
    final response = await _api.dio.get<List<int>>(
      ApiConfig.salesReceiptPrint(id),
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  /// Get a shareable WhatsApp link for a receipt.
  Future<Map<String, dynamic>> getWhatsAppLink(String id) async {
    final response = await _api.post(
      ApiConfig.salesReceiptWhatsAppLink(id),
    );
    return response.data as Map<String, dynamic>;
  }

  /// List receipts with filters.
  Future<Map<String, dynamic>> listReceipts({
    int page = 0,
    int size = 20,
    String? branchId,
    String? dateFrom,
    String? dateTo,
    String? paymentMode,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (branchId != null) 'branchId': branchId,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
      if (paymentMode != null) 'paymentMode': paymentMode,
    };
    final response =
        await _api.get(ApiConfig.salesReceipts, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }
}
