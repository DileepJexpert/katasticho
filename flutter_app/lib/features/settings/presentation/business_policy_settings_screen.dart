import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/org_settings_repository.dart';

class BusinessPolicySettingsScreen extends ConsumerStatefulWidget {
  const BusinessPolicySettingsScreen({super.key});

  @override
  ConsumerState<BusinessPolicySettingsScreen> createState() =>
      _BusinessPolicySettingsScreenState();
}

class _BusinessPolicySettingsScreenState
    extends ConsumerState<BusinessPolicySettingsScreen> {
  static const _creditPolicies = ['WARN', 'BLOCK', 'APPROVAL_REQUIRED'];
  static const _overduePolicies = ['WARN', 'BLOCK', 'APPROVAL_REQUIRED'];
  static const _schemeApplyModes = ['MANUAL', 'AUTO', 'DISABLED'];
  static const _batchPolicies = ['FEFO', 'FIFO', 'MANUAL'];
  static const _dispatchModes = ['CHALLAN_FIRST', 'INVOICE_FIRST', 'COMBINED'];

  final _graceDaysController = TextEditingController();
  bool _saving = false;
  bool _initialized = false;
  String _creditPolicy = 'WARN';
  String _overduePolicy = 'WARN';
  String _schemeApplyMode = 'MANUAL';
  String _batchPolicy = 'FEFO';
  String _dispatchMode = 'CHALLAN_FIRST';

  @override
  void dispose() {
    _graceDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(orgSettingsProvider);
    final role = ref.watch(authProvider).role?.toUpperCase() ?? 'OWNER';
    final canEdit = role == 'OWNER' || role == 'ADMIN';

    return Scaffold(
      appBar: AppBar(title: const Text('Business Policies')),
      body: settingsAsync.when(
        loading: () => const KLoading(message: 'Loading policies...'),
        error: (_, __) => KErrorView(
          message: 'Failed to load business policies',
          onRetry: () => ref.invalidate(orgSettingsProvider),
        ),
        data: (settings) {
          _hydrateOnce(settings);
          return ListView(
            padding: KSpacing.pagePadding,
            children: [
              if (!canEdit) ...[
                _InfoBanner(
                  icon: Icons.lock_outline,
                  text:
                      'Only owner and admin users can change business policies.',
                ),
                KSpacing.vGapMd,
              ],
              _PolicySection(
                title: 'Sales Controls',
                subtitle:
                    'Credit and overdue checks run when Sales Orders are created.',
                children: [
                  _PolicyDropdown(
                    label: 'Credit policy',
                    value: _creditPolicy,
                    items: _creditPolicies,
                    enabled: canEdit && !_saving,
                    onChanged: (value) => setState(() => _creditPolicy = value),
                  ),
                  KSpacing.vGapMd,
                  _PolicyDropdown(
                    label: 'Overdue invoice policy',
                    value: _overduePolicy,
                    items: _overduePolicies,
                    enabled: canEdit && !_saving,
                    onChanged: (value) =>
                        setState(() => _overduePolicy = value),
                  ),
                  KSpacing.vGapMd,
                  TextField(
                    controller: _graceDaysController,
                    enabled: canEdit && !_saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Overdue grace days',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  KSpacing.vGapMd,
                  _PolicyDropdown(
                    label: 'Sales Order scheme mode',
                    value: _schemeApplyMode,
                    items: _schemeApplyModes,
                    enabled: canEdit && !_saving,
                    onChanged: (value) =>
                        setState(() => _schemeApplyMode = value),
                  ),
                ],
              ),
              KSpacing.vGapMd,
              _PolicySection(
                title: 'Inventory & Dispatch',
                subtitle:
                    'These decide how stock batches are suggested and how sales documents move forward.',
                children: [
                  _PolicyDropdown(
                    label: 'Batch issue policy',
                    value: _batchPolicy,
                    items: _batchPolicies,
                    enabled: canEdit && !_saving,
                    onChanged: (value) => setState(() => _batchPolicy = value),
                  ),
                  KSpacing.vGapMd,
                  _PolicyDropdown(
                    label: 'Dispatch mode',
                    value: _dispatchMode,
                    items: _dispatchModes,
                    enabled: canEdit && !_saving,
                    onChanged: (value) => setState(() => _dispatchMode = value),
                  ),
                ],
              ),
              KSpacing.vGapMd,
              _InfoBanner(
                icon: Icons.account_balance_outlined,
                text:
                    'These settings do not post accounting or stock by themselves. They only control validation and document flow.',
              ),
              KSpacing.vGapLg,
              KButton(
                label: _saving ? 'Saving...' : 'Save Policies',
                icon: Icons.save_outlined,
                fullWidth: true,
                onPressed: canEdit && !_saving ? () => _save(settings) : null,
              ),
            ],
          );
        },
      ),
    );
  }

  void _hydrateOnce(Map<String, String> settings) {
    if (_initialized) return;
    _creditPolicy =
        _safeValue(settings['sales.credit_policy'], _creditPolicies, 'WARN');
    _overduePolicy =
        _safeValue(settings['sales.overdue_policy'], _overduePolicies, 'WARN');
    _schemeApplyMode = _safeValue(
        settings['sales.scheme_apply_mode'], _schemeApplyModes, 'MANUAL');
    _batchPolicy =
        _safeValue(settings['inventory.batch_policy'], _batchPolicies, 'FEFO');
    _dispatchMode = _safeValue(
        settings['sales.dispatch_mode'], _dispatchModes, 'CHALLAN_FIRST');
    _graceDaysController.text = _safeInt(settings['sales.overdue_grace_days']);
    _initialized = true;
  }

  String _safeValue(String? raw, List<String> allowed, String fallback) {
    final value = (raw ?? '').trim().toUpperCase();
    return allowed.contains(value) ? value : fallback;
  }

  String _safeInt(String? raw) {
    final value = int.tryParse((raw ?? '').trim());
    if (value == null || value < 0) return '0';
    return value.toString();
  }

  Future<void> _save(Map<String, String> currentSettings) async {
    setState(() => _saving = true);
    try {
      final next = Map<String, String>.from(currentSettings)
        ..['sales.credit_policy'] = _creditPolicy
        ..['sales.overdue_policy'] = _overduePolicy
        ..['sales.overdue_grace_days'] = _safeInt(_graceDaysController.text)
        ..['sales.scheme_apply_mode'] = _schemeApplyMode
        ..['inventory.batch_policy'] = _batchPolicy
        ..['sales.dispatch_mode'] = _dispatchMode;

      await ref.read(orgSettingsRepositoryProvider).updateAll(next);
      ref.invalidate(orgSettingsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business policies saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save business policies'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PolicySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _PolicySection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: KTypography.h3),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: KTypography.bodySmall.copyWith(
              color: KColors.textSecondary,
              height: 1.35,
            ),
          ),
          KSpacing.vGapMd,
          ...children,
        ],
      ),
    );
  }
}

class _PolicyDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _PolicyDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: [
        for (final item in items)
          DropdownMenuItem(
            value: item,
            child: Text(_label(item)),
          ),
      ],
      onChanged: enabled ? (value) => onChanged(value!) : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  String _label(String value) {
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .map((part) =>
            part.isEmpty ? part : part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: cs.primary),
          KSpacing.hGapSm,
          Expanded(
            child: Text(
              text,
              style: KTypography.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
