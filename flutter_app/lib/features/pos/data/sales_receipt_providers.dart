import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pos_repository.dart';

class ReceiptListFilter {
  final String? paymentMode;
  final String? dateFrom;
  final String? dateTo;
  final int page;

  const ReceiptListFilter({this.paymentMode, this.dateFrom, this.dateTo, this.page = 0});

  ReceiptListFilter copyWith({String? paymentMode, String? dateFrom, String? dateTo, int? page}) {
    return ReceiptListFilter(
      paymentMode: paymentMode ?? this.paymentMode,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      page: page ?? this.page,
    );
  }
}

final receiptFilterProvider =
    StateProvider<ReceiptListFilter>((ref) => const ReceiptListFilter());

final receiptListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(receiptFilterProvider);
  final repo = ref.watch(posRepositoryProvider);
  return repo.listReceipts(
    page: filter.page,
    paymentMode: filter.paymentMode,
    dateFrom: filter.dateFrom,
    dateTo: filter.dateTo,
  );
});

final receiptDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(posRepositoryProvider);
    return repo.getReceipt(id);
  },
);
