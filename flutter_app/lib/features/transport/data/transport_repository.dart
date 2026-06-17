import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final transportRepositoryProvider = Provider<TransportRepository>((ref) {
  return TransportRepository(ref.watch(apiClientProvider));
});

class TransportRepository {
  final ApiClient _api;
  TransportRepository(this._api);

  // ── Lorry receipts ───────────────────────────────────────────────────

  Future<List<dynamic>> listLorryReceipts({String? status}) async {
    final response = await _api.get(ApiConfig.lorryReceipts,
        queryParameters: status == null ? null : {'status': status});
    return (response.data['data'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> createLorryReceipt(
      Map<String, dynamic> body) async {
    final response = await _api.post(ApiConfig.lorryReceipts, data: body);
    return _data(response.data);
  }

  Future<Map<String, dynamic>> issueLr(String id) async {
    final response = await _api.post(ApiConfig.lorryReceiptIssue(id));
    return _data(response.data);
  }

  Future<Map<String, dynamic>> deliverLr(String id) async {
    final response = await _api.post(ApiConfig.lorryReceiptDeliver(id));
    return _data(response.data);
  }

  Future<Map<String, dynamic>> cancelLr(String id, String? reason) async {
    final response = await _api.post(ApiConfig.lorryReceiptCancel(id),
        data: reason == null ? null : {'reason': reason});
    return _data(response.data);
  }

  Future<Map<String, dynamic>> billFreight(String id) async {
    final response = await _api.post(ApiConfig.lorryReceiptBillFreight(id));
    return _data(response.data);
  }

  // ── Freight rate cards ───────────────────────────────────────────────

  Future<List<dynamic>> listRateCards({String? transporterContactId}) async {
    final response = await _api.get(ApiConfig.freightRateCards,
        queryParameters: transporterContactId == null
            ? null
            : {'transporterContactId': transporterContactId});
    return (response.data['data'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> createRateCard(Map<String, dynamic> body) async {
    final response = await _api.post(ApiConfig.freightRateCards, data: body);
    return _data(response.data);
  }

  Future<void> deleteRateCard(String id) async {
    await _api.delete(ApiConfig.freightRateCard(id));
  }

  Map<String, dynamic> _data(dynamic body) {
    final map = body as Map<String, dynamic>;
    return Map<String, dynamic>.from((map['data'] as Map?) ?? map);
  }
}
