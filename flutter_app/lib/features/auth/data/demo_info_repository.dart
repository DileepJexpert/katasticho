import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// One demo login surfaced on the login screen — phone + display name + role
/// + the matching plaintext password (server only sends this when demo mode is on).
class DemoLogin {
  final String phone;
  final String fullName;
  final String role;
  final String password;

  const DemoLogin({
    required this.phone,
    required this.fullName,
    required this.role,
    required this.password,
  });

  factory DemoLogin.fromJson(Map<String, dynamic> json) => DemoLogin(
        phone: json['phone'] as String,
        fullName: json['fullName'] as String,
        role: json['role'] as String,
        password: json['password'] as String,
      );
}

/// Demo-mode payload returned by `/api/v1/auth/demo-info`. When `enabled` is
/// false the user list is empty and the login-screen card hides itself.
class DemoInfo {
  final bool enabled;
  final String orgName;
  final List<DemoLogin> users;

  const DemoInfo({
    required this.enabled,
    required this.orgName,
    required this.users,
  });

  static const DemoInfo disabled = DemoInfo(
    enabled: false,
    orgName: '',
    users: [],
  );

  factory DemoInfo.fromJson(Map<String, dynamic> json) => DemoInfo(
        enabled: json['enabled'] as bool? ?? false,
        orgName: json['orgName'] as String? ?? '',
        users: ((json['users'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(DemoLogin.fromJson)
            .toList(growable: false),
      );
}

/// Fetches `/api/v1/auth/demo-info` once per app launch. Public endpoint
/// (no auth header needed). Network errors / non-200 responses → treat as
/// "demo disabled" instead of throwing, so the login screen stays clean.
final demoInfoProvider = FutureProvider<DemoInfo>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  try {
    final response = await apiClient.get<Map<String, dynamic>>(ApiConfig.demoInfo);
    final data = response.data?['data'] as Map<String, dynamic>?;
    if (data == null) return DemoInfo.disabled;
    return DemoInfo.fromJson(data);
  } catch (_) {
    return DemoInfo.disabled;
  }
});
