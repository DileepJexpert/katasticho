import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/inventory_repository.dart';

final _warehouseZonesProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, warehouseId) {
  return ref
      .watch(inventoryRepositoryProvider)
      .getWarehouseZones(warehouseId: warehouseId);
});

final _warehousesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(inventoryRepositoryProvider).getWarehouses();
});

class WarehouseZoneScreen extends ConsumerStatefulWidget {
  const WarehouseZoneScreen({super.key});

  @override
  ConsumerState<WarehouseZoneScreen> createState() => _WarehouseZoneScreenState();
}

class _WarehouseZoneScreenState extends ConsumerState<WarehouseZoneScreen> {
  String? _selectedWarehouseId;

  @override
  Widget build(BuildContext context) {
    final warehousesAsync = ref.watch(_warehousesProvider);
    final zonesAsync = ref.watch(_warehouseZonesProvider(_selectedWarehouseId));

    return KKeyboardListWrapper(
      itemCount: () => (zonesAsync.valueOrNull as List?)?.length ?? 0,
      onRefresh: () => ref.invalidate(_warehouseZonesProvider),
      child: Scaffold(
        appBar: AppBar(title: const Text('Warehouse Zones')),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Create Zone (N)',
          onPressed: () => _showCreateZoneSheet(context),
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            // Warehouse selector
            warehousesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (warehouses) => Padding(
                padding: const EdgeInsets.fromLTRB(
                    KSpacing.md, KSpacing.md, KSpacing.md, 0),
                child: DropdownButtonFormField<String>(
                  value: _selectedWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse',
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('All Warehouses'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Warehouses')),
                    ...warehouses.map((w) {
                      final wh = w as Map<String, dynamic>;
                      return DropdownMenuItem(
                        value: wh['id'] as String,
                        child: Text(wh['name'] as String? ?? ''),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => _selectedWarehouseId = v),
                ),
              ),
            ),
            // Zones list
            Expanded(
              child: zonesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
                data: (zones) {
                  if (zones.isEmpty) {
                    return const Center(child: Text('No zones defined for this warehouse'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(_warehouseZonesProvider),
                    child: ListView.builder(
                      padding: KSpacing.screenPadding,
                      itemCount: zones.length,
                      itemBuilder: (_, i) {
                        final zone = zones[i] as Map<String, dynamic>;
                        return _ZoneCard(zone: zone);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateZoneSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateZoneSheet(
        warehouseId: _selectedWarehouseId,
        onCreated: () => ref.invalidate(_warehouseZonesProvider),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final Map<String, dynamic> zone;
  const _ZoneCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    final zoneType = zone['zoneType'] as String? ?? 'STORAGE';
    final color = switch (zoneType) {
      'STORAGE' => KColors.info,
      'QUARANTINE' => KColors.warning,
      'DISPATCH' => KColors.success,
      'RECEIVING' => Colors.purple,
      'RETURNS' => KColors.error,
      _ => KColors.neutral,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.grid_view_outlined),
        title: Row(
          children: [
            Text(zone['name'] as String? ?? '', style: KTypography.titleSmall),
            const SizedBox(width: KSpacing.sm),
            KStatusChip(label: zoneType, color: color),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (zone['description'] != null)
              Text(zone['description'] as String,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Warehouse: ${zone['warehouseName'] ?? 'N/A'}',
                style: KTypography.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _CreateZoneSheet extends ConsumerStatefulWidget {
  final String? warehouseId;
  final VoidCallback onCreated;
  const _CreateZoneSheet({required this.warehouseId, required this.onCreated});

  @override
  ConsumerState<_CreateZoneSheet> createState() => _CreateZoneSheetState();
}

class _CreateZoneSheetState extends ConsumerState<_CreateZoneSheet> {
  final _nameCtrl = TextEditingController();
  String _zoneType = 'STORAGE';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          KSpacing.md,
          KSpacing.md,
          KSpacing.md,
          MediaQuery.of(context).viewInsets.bottom + KSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Zone', style: KTypography.titleMedium),
          const SizedBox(height: KSpacing.md),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Zone Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: KSpacing.sm),
          DropdownButtonFormField<String>(
            value: _zoneType,
            decoration: const InputDecoration(
              labelText: 'Zone Type',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'STORAGE', child: Text('Storage')),
              DropdownMenuItem(value: 'QUARANTINE', child: Text('Quarantine')),
              DropdownMenuItem(value: 'DISPATCH', child: Text('Dispatch')),
              DropdownMenuItem(value: 'RECEIVING', child: Text('Receiving')),
              DropdownMenuItem(value: 'RETURNS', child: Text('Returns')),
            ],
            onChanged: (v) => setState(() => _zoneType = v!),
          ),
          const SizedBox(height: KSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              const SizedBox(width: KSpacing.sm),
              FilledButton(
                onPressed: _loading ? null : _create,
                child: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      await ref.read(inventoryRepositoryProvider).createWarehouseZone({
        'name': _nameCtrl.text.trim(),
        'zoneType': _zoneType,
        if (widget.warehouseId != null) 'warehouseId': widget.warehouseId,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ApiErrorParser.message(e)),
              backgroundColor: KColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
