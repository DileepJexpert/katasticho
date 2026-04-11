import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  /// Step 1: Send phone number, get OTP sent.
  Future<Map<String, dynamic>> login(String phoneNumber) async {
    final response = await _apiClient.post(
      ApiConfig.login,
      data: {'phoneNumber': phoneNumber},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Step 2: Verify OTP, get tokens.
  Future<Map<String, dynamic>> verifyOtp(
      String phoneNumber, String otpCode) async {
    final response = await _apiClient.post(
      ApiConfig.verifyOtp,
      data: {'phoneNumber': phoneNumber, 'otpCode': otpCode},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Register new user + organisation.
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String phoneNumber,
    required String email,
    required String organisationName,
    required String industry,
    required String country,
    required String baseCurrency,
    String? gstin,
    String? taxRegime,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.register,
      data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'email': email,
        'organisationName': organisationName,
        'industry': industry,
        'country': country,
        'baseCurrency': baseCurrency,
        if (gstin != null) 'gstin': gstin,
        if (taxRegime != null) 'taxRegime': taxRegime,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Get current user profile.
  Future<Map<String, dynamic>> getMe() async {
    final response = await _apiClient.get(ApiConfig.me);
    return response.data as Map<String, dynamic>;
  }
}
