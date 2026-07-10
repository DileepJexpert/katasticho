import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import 'auth_state.dart';

/// Per-org authoritative module-visibility overrides.
///
/// An OWNER/ADMIN can, per module, override the industry/feature-flag default in
/// BOTH directions — show a module their vertical hides, or hide one it shows —
/// via the "Modules" settings screen (`PUT /api/v1/settings/module-visibility`).
/// The map is `{MODULE_CODE: visible}`; a module absent from the map uses its
/// computed default. Applied on top of [BusinessCapabilities] so the explicit
/// org decision wins.
///
/// Org-scoped by construction (the backend resolves the org from the session),
/// so one org's overrides can never affect another. Returns an empty map on any
/// failure — the safe default is the computed capabilities, unchanged.
final moduleOverridesProvider = FutureProvider<Map<String, bool>>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return const <String, bool>{};

  final client = ref.watch(apiClientProvider);
  try {
    final res = await client.get(ApiConfig.moduleVisibility);
    final data = res.data as Map<String, dynamic>? ?? const {};
    final raw = data['overrides'] as Map<String, dynamic>? ?? const {};
    final out = <String, bool>{};
    raw.forEach((k, v) {
      if (v is bool) out[k.toString().toUpperCase()] = v;
    });
    return out;
  } catch (_) {
    return const <String, bool>{};
  }
});
