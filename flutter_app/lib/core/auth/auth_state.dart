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
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.userName,
    this.role,
    this.orgId,
    this.orgName,
    this.industry,
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

      debugPrint('[AuthNotifier] Restored session -> userId: $userId, userName: $userName, role: $role, orgId: $orgId, orgName: $orgName, industry: $industry');

      state = AuthState(
        status: AuthStatus.authenticated,
        userId: userId,
        userName: userName,
        role: role,
        orgId: orgId,
        orgName: orgName,
        industry: industry,
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
  }) async {
    debugPrint('[AuthNotifier] onLoginSuccess called');
    debugPrint('[AuthNotifier] accessToken: ${accessToken.substring(0, accessToken.length > 20 ? 20 : accessToken.length)}...');
    debugPrint('[AuthNotifier] refreshToken: ${refreshToken.substring(0, refreshToken.length > 20 ? 20 : refreshToken.length)}...');
    debugPrint('[AuthNotifier] userId: $userId, userName: $userName, role: $role');
    debugPrint('[AuthNotifier] orgId: $orgId, orgName: $orgName, industry: $industry');

    debugPrint('[AuthNotifier] Saving tokens...');
    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    debugPrint('[AuthNotifier] Tokens saved');

    debugPrint('[AuthNotifier] Saving user info...');
    await _storage.saveUserInfo(
      userId: userId,
      userName: userName,
      role: role,
    );
    debugPrint('[AuthNotifier] User info saved');

    debugPrint('[AuthNotifier] Saving org info...');
    await _storage.saveOrgInfo(
      orgId: orgId,
      orgName: orgName,
      industry: industry,
    );
    debugPrint('[AuthNotifier] Org info saved');

    state = AuthState(
      status: AuthStatus.authenticated,
      userId: userId,
      userName: userName,
      role: role,
      orgId: orgId,
      orgName: orgName,
      industry: industry,
    );
    debugPrint('[AuthNotifier] State set to authenticated');
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
