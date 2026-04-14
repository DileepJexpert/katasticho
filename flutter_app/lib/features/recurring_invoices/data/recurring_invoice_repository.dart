import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final recurringInvoiceRepositoryProvider =
    Provider<RecurringInvoiceRepository>((ref) {
  return RecurringInvoiceRepository(ref.watch(apiClientProvider));
});

/// Filter bundle for the list provider — value-equal so Riverpod
/// can cache pages per-filter.
class RecurringInvoiceFilters {
  final String? status;

  const RecurringInvoiceFilters({this.status});

  @override
  bool operator ==(Object other) =>
      other is RecurringInvoiceFilters && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

class RecurringInvoiceRepository {
  final ApiClient _api;

  RecurringInvoiceRepository(this._api);

  Future<Map<String, dynamic>> listTemplates({
    int page = 0,
    int size = 20,
    String? status,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    debugPrint('[RecurringInvoiceRepo] list params: $params');
    final response =
        await _api.get(ApiConfig.recurringInvoices, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTemplate(String id) async {
    final response = await _api.get(ApiConfig.recurringInvoiceById(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.recurringInvoices, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTemplate(
      String id, Map<String, dynamic> data) async {
    final response =
        await _api.put(ApiConfig.recurringInvoiceById(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> stopTemplate(String id) async {
    final response = await _api.post(ApiConfig.stopRecurringInvoice(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resumeTemplate(String id) async {
    final response = await _api.post(ApiConfig.resumeRecurringInvoice(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateNow(String id) async {
    final response = await _api.post(ApiConfig.generateRecurringInvoice(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generatedInvoices(String id) async {
    final response = await _api.get(ApiConfig.recurringInvoiceGenerated(id));
    return response.data as Map<String, dynamic>;
  }
}

// ── Providers ──

final recurringInvoiceListProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, RecurringInvoiceFilters>(
  (ref, filters) async {
    final repo = ref.watch(recurringInvoiceRepositoryProvider);
    return repo.listTemplates(status: filters.status);
  },
);

final recurringInvoiceDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(recurringInvoiceRepositoryProvider);
    return repo.getTemplate(id);
  },
);

/// List of invoices generated from a template — used on the detail
/// screen's "Generated invoices" panel.
final recurringGeneratedProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, id) async {
    final repo = ref.watch(recurringInvoiceRepositoryProvider);
    final resp = await repo.generatedInvoices(id);
    final data = resp['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return const <Map<String, dynamic>>[];
  },
);
