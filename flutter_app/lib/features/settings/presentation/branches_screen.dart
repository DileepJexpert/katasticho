import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Branches')),
      body: async.when(
        loading: () => const KShimmerList(),
        error: (err, _) => KErrorView(
          message: 'Failed to load branches',
          onRetry: () => ref.invalidate(branchListSettingsProvider),
        ),
        data: (branches) {
          if (branches.isEmpty) {
            return KEmptyState(
              icon: Icons.account_tree_outlined,
              title: 'No branches yet',
              subtitle: 'Add a branch to split sales and reports by location',
              actionLabel: 'Add Branch',
              onAction: () => _openCreateSheet(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(branchListSettingsProvider),
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: branches.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (_, i) => _BranchCard(branch: branches[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add Branch'),
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ProviderScope(
        parent: ProviderScope.containerOf(context),
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
    final name = branch['name'] as String? ?? '';
    final code = branch['code'] as String? ?? '';
    final city = branch['city'] as String? ?? '';
    final state = branch['state'] as String? ?? '';
    final isDefault = branch['isDefault'] == true || branch['default'] == true;
    final active = branch['active'] != false;
    final location = [city, state].where((s) => s.isNotEmpty).join(', ');

    return KCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KColors.primary.withValues(alpha: 0.1),
              borderRadius: KSpacing.borderRadiusMd,
            ),
            child: Text(code.isNotEmpty ? code.substring(0, code.length.clamp(0, 3)) : '?',
                style: KTypography.labelSmall.copyWith(color: KColors.primary)),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: KTypography.labelLarge),
                    if (isDefault) ...[
                      KSpacing.hGapSm,
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: KColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Default',
                            style: KTypography.labelSmall.copyWith(color: KColors.success)),
                      ),
                    ],
                  ],
                ),
                if (location.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(location, style: KTypography.bodySmall),
                ],
              ],
            ),
          ),
          Icon(
            active ? Icons.check_circle_outline : Icons.pause_circle_outline,
            color: active ? KColors.success : KColors.textHint,
            size: 20,
          ),
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
      if (!mounted) return;
      ref.invalidate(branchListSettingsProvider);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create branch: $e')),
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
              Text('Add Branch', style: KTypography.h2),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _code,
                      decoration: const InputDecoration(
                          labelText: 'Code *', hintText: 'HQ', border: OutlineInputBorder(), isDense: true),
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
                          labelText: 'Branch Name *', border: OutlineInputBorder(), isDense: true),
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
                    labelText: 'Address', border: OutlineInputBorder(), isDense: true),
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
                        labelText: 'Postal', border: OutlineInputBorder(), isDense: true),
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
                        labelText: 'State', border: OutlineInputBorder(), isDense: true),
                  )),
                  KSpacing.hGapSm,
                  Expanded(child: TextFormField(
                    controller: _stateCode,
                    decoration: const InputDecoration(
                        labelText: 'Code', hintText: 'MH', border: OutlineInputBorder(), isDense: true),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 5,
                  )),
                ],
              ),
              KSpacing.vGapSm,
              TextFormField(
                controller: _gstin,
                decoration: const InputDecoration(
                    labelText: 'GSTIN (if different)', border: OutlineInputBorder(), isDense: true),
              ),
              KSpacing.vGapSm,
              SwitchListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('Set as default branch'),
                contentPadding: EdgeInsets.zero,
              ),
              KSpacing.vGapMd,
              SizedBox(
                width: double.infinity,
                child: KButton(
                  label: 'Create Branch',
                  fullWidth: true,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
