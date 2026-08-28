import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final workflowRulesRepositoryProvider = Provider<WorkflowRulesRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return WorkflowRulesRepository(api);
});

final workflowRulesListProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(workflowRulesRepositoryProvider);
  return repo.listWorkflowRules();
});

final workflowRuleMetadataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(workflowRulesRepositoryProvider);
  return repo.getMetadata();
});

class WorkflowRulesRepository {
  final ApiClient _api;
  WorkflowRulesRepository(this._api);

  Future<List<Map<String, dynamic>>> listWorkflowRules({int page = 0, int size = 50}) async {
    final res = await _api.get('${ApiConfig.workflowRules}?page=$page&size=$size');
    final data = res.data['data'] ?? res.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : (data is List ? data : []);
    return content.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> getWorkflowRule(String id) async {
    final res = await _api.get(ApiConfig.workflowRuleById(id));
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createWorkflowRule(Map<String, dynamic> payload) async {
    final res = await _api.post(ApiConfig.workflowRules, data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateWorkflowRule(String id, Map<String, dynamic> payload) async {
    final res = await _api.put(ApiConfig.workflowRuleById(id), data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<void> toggleWorkflowRule(String id, bool active) async {
    await _api.post('${ApiConfig.workflowRuleToggle(id)}?active=$active');
  }

  Future<void> deleteWorkflowRule(String id) async {
    await _api.delete(ApiConfig.workflowRuleById(id));
  }

  Future<Map<String, dynamic>> dryRunWorkflowRule(Map<String, dynamic> payload) async {
    final res = await _api.post(ApiConfig.workflowRuleDryRun, data: payload);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMetadata() async {
    final res = await _api.get(ApiConfig.workflowRuleMetadata);
    return (res.data['data'] ?? res.data) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getExecutions(String ruleId, {int page = 0, int size = 20}) async {
    final res = await _api.get('${ApiConfig.workflowRuleExecutions(ruleId)}?page=$page&size=$size');
    final data = res.data['data'] ?? res.data;
    final content = data is Map ? (data['content'] as List?) ?? [] : (data is List ? data : []);
    return content.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }
}
