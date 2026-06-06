import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final partnerNetworkRepositoryProvider = Provider((ref) {
  return PartnerNetworkRepository(ref.watch(apiClientProvider));
});

final partnersProvider = FutureProvider((ref) {
  return ref.watch(partnerNetworkRepositoryProvider).listPartners();
});

final pendingPartnersProvider = FutureProvider((ref) {
  return ref.watch(partnerNetworkRepositoryProvider).listPendingRequests();
});

final catalogProvider = FutureProvider((ref) {
  return ref.watch(partnerNetworkRepositoryProvider).listCatalog();
});

final outgoingOrdersProvider = FutureProvider((ref) {
  return ref.watch(partnerNetworkRepositoryProvider).listOutgoingOrders();
});

final incomingOrdersProvider = FutureProvider((ref) {
  return ref.watch(partnerNetworkRepositoryProvider).listIncomingOrders();
});

class PartnerNetworkRepository {
  PartnerNetworkRepository(this._api);
  final ApiClient _api;

  // ── Trading Partners ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listPartners() async {
    final res = await _api.get(ApiConfig.partnerNetworkPartners);
    return _unwrapList(res);
  }

  Future<List<Map<String, dynamic>>> listPendingRequests() async {
    final res = await _api.get(ApiConfig.partnerNetworkPartnersPending);
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> getPartner(String id) async {
    final res = await _api.get(ApiConfig.partnerNetworkPartnerById(id));
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> requestPartnership({
    required String targetOrgId,
    required String role,
    double? creditLimit,
    String? paymentTerms,
    String? deliveryTerms,
    String? notes,
  }) async {
    final res = await _api.post(ApiConfig.partnerNetworkPartnerRequest, data: {
      'targetOrgId': targetOrgId,
      'role': role,
      if (creditLimit != null) 'creditLimit': creditLimit,
      if (paymentTerms != null) 'paymentTerms': paymentTerms,
      if (deliveryTerms != null) 'deliveryTerms': deliveryTerms,
      if (notes != null) 'notes': notes,
    });
    return _unwrap(res);
  }

  Future<void> approvePartner(String id) async {
    await _api.post(ApiConfig.partnerNetworkPartnerApprove(id));
  }

  Future<void> rejectPartner(String id) async {
    await _api.post(ApiConfig.partnerNetworkPartnerReject(id));
  }

  Future<void> suspendPartner(String id) async {
    await _api.post(ApiConfig.partnerNetworkPartnerSuspend(id));
  }

  // ── Published Catalog ─────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listCatalog() async {
    final res = await _api.get(ApiConfig.partnerNetworkCatalog);
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> publishCatalogItem(Map<String, dynamic> data) async {
    final res = await _api.post(ApiConfig.partnerNetworkCatalog, data: data);
    return _unwrap(res);
  }

  Future<void> unpublishCatalogItem(String id) async {
    await _api.post(ApiConfig.partnerNetworkCatalogUnpublish(id));
  }

  // ── Supplier Search ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchSuppliers({String? search}) async {
    final res = await _api.get(
      ApiConfig.partnerNetworkSupplierSearch,
      queryParameters: {if (search != null && search.isNotEmpty) 'search': search},
    );
    return _unwrapList(res);
  }

  Future<List<Map<String, dynamic>>> searchByDrug(String drugMasterId) async {
    final res = await _api.get(ApiConfig.partnerNetworkSupplierSearchByDrug(drugMasterId));
    return _unwrapList(res);
  }

  // ── Network Orders ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listOutgoingOrders() async {
    final res = await _api.get(ApiConfig.partnerNetworkOrdersOutgoing);
    return _unwrapList(res);
  }

  Future<List<Map<String, dynamic>>> listIncomingOrders() async {
    final res = await _api.get(ApiConfig.partnerNetworkOrdersIncoming);
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> getOrder(String id) async {
    final res = await _api.get(ApiConfig.partnerNetworkOrderById(id));
    return _unwrap(res);
  }

  Future<List<Map<String, dynamic>>> getOrderEvents(String id) async {
    final res = await _api.get(ApiConfig.partnerNetworkOrderEvents(id));
    return _unwrapList(res);
  }

  Future<Map<String, dynamic>> placeOrder(Map<String, dynamic> data) async {
    final res = await _api.post(ApiConfig.partnerNetworkOrders, data: data);
    return _unwrap(res);
  }

  Future<void> confirmOrder(String id, Map<String, dynamic> data) async {
    await _api.post(ApiConfig.partnerNetworkOrderConfirm(id), data: data);
  }

  Future<void> rejectOrder(String id, {String? reason}) async {
    await _api.post(ApiConfig.partnerNetworkOrderReject(id), data: {
      if (reason != null) 'reason': reason,
    });
  }

  Future<void> cancelOrder(String id) async {
    await _api.post(ApiConfig.partnerNetworkOrderCancel(id));
  }

  Future<void> markDispatched(String id) async {
    await _api.post(ApiConfig.partnerNetworkOrderDispatch(id));
  }

  Future<void> markDelivered(String id) async {
    await _api.post(ApiConfig.partnerNetworkOrderDeliver(id));
  }

  // ── Helpers ───────────────────────────────────────────────────

  Map<String, dynamic> _unwrap(dynamic res) {
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      if (data is Map<String, dynamic>) return data;
      return res;
    }
    return {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic res) {
    if (res is Map<String, dynamic>) {
      final data = res['data'];
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map) {
        final content = data['content'];
        if (content is List) return content.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }
}
