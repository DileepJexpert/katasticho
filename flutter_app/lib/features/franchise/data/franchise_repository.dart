import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final franchiseRepositoryProvider = Provider<FranchiseRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return FranchiseRepository(client);
});

final franchiseNodesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(franchiseRepositoryProvider);
  return repo.listNodes();
});

final franchisePolicyProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(franchiseRepositoryProvider);
  return repo.getPolicy();
});

final branchPriceOverridesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, branchId) async {
  final repo = ref.watch(franchiseRepositoryProvider);
  return repo.getBranchOverrides(branchId);
});

final franchiseSettlementsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, nodeId) async {
  final repo = ref.watch(franchiseRepositoryProvider);
  return repo.listSettlements(nodeId: nodeId);
});

class FranchiseRepository {
  final ApiClient _client;
  FranchiseRepository(this._client);

  Future<List<Map<String, dynamic>>> listNodes() async {
    final res = await _client.get(ApiConfig.franchiseNodes);
    final data = res.data['data'] as List? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createNode(Map<String, dynamic> payload) async {
    final res = await _client.post(ApiConfig.franchiseNodes, data: payload);
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> updateNode(String id, Map<String, dynamic> payload) async {
    final res = await _client.put(ApiConfig.franchiseNode(id), data: payload);
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> deleteNode(String id) async {
    await _client.delete(ApiConfig.franchiseNode(id));
  }

  Future<Map<String, dynamic>> getPolicy() async {
    final res = await _client.get(ApiConfig.franchisePolicy);
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> savePolicy(Map<String, dynamic> payload) async {
    final res = await _client.put(ApiConfig.franchisePolicy, data: payload);
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> pushCatalogSync(Map<String, dynamic> payload) async {
    final res = await _client.post(ApiConfig.franchiseCatalogSync, data: payload);
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<List<Map<String, dynamic>>> getBranchOverrides(String branchId) async {
    final res = await _client.get(ApiConfig.branchPriceOverrides(branchId));
    final data = res.data['data'] as List? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> savePriceOverride(Map<String, dynamic> payload) async {
    final res = await _client.post(ApiConfig.franchisePriceOverrides, data: payload);
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> deletePriceOverride(String id) async {
    await _client.delete(ApiConfig.franchisePriceOverride(id));
  }

  Future<List<Map<String, dynamic>>> listSettlements({String? nodeId}) async {
    final res = await _client.get(
      ApiConfig.franchiseSettlements,
      queryParameters: {if (nodeId != null) 'nodeId': nodeId},
    );
    final data = res.data['data'] as List? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> calculateSettlement(Map<String, dynamic> payload) async {
    final res = await _client.post(ApiConfig.franchiseSettlementCalculate, data: payload);
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> generateRoyaltyInvoice(String id) async {
    final res = await _client.post(ApiConfig.franchiseSettlementInvoice(id));
    return (res.data['data'] as Map<String, dynamic>?) ?? {};
  }
}