import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final reimbursementRepositoryProvider = Provider<EmployeeReimbursementRepository>((ref) =>
    EmployeeReimbursementRepository(ref.watch(apiClientProvider)));

class EmployeeReimbursementRepository {
  final ApiClient _api;
  EmployeeReimbursementRepository(this._api);

  Future<Map<String, dynamic>> list({String? status, int page = 0, int size = 50}) async {
    final response = await _api.get(ApiConfig.employeeReimbursements, queryParameters: {
      'page': page,
      'size': size,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> listAdvances() async {
    final response = await _api.get(ApiConfig.employeeAdvances, queryParameters: {'page': 0, 'size': 50});
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> submit(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.employeeReimbursements, data: data);
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> createAdvance(Map<String, dynamic> data) async {
    final response = await _api.post(ApiConfig.employeeAdvances, data: data);
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> approve(String id) async {
    final response = await _api.post(ApiConfig.employeeReimbursementApprove(id));
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> reject(String id, String reason) async {
    final response = await _api.post(ApiConfig.employeeReimbursementReject(id), data: {'reason': reason});
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> pay(String id, String paidThroughId) async {
    final response = await _api.post(ApiConfig.employeeReimbursementPay(id), data: {'paidThroughId': paidThroughId});
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<void> uploadReceipt(String id, PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) throw StateError('Receipt bytes are unavailable');
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name),
    });
    await _api.dio.post(ApiConfig.employeeReimbursementAttachments(id), data: form,
        options: Options(contentType: 'multipart/form-data'));
  }
}

