import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bill_repository.dart';

/// Holds the current filter state for the bill list.
class BillListFilter {
  final String? status;
  final String? contactId;
  final String? branchId;
  final String? search;
  final int page;

  const BillListFilter({
    this.status,
    this.contactId,
    this.branchId,
    this.search,
    this.page = 0,
  });

  BillListFilter copyWith({
    String? status,
    String? contactId,
    String? branchId,
    String? search,
    int? page,
  }) {
    return BillListFilter(
      status: status ?? this.status,
      contactId: contactId ?? this.contactId,
      branchId: branchId ?? this.branchId,
      search: search ?? this.search,
      page: page ?? this.page,
    );
  }
}

final billFilterProvider =
    StateProvider<BillListFilter>((ref) => const BillListFilter());

/// Fetches bills based on current filter.
final billListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(billFilterProvider);
  final repo = ref.watch(billRepositoryProvider);
  return repo.listBills(
    page: filter.page,
    status: filter.status,
    contactId: filter.contactId,
    branchId: filter.branchId,
    search: filter.search,
  );
});

/// Fetches a single bill by ID.
final billDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(billRepositoryProvider);
    return repo.getBill(id);
  },
);

/// Fetches payments for a specific bill.
final billPaymentsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, billId) async {
    final repo = ref.watch(billRepositoryProvider);
    return repo.getBillPayments(billId);
  },
);
