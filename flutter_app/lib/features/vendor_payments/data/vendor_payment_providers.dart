import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vendor_payment_repository.dart';

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
    String? contactId,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) {
    return VendorPaymentListFilter(
      contactId: contactId ?? this.contactId,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
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
