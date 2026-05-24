import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

class DrugLicenseRepository {
  final ApiClient _client;
  DrugLicenseRepository(this._client);

  Future<List<Map<String, dynamic>>> list() async {
    debugPrint('[DrugLicenseRepo] list');
    try {
      final res = await _client.get(ApiConfig.drugLicenses);
      final data = (res.data as Map<String, dynamic>)['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return const [];
    } catch (e, st) {
      debugPrint('[DrugLicenseRepo] list FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    debugPrint('[DrugLicenseRepo] create body=$body');
    try {
      final res = await _client.post(ApiConfig.drugLicenses, data: body);
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[DrugLicenseRepo] create FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    debugPrint('[DrugLicenseRepo] update id=$id body=$body');
    try {
      final res =
          await _client.put(ApiConfig.drugLicenseById(id), data: body);
      return (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[DrugLicenseRepo] update FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    debugPrint('[DrugLicenseRepo] delete id=$id');
    try {
      await _client.delete(ApiConfig.drugLicenseById(id));
    } catch (e, st) {
      debugPrint('[DrugLicenseRepo] delete FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getExpiring({int days = 30}) async {
    debugPrint('[DrugLicenseRepo] getExpiring days=$days');
    try {
      final res = await _client.get(
        ApiConfig.drugLicensesExpiring,
        queryParameters: {'days': days},
      );
      final data = (res.data as Map<String, dynamic>)['data'];
      if (data is List) return data.cast<Map<String, dynamic>>();
      return const [];
    } catch (e, st) {
      debugPrint('[DrugLicenseRepo] getExpiring FAILED: $e\n$st');
      rethrow;
    }
  }
}

final drugLicenseRepositoryProvider = Provider<DrugLicenseRepository>((ref) {
  return DrugLicenseRepository(ref.watch(apiClientProvider));
});

final drugLicensesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(drugLicenseRepositoryProvider).list();
});

final expiringLicensesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(drugLicenseRepositoryProvider).getExpiring(days: 60);
});
