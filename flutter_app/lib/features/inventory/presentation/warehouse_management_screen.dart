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
        title: const Text('Warehouses'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(warehouseManagementListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add warehouse'),
        tooltip: 'Add warehouse (N)',
      ),
      body: warehouses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(warehouseManagementListProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return KEmptyState(
              icon: Icons.warehouse_outlined,
              title: 'No warehouses yet',
              subtitle: 'Add the locations you stock and ship from.',
              actionLabel: 'Add warehouse',
              onAction: () => _openForm(context, ref, null),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(warehouseManagementListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(KSpacing.md),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: KSpacing.sm),
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
    // The API response uses `active`; keep `isActive` as a compatibility
    // fallback for older payloads.
    final isActive = w['active'] == true || w['isActive'] == true;
    final location = [w['city'], w['state']]
        .where((s) => s != null && (s as String).isNotEmpty)
        .join(', ');
    return KCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(w['name']?.toString() ?? '—',
                        style: KTypography.labelLarge,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  if (isDefault) const KStatusChip(status: 'DEFAULT'),
                  if (!isActive) ...[
                    const SizedBox(width: 4),
                    const KStatusChip(status: 'INACTIVE'),
                  ],
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  Text(w['code']?.toString() ?? '',
                      style: KTypography.mono(size: 12, color: KColors.textSecondary)),
                  if (location.isNotEmpty) ...[
                    const SizedBox(width: KSpacing.sm),
                    Flexible(
                      child: Text(location,
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onAction(context, ref, w, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (!isDefault)
                const PopupMenuItem(value: 'delete', child: Text('Remove')),
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
          title: const Text('Remove warehouse?'),
          content: Text('"${w['name']}" will be removed. This is blocked if it '
              'still holds stock.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: KColors.error),
              child: const Text('Remove'),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(KSpacing.md, KSpacing.md, KSpacing.md, bottom + KSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit warehouse' : 'New warehouse',
                style: KTypography.labelLarge),
            const SizedBox(height: KSpacing.md),
            Row(children: [
              Expanded(child: KTextField(label: 'Code', controller: _code, hint: 'WH1')),
              const SizedBox(width: KSpacing.sm),
              Expanded(flex: 2, child: KTextField(label: 'Name', controller: _name)),
            ]),
            const SizedBox(height: KSpacing.sm),
            KTextField(label: 'Address line 1', controller: _addr1),
            const SizedBox(height: KSpacing.sm),
            KTextField(label: 'Address line 2', controller: _addr2),
            const SizedBox(height: KSpacing.sm),
            Row(children: [
              Expanded(child: KTextField(label: 'City', controller: _city)),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: KTextField(label: 'State', controller: _state)),
            ]),
            const SizedBox(height: KSpacing.sm),
            Row(children: [
              Expanded(child: KTextField(label: 'State code', controller: _stateCode, hint: '27')),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: KTextField(label: 'PIN', controller: _postal)),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: KTextField(label: 'Country', controller: _country)),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default warehouse'),
              subtitle: Text('Used when no warehouse is picked',
                  style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active warehouse'),
              subtitle: Text('Available for stock, purchasing, and sales',
                  style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
              value: _isActive,
              onChanged: (v) {
                if (!v && _isDefault) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Choose another default warehouse first')));
                  return;
                }
                setState(() => _isActive = v);
              },
            ),
            const SizedBox(height: KSpacing.sm),
            KButton(
              label: _isEdit ? 'Save' : 'Create',
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
