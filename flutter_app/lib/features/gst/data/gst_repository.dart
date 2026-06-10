import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final gstRepositoryProvider = Provider<GstRepository>((ref) {
  return GstRepository(ref.watch(apiClientProvider));
});

class GstRepository {
  final ApiClient _api;

  GstRepository(this._api);

  Future<Map<String, dynamic>> getGstr1({
    required int year,
    required int month,
  }) async {
    final response = await _api.get(ApiConfig.gstr1, queryParameters: {
      'year': year,
      'month': month,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getGstr3b({
    required int year,
    required int month,
  }) async {
    final response = await _api.get(ApiConfig.gstr3b, queryParameters: {
      'year': year,
      'month': month,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReviewCenter({String? status}) async {
    final response = await _api.get(ApiConfig.gstReviewCenter,
        queryParameters: {if (status != null) 'status': status});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> reviewSuggestion(
    String id, {
    required String action,
    String? correctionReason,
  }) async {
    final response = await _api.post(
      ApiConfig.aiSuggestionReview(id),
      data: {
        'action': action,
        if (correctionReason != null) 'correctionReason': correctionReason,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── GSTR-2B reconciliation ────────────────────────────────────────────

  /// Upload the portal's GSTR-2B JSON; backend parses, matches, returns summary.
  Future<Map<String, dynamic>> uploadGstr2b(
      String period, Map<String, dynamic> portalJson) async {
    final response = await _api.post(
      ApiConfig.gstr2bUpload,
      queryParameters: {'period': period},
      data: portalJson,
    );
    return _data(response.data);
  }

  Future<Map<String, dynamic>> getGstr2bSummary(String period) async {
    final response = await _api
        .get(ApiConfig.gstr2bSummary, queryParameters: {'period': period});
    return _data(response.data);
  }

  Future<List<dynamic>> listGstr2bEntries(String period) async {
    final response =
        await _api.get(ApiConfig.gstr2b, queryParameters: {'period': period});
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List?) ?? const [];
  }

  // ── e-Way bills ───────────────────────────────────────────────────────

  Future<List<dynamic>> listEwayBills({String? status}) async {
    final response = await _api.get(ApiConfig.ewayBills,
        queryParameters: {if (status != null) 'status': status});
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> recordEwayBill(
    String id, {
    required String ewbNumber,
    String? vehicleNumber,
  }) async {
    final response = await _api.post(ApiConfig.ewayBillRecord(id), data: {
      'ewbNumber': ewbNumber,
      if (vehicleNumber != null && vehicleNumber.isNotEmpty)
        'vehicleNumber': vehicleNumber,
    });
    return _data(response.data);
  }

  Future<void> cancelEwayBill(String id, {String? reason}) async {
    await _api.post(ApiConfig.ewayBillCancel(id),
        data: reason != null ? {'reason': reason} : null);
  }

  /// NIC bulk-upload JSON for the document — share/save then upload on the portal.
  Future<Map<String, dynamic>> ewayBillPortalJson(String id) async {
    final response = await _api.get(ApiConfig.ewayBillPortalJson(id));
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  /// Vehicle-aggregate rule check: combined value in one vehicle vs threshold.
  Future<Map<String, dynamic>> checkVehicle({
    required String vehicleNumber,
    required String date,
    double? additionalValue,
  }) async {
    final response = await _api.post(ApiConfig.ewayBillCheckVehicle, data: {
      'vehicleNumber': vehicleNumber,
      'date': date,
      if (additionalValue != null) 'additionalValue': additionalValue,
    });
    return _data(response.data);
  }

  // ── Compliance calendar ───────────────────────────────────────────────

  Future<List<dynamic>> getComplianceCalendar() async {
    final response = await _api.get(ApiConfig.gstComplianceCalendar);
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List?) ?? const [];
  }

  // ── e-Invoice (IRN) ───────────────────────────────────────────────────

  Future<List<dynamic>> listEInvoices({String? status}) async {
    final response = await _api.get(ApiConfig.eInvoices,
        queryParameters: {if (status != null) 'status': status});
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List?) ?? const [];
  }

  Future<Map<String, dynamic>> recordEInvoice(
    String id, {
    required String irn,
    String? ackNumber,
    String? ackDate,
    String? signedQr,
  }) async {
    final response = await _api.post(ApiConfig.eInvoiceRecord(id), data: {
      'irn': irn,
      if (ackNumber != null && ackNumber.isNotEmpty) 'ackNumber': ackNumber,
      if (ackDate != null && ackDate.isNotEmpty) 'ackDate': ackDate,
      if (signedQr != null && signedQr.isNotEmpty) 'signedQr': signedQr,
    });
    return _data(response.data);
  }

  Future<void> cancelEInvoice(String id, {String? reason}) async {
    await _api.post(ApiConfig.eInvoiceCancel(id),
        data: reason != null ? {'reason': reason} : null);
  }

  /// IRP INV-01 JSON for offline-tool / GSP upload.
  Future<Map<String, dynamic>> eInvoicePortalJson(String id) async {
    final response = await _api.get(ApiConfig.eInvoicePortalJson(id));
    return response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : <String, dynamic>{};
  }

  Future<bool> getEInvoiceEnabled() async {
    final response = await _api.get(ApiConfig.eInvoiceSettings);
    return _data(response.data)['enabled'] == true;
  }

  Future<void> setEInvoiceEnabled(bool enabled) async {
    await _api.put(ApiConfig.eInvoiceSettings, data: {'enabled': enabled});
  }

  // ── TDS ───────────────────────────────────────────────────────────────

  Future<List<dynamic>> tdsRegister(String from, String to) async {
    final response = await _api
        .get(ApiConfig.tdsRegister, queryParameters: {'from': from, 'to': to});
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List?) ?? const [];
  }

  /// Quarterly Form 26Q data. [fy] = FY start year (2026 = FY 2026-27).
  Future<Map<String, dynamic>> tds26q(int fy, int quarter) async {
    final response = await _api.get(ApiConfig.tds26q,
        queryParameters: {'fy': fy, 'quarter': quarter});
    return _data(response.data);
  }

  Map<String, dynamic> _data(dynamic body) {
    final map = body as Map<String, dynamic>;
    return Map<String, dynamic>.from((map['data'] as Map?) ?? map);
  }
}
