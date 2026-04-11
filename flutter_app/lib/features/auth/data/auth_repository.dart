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

  /// Request OTP for phone number (used by both login and signup flows).
  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final response = await _apiClient.post(
      ApiConfig.requestOtp,
      data: {'phone': phone},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Verify OTP for existing user login — returns tokens.
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final response = await _apiClient.post(
      ApiConfig.verifyOtp,
      data: {'phone': phone, 'otp': otp},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Signup: create new user + organisation (requires phone OTP).
  Future<Map<String, dynamic>> signup({
    required String phone,
    required String otp,
    required String fullName,
    required String orgName,
    String? industry,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.signup,
      data: {
        'phone': phone,
        'otp': otp,
        'fullName': fullName,
        'orgName': orgName,
        if (industry != null) 'industry': industry,
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
