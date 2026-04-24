import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository(ref.watch(apiClientProvider));
});

class JournalRepository {
  final ApiClient _api;

  JournalRepository(this._api);

  Future<Map<String, dynamic>> listJournals({
    int page = 0,
    int size = 20,
    String? sourceModule,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (sourceModule != null) 'sourceModule': sourceModule,
      if (dateFrom != null) 'dateFrom': dateFrom,
      if (dateTo != null) 'dateTo': dateTo,
      if (search != null) 'search': search,
    };
    final response =
        await _api.get(ApiConfig.journalEntries, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getJournal(String id) async {
    final response = await _api.get('${ApiConfig.journalEntries}/$id');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createJournal(
      Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.journalEntries, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postJournal(String id) async {
    final response =
        await _api.post('${ApiConfig.journalEntries}/$id/post');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reverseJournal(String id) async {
    final response =
        await _api.post('${ApiConfig.journalEntries}/$id/reverse');
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteJournal(String id) async {
    await _api.delete('${ApiConfig.journalEntries}/$id');
  }
}

/// Holds the current filter state for the journal list.
class JournalListFilter {
  final String? sourceModule;
  final String? dateFrom;
  final String? dateTo;
  final String? search;
  final int page;

  const JournalListFilter({
    this.sourceModule,
    this.dateFrom,
    this.dateTo,
    this.search,
    this.page = 0,
  });

  JournalListFilter copyWith({
    String? sourceModule,
    String? dateFrom,
    String? dateTo,
    String? search,
    int? page,
  }) {
    return JournalListFilter(
      sourceModule: sourceModule ?? this.sourceModule,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      search: search ?? this.search,
      page: page ?? this.page,
    );
  }
}

final journalFilterProvider =
    StateProvider<JournalListFilter>((ref) => const JournalListFilter());

/// Fetches journals based on current filter.
final journalListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(journalFilterProvider);
  final repo = ref.watch(journalRepositoryProvider);
  return repo.listJournals(
    page: filter.page,
    sourceModule: filter.sourceModule,
    dateFrom: filter.dateFrom,
    dateTo: filter.dateTo,
    search: filter.search,
  );
});

/// Fetches a single journal entry by ID.
final journalDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(journalRepositoryProvider);
    return repo.getJournal(id);
  },
);
