import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import 'auth_state.dart';

/// Per-org sidebar overrides.
///
/// The org admin can hide any sidebar entry by adding its stable id to the
/// `org_settings.nav.disabled` list (a JSON array of strings, written via the
/// generic `PUT /api/v1/settings/nav.disabled` endpoint). PLATFORM_ADMIN
/// always sees everything regardless — the override is for the org's own
/// users, not for the platform itself.
///
/// Provider returns an empty set on any failure (unset key, network error,
/// malformed JSON) — the safe default is to show everything.
class NavOverrides {
  final Set<String> disabledIds;
  final bool isPlatformAdmin;

  const NavOverrides({
    required this.disabledIds,
    required this.isPlatformAdmin,
  });

  /// True when an entry with this id should be hidden from THIS user's
  /// sidebar. PLATFORM_ADMIN bypasses the disable list so the platform can
  /// always reach every screen for support.
  bool isDisabled(String? id) {
    if (id == null || id.isEmpty) return false;
    if (isPlatformAdmin) return false;
    return disabledIds.contains(id);
  }

  static const empty = NavOverrides(disabledIds: <String>{}, isPlatformAdmin: false);
}

/// Reads `org_settings.nav.disabled` once per session. Pairs the org's
/// disable list with the caller's role so the gate works without callers
/// having to fetch auth state separately.
final navOverridesProvider = FutureProvider<NavOverrides>((ref) async {
  final auth = ref.watch(authProvider);
  final isPlatformAdmin = (auth.role ?? '').toUpperCase() == 'PLATFORM_ADMIN';

  final client = ref.watch(apiClientProvider);
  try {
    final response = await client.get(
      '${ApiConfig.orgSettings}/nav.disabled',
      options: Options(validateStatus: (status) => status != null && status < 500),
    );
    final data = response.data as Map<String, dynamic>? ?? {};
    final raw = data['nav.disabled']?.toString();
    if (raw == null || raw.trim().isEmpty) {
      return NavOverrides(disabledIds: const {}, isPlatformAdmin: isPlatformAdmin);
    }
    // Stored as either a JSON array OR a comma-separated list — accept both
    // so a human typing in the settings UI doesn't have to remember syntax.
    final ids = _parseDisabledList(raw);
    return NavOverrides(disabledIds: ids, isPlatformAdmin: isPlatformAdmin);
  } catch (_) {
    return NavOverrides(disabledIds: const {}, isPlatformAdmin: isPlatformAdmin);
  }
});

Set<String> _parseDisabledList(String raw) {
  final trimmed = raw.trim();
  // JSON array case.
  if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
    final inner = trimmed.substring(1, trimmed.length - 1);
    return inner
        .split(',')
        .map((s) => s.trim().replaceAll('"', '').replaceAll("'", ''))
        .where((s) => s.isNotEmpty)
        .toSet();
  }
  // Comma-separated list.
  return trimmed
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
}
