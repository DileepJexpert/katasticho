import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/module_overrides.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/widgets/widgets.dart';

/// Owner / Admin screen for choosing which modules appear in the sidebar for
/// THIS organisation. Each module has three states:
///  - **Default** — follow the industry/feature-flag default (no override),
///  - **Show** — force it visible even if the vertical hides it,
///  - **Hide** — force it hidden even if the vertical shows it.
///
/// The explicit Show/Hide decision wins over the computed default (applied in
/// [BusinessCapabilities.applyModuleOverrides]). Reads/writes the per-org
/// `PUT /api/v1/settings/module-visibility` API, so one org's choices never
/// affect another. PLATFORM_ADMIN is unaffected by another org's overrides
/// only where the sidebar already bypasses gates.
class ModulesSettingsScreen extends ConsumerStatefulWidget {
  const ModulesSettingsScreen({super.key});

  @override
  ConsumerState<ModulesSettingsScreen> createState() =>
      _ModulesSettingsScreenState();
}

enum _Vis { byDefault, show, hide }

class _ModuleDef {
  final String code;
  final String label;
  const _ModuleDef(this.code, this.label);
}

const _verticalModules = <_ModuleDef>[
  _ModuleDef('POS', 'Point of Sale'),
  _ModuleDef('INVENTORY', 'Inventory'),
  _ModuleDef('DISTRIBUTION', 'Sales Orders & Delivery'),
  _ModuleDef('PHARMA', 'Pharmacy'),
  _ModuleDef('BATCH_EXPIRY', 'Batch & Expiry'),
  _ModuleDef('MANUFACTURING', 'Manufacturing'),
  _ModuleDef('FIELD_SALES', 'Field Sales'),
  _ModuleDef('PARTNER_NETWORK', 'Partner Network'),
  _ModuleDef('PAYROLL', 'HR & Payroll'),
  _ModuleDef('SUPPLY_CHAIN', 'Supply Planning'),
  _ModuleDef('COURIER', 'Courier & Transport'),
];

const _coreModules = <_ModuleDef>[
  _ModuleDef('ACCOUNTING', 'Accounting'),
  _ModuleDef('BANK_RECON', 'Bank Reconciliation'),
  _ModuleDef('AI_INBOX', 'AI Inbox'),
  _ModuleDef('REPORTS', 'Reports'),
];

class _ModulesSettingsScreenState extends ConsumerState<ModulesSettingsScreen> {
  final Map<String, _Vis> _state = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // Everything starts at "Default"; the GET fills in the explicit overrides.
    for (final m in [..._verticalModules, ..._coreModules]) {
      _state[m.code] = _Vis.byDefault;
    }
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get(ApiConfig.moduleVisibility);
      final data = res.data as Map<String, dynamic>? ?? const {};
      final overrides = data['overrides'] as Map<String, dynamic>? ?? const {};
      overrides.forEach((k, v) {
        if (v is bool) {
          _state[k.toString().toUpperCase()] = v ? _Vis.show : _Vis.hide;
        }
      });
    } catch (_) {
      // Unset / error → all default is fine.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final overrides = <String, bool>{};
      _state.forEach((code, vis) {
        if (vis == _Vis.show) overrides[code] = true;
        if (vis == _Vis.hide) overrides[code] = false;
        // byDefault → omitted (no override).
      });
      final client = ref.read(apiClientProvider);
      await client.put(ApiConfig.moduleVisibility, data: {'overrides': overrides});
      // Recompute the live sidebar for this session.
      ref.invalidate(moduleOverridesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modules updated — the sidebar refreshes for the team on next reload.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetAll() async {
    setState(() {
      for (final code in _state.keys) {
        _state[code] = _Vis.byDefault;
      }
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final role = (ref.watch(authProvider).role ?? '').toUpperCase();
    final isAdmin = role == 'OWNER' || role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modules'),
        actions: [
          if (isAdmin && !_loading) ...[
            TextButton(
              onPressed: _saving ? null : _resetAll,
              child: const Text('Reset'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
              ),
            ),
          ],
        ],
      ),
      body: _buildBody(isAdmin),
    );
  }

  Widget _buildBody(bool isAdmin) {
    if (!isAdmin) {
      return const KEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Not authorised',
        subtitle:
            'Only org owners and admins can change which modules the team sees.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'Choose which modules appear in your team\'s sidebar. "Default" '
            'follows your business type; "Show" or "Hide" force it either way '
            'and always win. Changes apply only to this organisation.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        _ModuleCard(
          title: 'Vertical modules',
          subtitle: 'Shown per business type — override as needed',
          modules: _verticalModules,
          state: _state,
          onChanged: (code, vis) => setState(() => _state[code] = vis),
        ),
        KSpacing.vGapMd,
        _ModuleCard(
          title: 'Core',
          subtitle: 'Available to every business — hide only if unused',
          modules: _coreModules,
          state: _state,
          onChanged: (code, vis) => setState(() => _state[code] = vis),
        ),
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_ModuleDef> modules;
  final Map<String, _Vis> state;
  final void Function(String code, _Vis vis) onChanged;
  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.modules,
    required this.state,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in modules)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(m.label),
              subtitle: Text(m.code, style: const TextStyle(fontSize: 11)),
              trailing: SizedBox(
                width: 116,
                child: DropdownButton<_Vis>(
                  isExpanded: true,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  value: state[m.code] ?? _Vis.byDefault,
                  onChanged: (v) => onChanged(m.code, v ?? _Vis.byDefault),
                  items: const [
                    DropdownMenuItem(value: _Vis.byDefault, child: Text('Default')),
                    DropdownMenuItem(value: _Vis.show, child: Text('Show')),
                    DropdownMenuItem(value: _Vis.hide, child: Text('Hide')),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
