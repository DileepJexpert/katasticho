import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final branchListSettingsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final res = await client.dio.get(ApiConfig.branches);
  final data = res.data['data'];
  if (data is List) return data.cast<Map<String, dynamic>>();
  return [];
});

// ── Screen ────────────────────────────────────────────────────────────────────

class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(branchListSettingsProvider);
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => async.valueOrNull?.length ?? 0,
      onNew: () => _openCreateSheet(context, ref),
      onRefresh: () => ref.invalidate(branchListSettingsProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Multi-Branch & Locations'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.invalidate(branchListSettingsProvider),
            ),
          ],
        ),
        body: async.when(
          loading: () => const KLoading(message: 'Loading branches and store locations...'),
          error: (err, _) => Padding(
            padding: KSpacing.pagePadding,
            child: KErrorView(
              message: ApiErrorParser.message(err),
              onRetry: () => ref.invalidate(branchListSettingsProvider),
            ),
          ),
          data: (branches) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(branchListSettingsProvider),
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company Branches & Outlets',
                              style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage multi-location GSTINs, physical warehouses, billing counters, and default headquarters.',
                              style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      KButton.primary(
                        label: 'Add Branch',
                        icon: Icons.add_business_rounded,
                        onPressed: () => _openCreateSheet(context, ref),
                      ),
                    ],
                  ),
                  KSpacing.vGapLg,
                  if (branches.isEmpty)
                    KEmptyState(
                      icon: Icons.account_tree_outlined,
                      title: 'No branches configured yet',
                      subtitle: 'Add branch offices or retail outlets to segregate invoicing, inventory, and GST returns by location.',
                      actionLabel: 'Add Branch',
                      onAction: () => _openCreateSheet(context, ref),
                    )
                  else
                    ...branches.map((b) => _BranchCard(branch: b)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => UncontrolledProviderScope(
        container: ProviderScope.containerOf(context),
        child: const _BranchCreateSheet(),
      ),
    );
  }
}

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;

  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = branch['name'] as String? ?? '';
    final code = branch['code'] as String? ?? '';
    final city = branch['city'] as String? ?? '';
    final state = branch['state'] as String? ?? '';
    final gstin = branch['gstin'] as String?;
    final isDefault = branch['isDefault'] == true || branch['default'] == true;
    final active = branch['active'] != false;
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
            ),
            child: Text(
              code.isNotEmpty ? code.substring(0, code.length.clamp(0, 3)).toUpperCase() : 'BR',
              style: KTypography.titleSmall.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700)),
                    if (isDefault) ...[
                      KSpacing.hGapSm,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: KColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: KTypography.mono(fontSize: 10, fontWeight: FontWeight.w700, color: KColors.success),
                        ),
                      ),
                    ],
                  ],
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(location, style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ],
                if (gstin != null && gstin.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'GSTIN: $gstin',
                    style: KTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          KStatusChip(status: active ? 'ACTIVE' : 'INACTIVE'),
        ],
      ),
    );
  }
}

// ── Create Sheet ──────────────────────────────────────────────────────────────

class _BranchCreateSheet extends ConsumerStatefulWidget {
  const _BranchCreateSheet();

  @override
  ConsumerState<_BranchCreateSheet> createState() => _BranchCreateSheetState();
}

class _BranchCreateSheetState extends ConsumerState<_BranchCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _code = TextEditingController();
  final _name = TextEditingController();
  final _addr1 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _stateCode = TextEditingController();
  final _postal = TextEditingController();
  final _gstin = TextEditingController();
  bool _isDefault = false;

  @override
  void dispose() {
    for (final c in [_code, _name, _addr1, _city, _state, _stateCode, _postal, _gstin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final client = ref.read(apiClientProvider);
      await client.dio.post(ApiConfig.branches, data: {
        'code': _code.text.trim().toUpperCase(),
        'name': _name.text.trim(),
        'addressLine1': _addr1.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'stateCode': _stateCode.text.trim().toUpperCase(),
        'postalCode': _postal.text.trim(),
        'gstin': _gstin.text.trim(),
        'isDefault': _isDefault,
      });
      ref.invalidate(branchListSettingsProvider);
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Branch created successfully'), backgroundColor: KColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to create branch: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Add New Branch Location', style: KTypography.h2),
              const SizedBox(height: 4),
              Text(
                'Configure branch address and optional distinct GSTIN.',
                style: KTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(
                          labelText: 'Branch Code *', hintText: 'HQ / BR-01', border: OutlineInputBorder(), isDense: true),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 20,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Branch Name *', hintText: 'Headquarters / Warehouse 1', border: OutlineInputBorder(), isDense: true),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              TextFormField(
                controller: _addr1,
                decoration: const InputDecoration(
                    labelText: 'Street Address', border: OutlineInputBorder(), isDense: true),
              ),
              KSpacing.vGapSm,
              Row(
                children: [
                  Expanded(child: TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(
                        labelText: 'City', border: OutlineInputBorder(), isDense: true),
                  )),
                  KSpacing.hGapSm,
                  Expanded(child: TextFormField(
                    controller: _postal,
                    decoration: const InputDecoration(
                        labelText: 'PIN / Postal Code', border: OutlineInputBorder(), isDense: true),
                    keyboardType: TextInputType.number,
                  )),
                ],
              ),
              KSpacing.vGapSm,
              Row(
                children: [
                  Expanded(flex: 3, child: TextFormField(
                    controller: _state,
                    decoration: const InputDecoration(
                        labelText: 'State / Province', border: OutlineInputBorder(), isDense: true),
                  )),
                  KSpacing.hGapSm,
                  Expanded(child: TextFormField(
                    controller: _stateCode,
                    decoration: const InputDecoration(
                        labelText: 'State Code', hintText: '27 / MH', border: OutlineInputBorder(), isDense: true),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 5,
                  )),
                ],
              ),
              KSpacing.vGapSm,
              TextFormField(
                controller: _gstin,
                decoration: const InputDecoration(
                    labelText: 'Branch GSTIN (if distinct state registration)', border: OutlineInputBorder(), isDense: true),
              ),
              KSpacing.vGapSm,
              SwitchListTile.adaptive(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('Set as primary default branch'),
                contentPadding: EdgeInsets.zero,
              ),
              KSpacing.vGapMd,
              KButton.primary(
                label: 'Create Branch Location',
                icon: Icons.check_rounded,
                fullWidth: true,
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
