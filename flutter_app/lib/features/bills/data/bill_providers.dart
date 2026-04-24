import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'bill_repository.dart';

const _sentinel = Object();

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
    Object? status = _sentinel,
    Object? contactId = _sentinel,
    Object? branchId = _sentinel,
    Object? search = _sentinel,
    int? page,
  }) {
    return BillListFilter(
      status: status == _sentinel ? this.status : status as String?,
      contactId: contactId == _sentinel ? this.contactId : contactId as String?,
      branchId: branchId == _sentinel ? this.branchId : branchId as String?,
      search: search == _sentinel ? this.search : search as String?,
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
