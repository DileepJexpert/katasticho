import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

class PrescriptionRepository {
  final ApiClient _client;
  PrescriptionRepository(this._client);

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    debugPrint('[PrescriptionRepo] create data=$data');
    try {
      final res = await _client.post(ApiConfig.prescriptions, data: data);
      final body = res.data as Map<String, dynamic>;
      return (body['data'] as Map<String, dynamic>?) ?? body;
    } catch (e, st) {
      debugPrint('[PrescriptionRepo] create FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getByContact(String contactId) async {
    debugPrint('[PrescriptionRepo] getByContact contactId=$contactId');
    try {
      final res = await _client.get(ApiConfig.prescriptionsByContact(contactId));
      final body = res.data as Map<String, dynamic>;
      final data = body['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return const [];
    } catch (e, st) {
      debugPrint('[PrescriptionRepo] getByContact FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getByReceipt(String receiptId) async {
    debugPrint('[PrescriptionRepo] getByReceipt receiptId=$receiptId');
    try {
      final res =
          await _client.get(ApiConfig.prescriptionsByReceipt(receiptId));
      final body = res.data as Map<String, dynamic>;
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (e, st) {
      debugPrint('[PrescriptionRepo] getByReceipt FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> list({int page = 1, int pageSize = 20}) async {
    debugPrint('[PrescriptionRepo] list page=$page');
    try {
      final res = await _client.get(
        ApiConfig.prescriptions,
        queryParameters: {'page': page, 'pageSize': pageSize},
      );
      final body = res.data as Map<String, dynamic>;
      final data = body['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return const [];
    } catch (e, st) {
      debugPrint('[PrescriptionRepo] list FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    debugPrint('[PrescriptionRepo] delete id=$id');
    try {
      await _client.delete(ApiConfig.prescriptionById(id));
    } catch (e, st) {
      debugPrint('[PrescriptionRepo] delete FAILED: $e\n$st');
      rethrow;
    }
  }
}

final prescriptionRepositoryProvider =
    Provider<PrescriptionRepository>((ref) {
  return PrescriptionRepository(ref.watch(apiClientProvider));
});

/// FutureProvider that loads all prescriptions for a given contact (patient).
final contactPrescriptionsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, contactId) {
  return ref.read(prescriptionRepositoryProvider).getByContact(contactId);
});
