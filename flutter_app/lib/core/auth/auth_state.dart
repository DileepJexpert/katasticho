import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_storage.dart';

/// Possible authentication states.
enum AuthStatus { initial, authenticated, unauthenticated, loading }

/// Global auth state managed by [AuthNotifier].
class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? userName;
  final String? role;
  final String? orgId;
  final String? orgName;
  final String? industry;
  final String? industryCode;
  final bool onboardingCompleted;
  final String? defaultLandingPage;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.userName,
    this.role,
    this.orgId,
    this.orgName,
    this.industry,
    this.industryCode,
    this.onboardingCompleted = false,
    this.defaultLandingPage,
    this.errorMessage,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? userName,
    String? role,
    String? orgId,
    String? orgName,
    String? industry,
    String? industryCode,
    bool? onboardingCompleted,
    String? defaultLandingPage,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      role: role ?? this.role,
      orgId: orgId ?? this.orgId,
      orgName: orgName ?? this.orgName,
      industry: industry ?? this.industry,
      industryCode: industryCode ?? this.industryCode,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      defaultLandingPage: defaultLandingPage ?? this.defaultLandingPage,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier that manages authentication lifecycle.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthStorage _storage;

  AuthNotifier(this._storage) : super(const AuthState()) {
    _checkSession();
  }

  Future<void> _checkSession() async {
    debugPrint('[AuthNotifier] _checkSession called');
    state = state.copyWith(status: AuthStatus.loading);
    final hasSession = await _storage.hasValidSession();
    debugPrint('[AuthNotifier] hasValidSession: $hasSession');
    if (hasSession) {
      final userId = await _storage.getUserId();
      final userName = await _storage.getUserName();
      final role = await _storage.getUserRole();
      final orgId = await _storage.getOrgId();
      final orgName = await _storage.getOrgName();
      final industry = await _storage.getIndustry();
      final industryCode = await _storage.getIndustryCode();
      final onboardingCompleted = await _storage.getOnboardingCompleted();
      final defaultLandingPage = await _storage.getDefaultLandingPage();

      debugPrint('[AuthNotifier] Restored session -> userId: $userId, orgId: $orgId, onboardingCompleted: $onboardingCompleted');

      state = AuthState(
        status: AuthStatus.authenticated,
        userId: userId,
        userName: userName,
        role: role,
        orgId: orgId,
        orgName: orgName,
        industry: industry,
        industryCode: industryCode,
        onboardingCompleted: onboardingCompleted,
        defaultLandingPage: defaultLandingPage,
      );
    } else {
      debugPrint('[AuthNotifier] No valid session, setting unauthenticated');
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> onLoginSuccess({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String userName,
    required String role,
    required String orgId,
    required String orgName,
    String? industry,
    String? industryCode,
    bool onboardingCompleted = false,
    String? defaultLandingPage,
  }) async {
    debugPrint('[AuthNotifier] onLoginSuccess called');
    debugPrint('[AuthNotifier] orgId: $orgId, orgName: $orgName, onboardingCompleted: $onboardingCompleted');

    await _storage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    await _storage.saveUserInfo(userId: userId, userName: userName, role: role);
    await _storage.saveOrgInfo(
      orgId: orgId,
      orgName: orgName,
      industry: industry,
      industryCode: industryCode,
      onboardingCompleted: onboardingCompleted,
      defaultLandingPage: defaultLandingPage,
    );

    state = AuthState(
      status: AuthStatus.authenticated,
      userId: userId,
      userName: userName,
      role: role,
      orgId: orgId,
      orgName: orgName,
      industry: industry,
      industryCode: industryCode,
      onboardingCompleted: onboardingCompleted,
      defaultLandingPage: defaultLandingPage,
    );
    debugPrint('[AuthNotifier] State set to authenticated');
  }

  void markOnboardingComplete() {
    state = state.copyWith(onboardingCompleted: true);
    _storage.saveOnboardingCompleted(completed: true);
  }

  /// Switch to a different org using a pre-fetched [AuthRepository].
  /// Returns true on success, false on failure.
  Future<bool> switchOrg({
    required String targetOrgId,
    required Future<Map<String, dynamic>> Function(String) switchFn,
  }) async {
    try {
      final result = await switchFn(targetOrgId);
      final data = result['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      await onLoginSuccess(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        userId: user['id'].toString(),
        userName: user['fullName'] as String,
        role: user['role'] as String,
        orgId: user['orgId'].toString(),
        orgName: user['orgName'] as String,
        industry: user['industry'] as String?,
        industryCode: user['industryCode'] as String?,
        onboardingCompleted: user['onboardingCompleted'] as bool? ?? true,
        defaultLandingPage: user['defaultLandingPage'] as String?,
      );
      return true;
    } catch (e) {
      debugPrint('[AuthNotifier] switchOrg failed: $e');
      return false;
    }
  }

  Future<void> logout() async {
    debugPrint('[AuthNotifier] logout called');
    await _storage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
    debugPrint('[AuthNotifier] Logged out, state set to unauthenticated');
  }

  void setError(String message) {
    debugPrint('[AuthNotifier] setError: $message');
    state = state.copyWith(
      status: AuthStatus.unauthenticated,
      errorMessage: message,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(authStorageProvider);
  return AuthNotifier(storage);
});
