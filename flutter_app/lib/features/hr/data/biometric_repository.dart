import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import 'biometric_models.dart';

final biometricRepositoryProvider = Provider<BiometricRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return BiometricRepository(client);
});

final biometricDevicesProvider =
    FutureProvider.autoDispose<List<BiometricDeviceModel>>((ref) async {
  final repo = ref.watch(biometricRepositoryProvider);
  return repo.fetchDevices();
});

final biometricLogsProvider =
    FutureProvider.autoDispose<List<BiometricPunchLogModel>>((ref) async {
  final repo = ref.watch(biometricRepositoryProvider);
  return repo.fetchLogs();
});

final hrEmployeesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(biometricRepositoryProvider);
  return repo.fetchEmployees();
});

class BiometricRepository {
  final ApiClient _client;

  BiometricRepository(this._client);

  Future<List<BiometricDeviceModel>> fetchDevices() async {
    final response = await _client.get(ApiConfig.biometricDevices);
    final data = response.data['data'] as List? ?? [];
    return data
        .map((d) => BiometricDeviceModel.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<BiometricDeviceModel> registerDevice(RegisterBiometricDeviceRequest req) async {
    final response = await _client.post(
      ApiConfig.biometricDevices,
      data: req.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return BiometricDeviceModel.fromJson(data);
  }

  Future<BiometricDeviceModel> updateDevice(
      String id, RegisterBiometricDeviceRequest req) async {
    final response = await _client.put(
      ApiConfig.biometricDevice(id),
      data: req.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return BiometricDeviceModel.fromJson(data);
  }

  Future<void> deleteDevice(String id) async {
    await _client.delete(ApiConfig.biometricDevice(id));
  }

  Future<Map<String, dynamic>> testDeviceConnection(String id) async {
    final response = await _client.post(ApiConfig.biometricDeviceTest(id));
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<List<BiometricPunchLogModel>> fetchLogs() async {
    final response = await _client.get(ApiConfig.biometricLogs);
    final data = response.data['data'] as List? ?? [];
    return data
        .map((l) => BiometricPunchLogModel.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  Future<BiometricPunchLogModel> simulatePunch(
      SimulatePunchRequestPayload req) async {
    final response = await _client.post(
      ApiConfig.biometricSimulatePunch,
      data: req.toJson(),
    );
    final data = response.data['data'] as Map<String, dynamic>;
    return BiometricPunchLogModel.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> fetchEmployees() async {
    final response = await _client.get(ApiConfig.payrollEmployees);
    final data = response.data['data'] as List? ?? [];
    return data.map((e) => e as Map<String, dynamic>).toList();
  }
}
