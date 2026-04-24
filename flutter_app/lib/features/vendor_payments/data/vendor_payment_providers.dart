import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vendor_payment_repository.dart';

const _sentinel = Object();

/// Holds the current filter state for the vendor payment list.
class VendorPaymentListFilter {
  final String? contactId;
  final String? dateFrom;
  final String? dateTo;
  final int page;

  const VendorPaymentListFilter({
    this.contactId,
    this.dateFrom,
    this.dateTo,
    this.page = 0,
  });

  VendorPaymentListFilter copyWith({
    Object? contactId = _sentinel,
    Object? dateFrom = _sentinel,
    Object? dateTo = _sentinel,
    int? page,
  }) {
    return VendorPaymentListFilter(
      contactId: contactId == _sentinel ? this.contactId : contactId as String?,
      dateFrom: dateFrom == _sentinel ? this.dateFrom : dateFrom as String?,
      dateTo: dateTo == _sentinel ? this.dateTo : dateTo as String?,
      page: page ?? this.page,
    );
  }
}

final vendorPaymentFilterProvider =
    StateProvider<VendorPaymentListFilter>(
        (ref) => const VendorPaymentListFilter());

/// Fetches vendor payments based on current filter.
final vendorPaymentListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(vendorPaymentFilterProvider);
  final repo = ref.watch(vendorPaymentRepositoryProvider);
  return repo.listPayments(
    page: filter.page,
    contactId: filter.contactId,
    dateFrom: filter.dateFrom,
    dateTo: filter.dateTo,
  );
});

/// Fetches a single vendor payment by ID.
final vendorPaymentDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(vendorPaymentRepositoryProvider);
    return repo.getPayment(id);
  },
);
