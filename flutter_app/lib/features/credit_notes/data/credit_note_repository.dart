import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final creditNoteRepositoryProvider = Provider<CreditNoteRepository>((ref) {
  return CreditNoteRepository(ref.watch(apiClientProvider));
});

class CreditNoteRepository {
  final ApiClient _api;

  CreditNoteRepository(this._api);

  Future<Map<String, dynamic>> listCreditNotes({
    int page = 0,
    int size = 20,
  }) async {
    final response = await _api.get(ApiConfig.creditNotes, queryParameters: {
      'page': page,
      'size': size,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCreditNote(String id) async {
    final response = await _api.get('${ApiConfig.creditNotes}/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCreditNote(
      Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.creditNotes, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> issueCreditNote(String id) async {
    final response = await _api.post(ApiConfig.issueCreditNote(id));
    return response.data as Map<String, dynamic>;
  }
}
