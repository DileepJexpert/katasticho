import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/inventory_repository.dart';

final warehouseManagementListProvider =
    FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(inventoryRepositoryProvider).getWarehouses();
});

/// Warehouse master — create / edit / remove. Warehouses had a create+list
/// backend but no edit or delete, so a mistyped name or a stale location was
/// permanent. (Delete is soft + guarded server-side: the default warehouse and
/// any warehouse still holding stock can't be removed.)
class WarehouseManagementScreen extends ConsumerWidget {
  const WarehouseManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehouses = ref.watch(warehouseManagementListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse Locations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(warehouseManagementListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(context, ref, null),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add Warehouse'),
        tooltip: 'Add warehouse (N)',
      ),
      body: warehouses.when(
        loading: () => const Center(child: KLoading(message: 'Loading warehouse locations...')),
        error: (e, _) => KErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(warehouseManagementListProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return KEmptyState(
              icon: Icons.warehouse_outlined,
              title: 'No Warehouses Configured',
              subtitle: 'Add the warehouse branches and distribution centers you stock and ship from.',
              actionLabel: 'Add Warehouse',
              onAction: () => _openForm(context, ref, null),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(warehouseManagementListProvider),
            child: ListView.separated(
              padding: KSpacing.pagePadding,
              itemCount: rows.length,
              separatorBuilder: (_, __) => KSpacing.vGapSm,
              itemBuilder: (_, i) =>
                  _card(context, ref, Map<String, dynamic>.from(rows[i] as Map)),
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Map<String, dynamic> w) {
    final isDefault = w['isDefault'] == true;
    final isActive = w['active'] == true || w['isActive'] == true;
    final location = [w['city'], w['state']]
        .where((s) => s != null && (s as String).isNotEmpty)
        .join(', ');
    return KCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(KSpacing.sm),
            decoration: BoxDecoration(
              color: (isDefault ? KColors.primary : KColors.textSecondary).withValues(alpha: 0.12),
              borderRadius: KSpacing.borderRadiusSm,
            ),
            child: Icon(
              Icons.warehouse_outlined,
              color: isDefault ? KColors.primary : KColors.textSecondary,
              size: 24,
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        w['name']?.toString() ?? '—',
                        style: KTypography.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    KSpacing.hGapSm,
                    if (isDefault) const KStatusChip(status: 'DEFAULT'),
                    if (!isActive) ...[
                      KSpacing.hGapXs,
                      const KStatusChip(status: 'INACTIVE'),
                    ],
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Text('Code: ', style: KTypography.caption),
                    Text(
                      w['code']?.toString() ?? '',
                      style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600, color: KColors.primary),
                    ),
                    if (location.isNotEmpty) ...[
                      KSpacing.hGapMd,
                      const Icon(Icons.location_on_outlined, size: 14, color: KColors.textSecondary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          location,
                          style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onAction(context, ref, w, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit Warehouse')),
              if (!isDefault)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Remove Location', style: TextStyle(color: KColors.error)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref,
      Map<String, dynamic> w, String action) async {
    if (action == 'edit') {
      await _openForm(context, ref, w);
      return;
    }
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Remove Warehouse Location?', style: KTypography.titleLarge),
          content: Text('"${w['name']}" will be removed. This action is blocked if the warehouse still holds on-hand stock or pending movements.'),
          actions: [
            KButton.outlined(
              label: 'Cancel',
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            KSpacing.hGapSm,
            KButton.danger(
              label: 'Confirm Remove',
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (ok != true) return;
      try {
        await ref.read(inventoryRepositoryProvider).deleteWarehouse(w['id'] as String);
        ref.invalidate(warehouseManagementListProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      }
    }
  }

  Future<void> _openForm(
      BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarehouseFormSheet(existing: existing),
    );
    if (saved == true) ref.invalidate(warehouseManagementListProvider);
  }
}

class _WarehouseFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  const _WarehouseFormSheet({this.existing});

  @override
  ConsumerState<_WarehouseFormSheet> createState() =>
      _WarehouseFormSheetState();
}

class _WarehouseFormSheetState extends ConsumerState<_WarehouseFormSheet> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _addr1 = TextEditingController();
  final _addr2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _stateCode = TextEditingController();
  final _postal = TextEditingController();
  final _country = TextEditingController(text: 'IN');
  bool _isDefault = false;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _code.text = (e['code'] ?? '').toString();
      _name.text = (e['name'] ?? '').toString();
      _addr1.text = (e['addressLine1'] ?? '').toString();
      _addr2.text = (e['addressLine2'] ?? '').toString();
      _city.text = (e['city'] ?? '').toString();
      _state.text = (e['state'] ?? '').toString();
      _stateCode.text = (e['stateCode'] ?? '').toString();
      _postal.text = (e['postalCode'] ?? '').toString();
      _country.text = (e['country'] ?? 'IN').toString();
      _isDefault = e['isDefault'] == true;
      _isActive = e['active'] == true || e['isActive'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in [_code, _name, _addr1, _addr2, _city, _state, _stateCode, _postal, _country]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code and name are required')));
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'code': _code.text.trim(),
      'name': _name.text.trim(),
      'addressLine1': _addr1.text.trim(),
      'addressLine2': _addr2.text.trim(),
      'city': _city.text.trim(),
      'state': _state.text.trim(),
      'stateCode': _stateCode.text.trim(),
      'postalCode': _postal.text.trim(),
      'country': _country.text.trim().isEmpty ? 'IN' : _country.text.trim(),
      'isDefault': _isDefault,
      'active': _isActive,
    };
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      if (_isEdit) {
        await repo.updateWarehouse(widget.existing!['id'] as String, body);
      } else {
        await repo.createWarehouse(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      padding: EdgeInsets.fromLTRB(KSpacing.lg, KSpacing.lg, KSpacing.lg, bottom + KSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(_isEdit ? 'Edit Warehouse Location' : 'New Warehouse Location',
                      style: KTypography.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            KSpacing.vGapMd,
            KCompactRow(children: [
              KTextField(label: 'Warehouse Code', controller: _code, hint: 'e.g. WH-MUM-01'),
              KTextField(label: 'Warehouse Name', controller: _name, hint: 'e.g. Mumbai Central Depot'),
            ]),
            KSpacing.vGapSm,
            KTextField(label: 'Address Line 1', controller: _addr1, hint: 'Plot / Building / Street'),
            KSpacing.vGapSm,
            KTextField(label: 'Address Line 2', controller: _addr2, hint: 'Area / Industrial Estate'),
            KSpacing.vGapSm,
            KCompactRow(children: [
              KTextField(label: 'City', controller: _city),
              KTextField(label: 'State', controller: _state),
            ]),
            KSpacing.vGapSm,
            KCompactRow(children: [
              KTextField(label: 'State Code (GST)', controller: _stateCode, hint: '27'),
              KTextField(label: 'PIN Code', controller: _postal, hint: '400001'),
            ]),
            KSpacing.vGapSm,
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Default Dispatch Warehouse', style: KTypography.titleSmall),
              subtitle: Text('Default source location for sales orders and shipments',
                  style: KTypography.caption.copyWith(color: KColors.textSecondary)),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Active for Stock & Transactions', style: KTypography.titleSmall),
              subtitle: Text('Available for purchasing, transfers, and order fulfillment',
                  style: KTypography.caption.copyWith(color: KColors.textSecondary)),
              value: _isActive,
              onChanged: (v) {
                if (!v && _isDefault) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Select another default warehouse before deactivating this one')));
                  return;
                }
                setState(() => _isActive = v);
              },
            ),
            KSpacing.vGapLg,
            KButton.primary(
              label: _isEdit ? 'Save Warehouse Changes' : 'Create Warehouse Location',
              icon: Icons.check,
              isLoading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
