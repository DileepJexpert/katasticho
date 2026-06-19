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

  // ── Vehicle log (own-fleet TCO) ──────────────────────────────────────

  Future<List<dynamic>> listVehicleLogs({String? vehicleNumber}) async {
    final response = await _api.get(ApiConfig.vehicleLogs,
        queryParameters:
            vehicleNumber == null ? null : {'vehicleNumber': vehicleNumber});
    return (response.data['data'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> createVehicleLog(
      Map<String, dynamic> body) async {
    final response = await _api.post(ApiConfig.vehicleLogs, data: body);
    return _data(response.data);
  }

  Future<void> deleteVehicleLog(String id) async {
    await _api.delete(ApiConfig.vehicleLog(id));
  }

  Future<Map<String, dynamic>> vehicleSummary(String vehicleNumber) async {
    final response = await _api.get(ApiConfig.vehicleLogSummary,
        queryParameters: {'vehicleNumber': vehicleNumber});
    return _data(response.data);
  }

  // ── Proof of delivery ────────────────────────────────────────────────

  Future<List<dynamic>> listPod({String? deliveryChallanId}) async {
    final response = await _api.get(ApiConfig.proofOfDelivery,
        queryParameters: deliveryChallanId == null
            ? null
            : {'deliveryChallanId': deliveryChallanId});
    return (response.data['data'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> createPod(Map<String, dynamic> body) async {
    final response = await _api.post(ApiConfig.proofOfDelivery, data: body);
    return _data(response.data);
  }

  Map<String, dynamic> _data(dynamic body) {
    final map = body as Map<String, dynamic>;
    return Map<String, dynamic>.from((map['data'] as Map?) ?? map);
  }
}
