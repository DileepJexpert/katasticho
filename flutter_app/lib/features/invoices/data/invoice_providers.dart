import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../payments/data/payment_repository.dart';
import 'invoice_repository.dart';

const _sentinel = Object();

/// Holds the current filter state for the invoice list.
class InvoiceListFilter {
  final String? status;
  final String? search;
  final int page;

  const InvoiceListFilter({this.status, this.search, this.page = 0});

  InvoiceListFilter copyWith({Object? status = _sentinel, Object? search = _sentinel, int? page}) {
    return InvoiceListFilter(
      status: status == _sentinel ? this.status : status as String?,
      search: search == _sentinel ? this.search : search as String?,
      page: page ?? this.page,
    );
  }
}

final invoiceFilterProvider =
    StateProvider<InvoiceListFilter>((ref) => const InvoiceListFilter());

/// Fetches invoices based on current filter.
final invoiceListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(invoiceFilterProvider);
  final repo = ref.watch(invoiceRepositoryProvider);
  return repo.listInvoices(
    page: filter.page,
    status: filter.status,
    search: filter.search,
  );
});

/// Fetches a single invoice by ID.
final invoiceDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(invoiceRepositoryProvider);
    return repo.getInvoice(id);
  },
);

/// Fetches the list of payments recorded against an invoice.
final invoicePaymentsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
  (ref, invoiceId) async {
    final repo = ref.watch(paymentRepositoryProvider);
    final result = await repo.listPaymentsForInvoice(invoiceId);
    final data = result['data'];
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return const [];
  },
);
