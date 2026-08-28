import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import 'job_work_models.dart';

final jobWorkRepositoryProvider = Provider<JobWorkRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return JobWorkRepository(client);
});

final jobWorkOrdersProvider =
    FutureProvider.autoDispose<List<JobWorkOrderModel>>((ref) async {
  final repo = ref.watch(jobWorkRepositoryProvider);
  return repo.fetchOrders();
});

final jobWorkOrderProvider = FutureProvider.autoDispose
    .family<JobWorkOrderModel, String>((ref, id) async {
  final repo = ref.watch(jobWorkRepositoryProvider);
  return repo.fetchOrder(id);
});

final itc04ReportProvider = FutureProvider.autoDispose
    .family<Itc04SummaryModel, ({String quarter, int year})>((ref, params) async {
  final repo = ref.watch(jobWorkRepositoryProvider);
  return repo.fetchItc04(params.quarter, params.year);
});

final jobWorkVendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get(ApiConfig.contacts);
  final data = response.data['data']['content'] as List? ??
      response.data['data'] as List? ??
      [];
  return data.map((c) => c as Map<String, dynamic>).toList();
});

final jobWorkItemsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get(ApiConfig.items);
  final data = response.data['data']['content'] as List? ??
      response.data['data'] as List? ??
      [];
  return data.map((i) => i as Map<String, dynamic>).toList();
});

class JobWorkRepository {
  final ApiClient _client;

  JobWorkRepository(this._client);

  Future<List<JobWorkOrderModel>> fetchOrders() async {
    final response = await _client.get(ApiConfig.jobWorkOrders);
    final data = response.data['data']['content'] as List? ??
        response.data['data'] as List? ??
        [];
    return data
        .map((o) => JobWorkOrderModel.fromJson(o as Map<String, dynamic>))
        .toList();
  }

  Future<JobWorkOrderModel> fetchOrder(String id) async {
    final response = await _client.get(ApiConfig.jobWorkOrder(id));
    final data = response.data['data'] as Map<String, dynamic>;
    return JobWorkOrderModel.fromJson(data);
  }

  Future<JobWorkOrderModel> createOrder(CreateJobWorkRequest req) async {
    final response = await _client.post(
      ApiConfig.jobWorkOrders,
      data: req.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return JobWorkOrderModel.fromJson(data);
  }

  Future<JobWorkOrderModel> recordReceipt(
      String id, ReceiveJobWorkRequest req) async {
    final response = await _client.post(
      ApiConfig.jobWorkReceipt(id),
      data: req.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return JobWorkOrderModel.fromJson(data);
  }

  Future<Itc04SummaryModel> fetchItc04(String quarter, int year) async {
    final response = await _client.get(ApiConfig.jobWorkItc04(quarter, year));
    final data = response.data['data'] as Map<String, dynamic>;
    return Itc04SummaryModel.fromJson(data);
  }
}
