import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
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
      itemCount: () => (zonesAsync.valueOrNull)?.length ?? 0,
      onRefresh: () => ref.invalidate(_warehouseZonesProvider),
      child: Scaffold(
        appBar: AppBar(title: const Text('Warehouse Storage Zones')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: KColors.primary,
          foregroundColor: Colors.white,
          tooltip: 'Create Zone (N)',
          onPressed: () => _showCreateZoneSheet(context),
          icon: const Icon(Icons.add),
          label: const Text('New Zone'),
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
                  initialValue: _selectedWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Warehouse',
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
            KSpacing.vGapSm,
            // Zones list
            Expanded(
              child: zonesAsync.when(
                loading: () => const Center(child: KLoading(message: 'Loading warehouse zones...')),
                error: (e, _) => KErrorView(
                  message: ApiErrorParser.message(e),
                  onRetry: () => ref.invalidate(_warehouseZonesProvider),
                ),
                data: (zones) {
                  if (zones.isEmpty) {
                    return KEmptyState(
                      icon: Icons.grid_view_outlined,
                      title: 'No Warehouse Zones Found',
                      subtitle: 'Divide warehouse floor space into functional zones (storage, receiving, dispatch, quarantine).',
                      actionLabel: 'Create Zone',
                      onAction: () => _showCreateZoneSheet(context),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(_warehouseZonesProvider),
                    child: ListView.separated(
                      padding: KSpacing.pagePadding,
                      itemCount: zones.length,
                      separatorBuilder: (_, __) => KSpacing.vGapSm,
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
      backgroundColor: Colors.transparent,
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

    return KCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(KSpacing.sm),
            decoration: BoxDecoration(
              color: KColors.primary.withValues(alpha: 0.12),
              borderRadius: KSpacing.borderRadiusSm,
            ),
            child: const Icon(Icons.grid_view_outlined, color: KColors.primary, size: 24),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(zone['name'] as String? ?? '', style: KTypography.titleMedium),
                    KSpacing.hGapSm,
                    KStatusChip(status: zoneType),
                  ],
                ),
                if (zone['description'] != null) ...[
                  KSpacing.vGapXs,
                  Text(zone['description'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                ],
                KSpacing.vGapXs,
                Row(
                  children: [
                    const Icon(Icons.warehouse_outlined, size: 14, color: KColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      zone['warehouseName']?.toString() ?? 'Default Warehouse',
                      style: KTypography.caption.copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
  final _descCtrl = TextEditingController();
  String _zoneType = 'STORAGE';
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(KSpacing.radiusLg)),
      ),
      padding: EdgeInsets.fromLTRB(
          KSpacing.lg,
          KSpacing.lg,
          KSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + KSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Create Warehouse Zone', style: KTypography.titleLarge)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            KSpacing.vGapMd,
            KTextField(
              controller: _nameCtrl,
              autofocus: true,
              label: 'Zone Name / Identifier',
              hint: 'e.g. Zone A - Cold Storage, High Rack North',
            ),
            KSpacing.vGapSm,
            DropdownButtonFormField<String>(
              initialValue: _zoneType,
              decoration: const InputDecoration(
                labelText: 'Zone Function Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'STORAGE', child: Text('Standard Storage')),
                DropdownMenuItem(value: 'QUARANTINE', child: Text('Quarantine & Inspection')),
                DropdownMenuItem(value: 'DISPATCH', child: Text('Dispatch & Staging')),
                DropdownMenuItem(value: 'RECEIVING', child: Text('Receiving Dock')),
                DropdownMenuItem(value: 'RETURNS', child: Text('Returns & Quarantine')),
              ],
              onChanged: (v) => setState(() => _zoneType = v!),
            ),
            KSpacing.vGapSm,
            KTextField(
              controller: _descCtrl,
              label: 'Zone Description (Optional)',
              hint: 'Temperature rating, access restrictions, capacity limits',
              maxLines: 2,
            ),
            KSpacing.vGapLg,
            KButton.primary(
              label: 'Create Zone',
              icon: Icons.check,
              isLoading: _loading,
              onPressed: _loading ? null : _create,
            ),
          ],
        ),
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
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
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
