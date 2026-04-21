import 'package:flutter/foundation.dart';
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
    debugPrint('[AuthRepo] requestOtp called, phone: $phone');
    debugPrint('[AuthRepo] POST ${ApiConfig.requestOtp} body: {phone: $phone}');
    try {
      final response = await _apiClient.post(
        ApiConfig.requestOtp,
        data: {'phone': phone},
      );
      debugPrint('[AuthRepo] requestOtp response status: ${response.statusCode}');
      debugPrint('[AuthRepo] requestOtp response data: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[AuthRepo] requestOtp FAILED: $e');
      debugPrint('[AuthRepo] Stack trace: $st');
      rethrow;
    }
  }

  /// Verify OTP for existing user login — returns tokens.
  Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    debugPrint('[AuthRepo] verifyOtp called, phone: $phone, otp: $otp');
    debugPrint('[AuthRepo] POST ${ApiConfig.verifyOtp} body: {phone: $phone, otp: $otp}');
    try {
      final response = await _apiClient.post(
        ApiConfig.verifyOtp,
        data: {'phone': phone, 'otp': otp},
      );
      debugPrint('[AuthRepo] verifyOtp response status: ${response.statusCode}');
      debugPrint('[AuthRepo] verifyOtp response data: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[AuthRepo] verifyOtp FAILED: $e');
      debugPrint('[AuthRepo] Stack trace: $st');
      rethrow;
    }
  }

  /// Signup: create new user + organisation (requires phone OTP).
  Future<Map<String, dynamic>> signup({
    required String phone,
    required String otp,
    required String fullName,
    required String orgName,
    String? industry,
  }) async {
    final body = {
      'phone': phone,
      'otp': otp,
      'fullName': fullName,
      'orgName': orgName,
      if (industry != null) 'industry': industry,
    };
    debugPrint('[AuthRepo] signup called with body: $body');
    debugPrint('[AuthRepo] POST ${ApiConfig.signup}');
    try {
      final response = await _apiClient.post(
        ApiConfig.signup,
        data: body,
      );
      debugPrint('[AuthRepo] signup response status: ${response.statusCode}');
      debugPrint('[AuthRepo] signup response data: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[AuthRepo] signup FAILED: $e');
      debugPrint('[AuthRepo] Stack trace: $st');
      rethrow;
    }
  }

  /// Get current user profile.
  Future<Map<String, dynamic>> getMe() async {
    debugPrint('[AuthRepo] getMe called');
    try {
      final response = await _apiClient.get(ApiConfig.me);
      debugPrint('[AuthRepo] getMe response: ${response.data}');
      return response.data as Map<String, dynamic>;
    } catch (e, st) {
      debugPrint('[AuthRepo] getMe FAILED: $e');
      debugPrint('[AuthRepo] Stack trace: $st');
      rethrow;
    }
  }

  /// List all organisations the current user belongs to.
  Future<List<Map<String, dynamic>>> getMyOrgs() async {
    final response = await _apiClient.get(ApiConfig.myOrgs);
    final data = (response.data as Map<String, dynamic>)['data'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  /// Switch to a different organisation and return a new auth token pair.
  Future<Map<String, dynamic>> switchOrg(String targetOrgId) async {
    final response = await _apiClient.post(
      ApiConfig.switchOrg,
      data: {'targetOrgId': targetOrgId},
    );
    return response.data as Map<String, dynamic>;
  }
}

final myOrgsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(authRepositoryProvider).getMyOrgs();
});
