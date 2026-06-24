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
    String? countryCode,
  }) async {
    final body = {
      'phone': phone,
      'otp': otp,
      'fullName': fullName,
      'orgName': orgName,
      if (industry != null) 'industry': industry,
      if (countryCode != null) 'countryCode': countryCode,
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

  /// Login with phone/email + password (no OTP required).
  Future<Map<String, dynamic>> loginWithPassword({
    required String identifier,
    required String password,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.login,
      data: {'identifier': identifier, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> forgotPassword({required String phone}) async {
    final response = await _apiClient.post(
      ApiConfig.forgotPassword,
      data: {'phone': phone},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.resetPassword,
      data: {
        'phone': phone,
        'otp': otp,
        'newPassword': newPassword,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Register new account with password (no OTP required).
  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String fullName,
    required String orgName,
    String? businessType,
    String? industryCode,
    String? countryCode,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.register,
      data: {
        'phone': phone,
        'password': password,
        'fullName': fullName,
        'orgName': orgName,
        if (businessType != null) 'businessType': businessType,
        if (industryCode != null) 'industryCode': industryCode,
        if (countryCode != null) 'countryCode': countryCode,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Request password reset via email token.
  Future<Map<String, dynamic>> forgotPasswordEmail({
    String? email,
    String? phone,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.forgotPasswordEmail,
      data: {
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Reset password with email token.
  Future<Map<String, dynamic>> resetPasswordWithToken({
    required String token,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.resetPasswordToken,
      data: {'token': token, 'newPassword': newPassword},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Resend verification email.
  Future<Map<String, dynamic>> resendVerificationEmail(String email) async {
    final response = await _apiClient.post(
      ApiConfig.resendVerification,
      data: {'email': email},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Change password (authenticated user).
  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.changePassword,
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
    return response.data as Map<String, dynamic>;
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

  /// Create an additional organisation for the current user.
  Future<Map<String, dynamic>> createAdditionalOrg({
    required String name,
    String? businessType,
    String? industryCode,
  }) async {
    final response = await _apiClient.post(
      ApiConfig.createAdditionalOrg,
      data: {
        'name': name,
        if (businessType != null) 'businessType': businessType,
        if (industryCode != null) 'industryCode': industryCode,
      },
    );
    return response.data as Map<String, dynamic>;
  }
}

final myOrgsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(authRepositoryProvider).getMyOrgs();
});
