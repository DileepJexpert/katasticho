import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final courierRepositoryProvider = Provider<CourierRepository>((ref) {
  return CourierRepository(ref.watch(apiClientProvider));
});

class CourierRepository {
  final ApiClient _api;
  CourierRepository(this._api);

  // ── Shipments ────────────────────────────────────────────────────────

  Future<List<dynamic>> listShipments({String? status}) async {
    final response = await _api.get(ApiConfig.courierShipments,
        queryParameters: status == null ? null : {'status': status});
    return (response.data['data'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> createShipment(Map<String, dynamic> body) async {
    final response = await _api.post(ApiConfig.courierShipments, data: body);
    return _data(response.data);
  }

  Future<Map<String, dynamic>> bookShipment(String id, String awbNumber) async {
    final response = await _api.post(ApiConfig.courierShipmentBook(id),
        data: {'awbNumber': awbNumber});
    return _data(response.data);
  }

  Future<Map<String, dynamic>> cancelShipment(String id, String? reason) async {
    final response = await _api.post(ApiConfig.courierShipmentCancel(id),
        data: reason == null ? null : {'reason': reason});
    return _data(response.data);
  }

  Future<Map<String, dynamic>> recordEvent(
      String id, Map<String, dynamic> event) async {
    final response =
        await _api.post(ApiConfig.courierShipmentEvents(id), data: event);
    return _data(response.data);
  }

  Future<List<dynamic>> listPendingRto() async {
    final response = await _api.get(ApiConfig.courierShipmentsPendingRto);
    return (response.data['data'] as List?) ?? const [];
  }

  // ── COD remittances ──────────────────────────────────────────────────

  Future<List<dynamic>> listRemittances() async {
    final response = await _api.get(ApiConfig.codRemittances);
    return (response.data['data'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> createRemittance(
      Map<String, dynamic> body) async {
    final response = await _api.post(ApiConfig.codRemittances, data: body);
    return _data(response.data);
  }

  Future<Map<String, dynamic>> reconcileRemittance(String id) async {
    final response = await _api.post(ApiConfig.codRemittanceReconcile(id));
    return _data(response.data);
  }

  Future<Map<String, dynamic>> getRemittance(String id) async {
    final response = await _api.get(ApiConfig.codRemittance(id));
    return _data(response.data);
  }

  // ── Live tracking ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> syncShipment(String id) async {
    final response = await _api.post(ApiConfig.courierTrackingSync(id));
    return _data(response.data);
  }

  Future<Map<String, dynamic>> syncAll() async {
    final response = await _api.post(ApiConfig.courierTrackingSyncAll);
    return _data(response.data);
  }

  Future<Map<String, dynamic>> pullCod(String partner,
      {String? from, String? to}) async {
    final response = await _api.post(ApiConfig.courierTrackingCodPull,
        queryParameters: {
          'partner': partner,
          if (from != null) 'from': from,
          if (to != null) 'to': to,
        });
    return _data(response.data);
  }

  Future<Map<String, dynamic>> webhookUrl(String partner) async {
    final response = await _api.get(ApiConfig.courierTrackingWebhookUrl(partner));
    return _data(response.data);
  }

  // ── Settings ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getCourierSettings() async {
    final response = await _api.get(ApiConfig.courierSettings);
    return _data(response.data);
  }

  Future<Map<String, dynamic>> updateCourierSettings(
      String partner, Map<String, dynamic> body) async {
    final response =
        await _api.put(ApiConfig.courierSettingsPartner(partner), data: body);
    return _data(response.data);
  }

  Future<Map<String, dynamic>> testCourier(String partner) async {
    final response = await _api.post(ApiConfig.courierSettingsPartnerTest(partner));
    return _data(response.data);
  }

  Map<String, dynamic> _data(dynamic body) {
    final map = body as Map<String, dynamic>;
    return Map<String, dynamic>.from((map['data'] as Map?) ?? map);
  }
}
