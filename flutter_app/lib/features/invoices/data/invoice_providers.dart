import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'invoice_repository.dart';

/// Holds the current filter state for the invoice list.
class InvoiceListFilter {
  final String? status;
  final String? search;
  final int page;

  const InvoiceListFilter({this.status, this.search, this.page = 0});

  InvoiceListFilter copyWith({String? status, String? search, int? page}) {
    return InvoiceListFilter(
      status: status ?? this.status,
      search: search ?? this.search,
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
