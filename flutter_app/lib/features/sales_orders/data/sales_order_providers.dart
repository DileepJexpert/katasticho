import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sales_order_repository.dart';

const _sentinel = Object();

class SalesOrderListFilter {
  final String? status;
  final String? search;
  final int page;
  final int size;

  const SalesOrderListFilter({
    this.status,
    this.search,
    this.page = 0,
    this.size = 20,
  });

  SalesOrderListFilter copyWith({
    Object? status = _sentinel,
    Object? search = _sentinel,
    int? page,
    int? size,
  }) {
    return SalesOrderListFilter(
      status: status == _sentinel ? this.status : status as String?,
      search: search == _sentinel ? this.search : search as String?,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }
}

final salesOrderFilterProvider =
    StateProvider<SalesOrderListFilter>((ref) => const SalesOrderListFilter());

final salesOrderListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(salesOrderFilterProvider);
  final repo = ref.watch(salesOrderRepositoryProvider);
  return repo.listSalesOrders(
    page: filter.page,
    size: filter.size,
    status: filter.status,
    search: filter.search,
  );
});

final salesOrderDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(salesOrderRepositoryProvider);
    return repo.getSalesOrder(id);
  },
);
