import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';

final caConsoleRepositoryProvider = Provider<CaConsoleRepository>((ref) {
  return CaConsoleRepository(ref.watch(apiClientProvider));
});

class CaConsoleRepository {
  final ApiClient _api;

  CaConsoleRepository(this._api);

  Map<String, dynamic> _unwrap(dynamic response) {
    final map = response as Map<String, dynamic>;
    return (map['data'] ?? map) as Map<String, dynamic>;
  }

  List<dynamic> _unwrapList(dynamic response) {
    final map = response as Map<String, dynamic>;
    return (map['data'] ?? const []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getDashboard() async {
    final response = await _api.get('/api/v1/ca/dashboard');
    return _unwrap(response.data);
  }

  Future<List<dynamic>> getClients() async {
    final response = await _api.get('/api/v1/ca/clients');
    return _unwrapList(response.data);
  }

  Future<List<dynamic>> getDeadlines({String? status}) async {
    final response = await _api.get('/api/v1/ca/compliance/deadlines',
        queryParameters: {if (status != null) 'status': status});
    return _unwrapList(response.data);
  }

  Future<void> generateDeadlines() async {
    await _api.post('/api/v1/ca/compliance/deadlines/generate');
  }

  Future<void> markFiled(String id, {String? reference}) async {
    await _api.post('/api/v1/ca/compliance/deadlines/$id/mark-filed',
        data: {if (reference != null) 'filingReference': reference});
  }

  Future<List<dynamic>> getAlerts({String? severity}) async {
    final response = await _api.get('/api/v1/ca/alerts',
        queryParameters: {if (severity != null) 'severity': severity});
    return _unwrapList(response.data);
  }

  Future<void> dismissAlert(String id) async {
    await _api.post('/api/v1/ca/alerts/$id/dismiss');
  }

  Future<Map<String, dynamic>> openBooks(String linkId) async {
    final response = await _api.post('/api/v1/ca/clients/$linkId/access-token');
    return _unwrap(response.data);
  }

  Future<List<dynamic>> dispatchReports({
    required List<String> clientOrgIds,
    required String periodLabel,
    required List<String> reportTypes,
    required String sendVia,
    required bool includeAiCommentary,
  }) async {
    final response = await _api.post('/api/v1/ca/reports/dispatch', data: {
      'clientOrgIds': clientOrgIds,
      'allClients': false,
      'periodLabel': periodLabel,
      'reportTypes': reportTypes,
      'sendVia': sendVia,
      'includeAiCommentary': includeAiCommentary,
    });
    return _unwrapList(response.data);
  }

  Future<List<dynamic>> getDispatchHistory() async {
    final response = await _api.get('/api/v1/ca/reports/dispatch/history');
    return _unwrapList(response.data);
  }
}
