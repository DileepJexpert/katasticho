import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vendor_credit_repository.dart';

const _sentinel = Object();

/// Filter state for the vendor credit list.
class VendorCreditListFilter {
  final String? status;
  final String? contactId;
  final int page;

  const VendorCreditListFilter({
    this.status,
    this.contactId,
    this.page = 0,
  });

  VendorCreditListFilter copyWith({
    Object? status = _sentinel,
    Object? contactId = _sentinel,
    int? page,
  }) {
    return VendorCreditListFilter(
      status: status == _sentinel ? this.status : status as String?,
      contactId: contactId == _sentinel ? this.contactId : contactId as String?,
      page: page ?? this.page,
    );
  }
}

final vendorCreditFilterProvider =
    StateProvider<VendorCreditListFilter>(
        (ref) => const VendorCreditListFilter());

/// Fetches vendor credits based on current filter.
final vendorCreditListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(vendorCreditFilterProvider);
  final repo = ref.watch(vendorCreditRepositoryProvider);
  return repo.listCredits(
    page: filter.page,
    status: filter.status,
    contactId: filter.contactId,
  );
});

/// Fetches a single vendor credit by ID.
final vendorCreditDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(vendorCreditRepositoryProvider);
    return repo.getCredit(id);
  },
);
