import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

class DebitNoteRepository {
  final ApiClient _api;

  DebitNoteRepository(this._api);

  Future<List<Map<String, dynamic>>> list({
    String? status,
    String? supplierId,
    int page = 0,
    int size = 50,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null) 'status': status,
      if (supplierId != null) 'supplierId': supplierId,
    };
    debugPrint('[DebitNoteRepo] list params=$params');
    try {
      final res = await _api.get(ApiConfig.debitNotes, queryParameters: params);
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
    } catch (e, st) {
      debugPrint('[DebitNoteRepo] list FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getById(String id) async {
    debugPrint('[DebitNoteRepo] getById id=$id');
    try {
      final res = await _api.get(ApiConfig.debitNoteById(id));
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) return inner;
        return data;
      }
      return {};
    } catch (e, st) {
      debugPrint('[DebitNoteRepo] getById FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    debugPrint('[DebitNoteRepo] create body=$body');
    try {
      final res = await _api.post(ApiConfig.debitNotes, data: body);
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) return inner;
        return data;
      }
      return {};
    } catch (e, st) {
      debugPrint('[DebitNoteRepo] create FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submit(String id) async {
    debugPrint('[DebitNoteRepo] submit id=$id');
    try {
      final res = await _api.post(ApiConfig.submitDebitNote(id));
      final data = res.data;
      if (data is Map<String, dynamic>) {
        final inner = data['data'];
        if (inner is Map<String, dynamic>) return inner;
        return data;
      }
      return {};
    } catch (e, st) {
      debugPrint('[DebitNoteRepo] submit FAILED: $e\n$st');
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    debugPrint('[DebitNoteRepo] delete id=$id');
    try {
      await _api.delete(ApiConfig.debitNoteById(id));
    } catch (e, st) {
      debugPrint('[DebitNoteRepo] delete FAILED: $e\n$st');
      rethrow;
    }
  }
}

final debitNoteRepositoryProvider = Provider<DebitNoteRepository>((ref) {
  return DebitNoteRepository(ref.watch(apiClientProvider));
});

final debitNotesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(debitNoteRepositoryProvider).list();
});

final debitNoteDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) => ref.watch(debitNoteRepositoryProvider).getById(id),
);
