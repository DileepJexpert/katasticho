import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'delivery_challan_repository.dart';

class DeliveryChallanListFilter {
  final String? status;
  final String? search;
  final String? salesOrderId;
  final int page;
  final int size;

  const DeliveryChallanListFilter({
    this.status,
    this.search,
    this.salesOrderId,
    this.page = 0,
    this.size = 20,
  });

  DeliveryChallanListFilter copyWith({
    String? status,
    String? search,
    String? salesOrderId,
    int? page,
    int? size,
  }) {
    return DeliveryChallanListFilter(
      status: status ?? this.status,
      search: search ?? this.search,
      salesOrderId: salesOrderId ?? this.salesOrderId,
      page: page ?? this.page,
      size: size ?? this.size,
    );
  }
}

final deliveryChallanFilterProvider =
    StateProvider<DeliveryChallanListFilter>((ref) => const DeliveryChallanListFilter());

final deliveryChallanListProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final filter = ref.watch(deliveryChallanFilterProvider);
  final repo = ref.watch(deliveryChallanRepositoryProvider);
  return repo.listDeliveryChallans(
    page: filter.page,
    size: filter.size,
    status: filter.status,
    search: filter.search,
    salesOrderId: filter.salesOrderId,
  );
});

final deliveryChallanDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) async {
    final repo = ref.watch(deliveryChallanRepositoryProvider);
    return repo.getDeliveryChallan(id);
  },
);
