import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/auth/nav_overrides.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/shell_screen.dart';

/// Owner / Admin screen for hiding entries from the org's sidebar. Reads /
/// writes `org_settings.nav.disabled` — a JSON array of stable NavItem /
/// NavGroup ids. PLATFORM_ADMIN bypasses the disable list (see
/// [NavOverrides.isPlatformAdmin]) so support staff always see everything.
///
/// Layout: one [KCard] per group, with a master Switch for the group and
/// a per-child Switch for every id'd child. Top-level NavItems (dashboard,
/// AI, POS, contacts, settings) get their own card at the top.
class NavCustomisationScreen extends ConsumerStatefulWidget {
  const NavCustomisationScreen({super.key});

  @override
  ConsumerState<NavCustomisationScreen> createState() =>
      _NavCustomisationScreenState();
}

class _NavCustomisationScreenState
    extends ConsumerState<NavCustomisationScreen> {
  Set<String> _disabled = <String>{};
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
    try {
      final client = ref.read(apiClientProvider);
      final res = await client.get('${ApiConfig.orgSettings}/nav.disabled');
      final data = res.data as Map<String, dynamic>? ?? const {};
      final raw = data['nav.disabled']?.toString() ?? '';
      if (mounted) setState(() => _disabled = _parseList(raw));
    } catch (_) {
      // Unset / 404 → empty set is fine — nothing disabled.
      if (mounted) setState(() => _disabled = <String>{});
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Set<String> _parseList(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return <String>{};
    if (t.startsWith('[') && t.endsWith(']')) {
      try {
        final decoded = json.decode(t);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((s) => s.isNotEmpty)
              .toSet();
        }
      } catch (_) {/* fall through */}
    }
    return t.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      // Generic settings endpoint stores values as strings — encode the
      // id list as a JSON array so the read side (NavOverrides provider)
      // parses it back cleanly.
      final body = {'value': json.encode(_disabled.toList()..sort())};
      await client.put('${ApiConfig.orgSettings}/nav.disabled', data: body);
      // Refresh the sidebar on the live session too.
      ref.invalidate(navOverridesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Sidebar updated — users will see changes on next reload.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', '').trim());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleId(String id, bool enabled) {
    setState(() {
      if (enabled) {
        _disabled.remove(id);
      } else {
        _disabled.add(id);
      }
    });
  }

  void _toggleGroup(NavGroup group, bool enabled) {
    setState(() {
      if (enabled) {
        if (group.id != null) _disabled.remove(group.id!);
        for (final c in group.children) {
          if (c.id != null) _disabled.remove(c.id!);
        }
      } else {
        if (group.id != null) _disabled.add(group.id!);
        for (final c in group.children) {
          if (c.id != null) _disabled.add(c.id!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = (ref.watch(authProvider).role ?? '').toUpperCase();
    final isAdmin = role == 'OWNER' || role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sidebar Customisation'),
        actions: [
          if (isAdmin && !_loading)
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
            'Only org owners and admins can change the sidebar layout for the team.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final groups = allConfigurableGroups();
    final topItems = allConfigurableTopLevelItems();

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
          child: Text(
            'Hide menu entries from your team\'s sidebar. Toggling a group off '
            'hides the whole group and every child. Changes apply to everyone '
            'in this org except platform admins.',
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
        // Top-level items card.
        _TopItemsCard(
          items: topItems,
          disabled: _disabled,
          onToggle: _toggleId,
        ),
        KSpacing.vGapMd,
        for (final g in groups) ...[
          _GroupCard(
            group: g,
            disabled: _disabled,
            onToggleGroup: _toggleGroup,
            onToggleChild: _toggleId,
          ),
          KSpacing.vGapMd,
        ],
      ],
    );
  }
}

class _TopItemsCard extends StatelessWidget {
  final List<NavItem> items;
  final Set<String> disabled;
  final void Function(String id, bool enabled) onToggle;
  const _TopItemsCard({
    required this.items,
    required this.disabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: 'Top-level',
      subtitle: 'Always-on entries above the grouped nav',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.label),
              subtitle: Text(item.id ?? '',
                  style: const TextStyle(fontSize: 11)),
              value: item.id == null || !disabled.contains(item.id),
              onChanged: item.id == null
                  ? null
                  : (v) => onToggle(item.id!, v),
            ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final NavGroup group;
  final Set<String> disabled;
  final void Function(NavGroup group, bool enabled) onToggleGroup;
  final void Function(String id, bool enabled) onToggleChild;
  const _GroupCard({
    required this.group,
    required this.disabled,
    required this.onToggleGroup,
    required this.onToggleChild,
  });

  @override
  Widget build(BuildContext context) {
    final groupDisabled =
        group.id != null && disabled.contains(group.id);
    final groupEnabled = !groupDisabled;
    return KCard(
      title: group.label,
      subtitle: group.id ?? '',
      action: Switch(
        value: groupEnabled,
        onChanged: (v) => onToggleGroup(group, v),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in group.children)
            if (c.id != null)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(c.label),
                subtitle: Text(c.id!,
                    style: const TextStyle(fontSize: 11)),
                value: groupEnabled && !disabled.contains(c.id),
                onChanged: groupEnabled
                    ? (v) => onToggleChild(c.id!, v)
                    : null,
              ),
        ],
      ),
    );
  }
}
