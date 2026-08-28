import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/item_repository.dart';

class RackLocationsScreen extends ConsumerStatefulWidget {
  const RackLocationsScreen({super.key});

  @override
  ConsumerState<RackLocationsScreen> createState() => _RackLocationsScreenState();
}

class _RackLocationsScreenState extends ConsumerState<RackLocationsScreen> {
  bool _loading = true;
  bool _seeding = false;
  String? _selectedWarehouseId;
  List<Map<String, dynamic>> _warehouses = const [];
  List<Map<String, dynamic>> _racks = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(itemRepositoryProvider);
      final warehouses = await repo.listWarehouses();
      final selectedWarehouseId = _selectedWarehouseId ??
          warehouses.cast<Map<String, dynamic>?>().firstWhere(
                (w) => w?['isDefault'] == true,
                orElse: () => warehouses.isNotEmpty ? warehouses.first : null,
              )?['id']?.toString();
      final racks = await repo.listRackLocationsForWarehouse(selectedWarehouseId);
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses;
        _selectedWarehouseId = selectedWarehouseId;
        _racks = racks;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load rack locations: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadRacks() async {
    try {
      final racks = await ref
          .read(itemRepositoryProvider)
          .listRackLocationsForWarehouse(_selectedWarehouseId);
      if (!mounted) return;
      setState(() => _racks = racks);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to refresh rack locations: $e')),
      );
    }
  }

  Future<void> _seedDemoLayout() async {
    setState(() => _seeding = true);
    try {
      await ref.read(itemRepositoryProvider).seedDemoRackLocations();
      await _reloadRacks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo rack layout loaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load demo rack layout: $e')),
      );
    } finally {
      if (mounted) setState(() => _seeding = false);
    }
  }

  Future<void> _openCreateSheet() async {
    if (_selectedWarehouseId == null) return;
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CreateRackSheet(
        warehouseId: _selectedWarehouseId!,
        warehouseName: _warehouseLabel(_selectedWarehouseId!),
      ),
    );
    if (created == true) {
      await _reloadRacks();
    }
  }

  String _warehouseLabel(String warehouseId) {
    final warehouse = _warehouses.cast<Map<String, dynamic>?>().firstWhere(
          (w) => w?['id']?.toString() == warehouseId,
          orElse: () => null,
        );
    final code = warehouse?['code']?.toString();
    final name = warehouse?['name']?.toString();
    if (name == null || name.isEmpty) return code ?? 'Warehouse';
    if (code == null || code.isEmpty) return name;
    return '$name ($code)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rack Locations'),
        actions: [
          TextButton.icon(
            onPressed: _seeding ? null : _seedDemoLayout,
            icon: _seeding
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_outlined),
            label: const Text('Load Demo Layout'),
          ),
        ],
      ),
      body: _loading
          ? const KLoading()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  KCard(
                    title: 'Rack Master',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configure rack codes per warehouse. These codes show in item details and POS search so staff can find medicines quickly.',
                          style: KTypography.bodySmall,
                        ),
                        KSpacing.vGapMd,
                        DropdownButtonFormField<String>(
                          initialValue: _selectedWarehouseId,
                          decoration: const InputDecoration(
                            labelText: 'Warehouse',
                            border: OutlineInputBorder(),
                          ),
                          items: _warehouses
                              .map(
                                (warehouse) => DropdownMenuItem<String>(
                                  value: warehouse['id']?.toString(),
                                  child: Text(
                                    _warehouseLabel(
                                      warehouse['id']?.toString() ?? '',
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            setState(() => _selectedWarehouseId = value);
                            await _reloadRacks();
                          },
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapMd,
                  if (_racks.isEmpty)
                    KEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No rack locations yet',
                      subtitle:
                          'Create your own rack layout or load the demo layout to test item and POS rack visibility.',
                      actionLabel: 'Add Rack',
                      onAction: _openCreateSheet,
                    )
                  else ...[
                    KCard(
                      title: 'Configured Racks',
                      action: KButton.outlined(
                        label: 'Add Rack',
                        icon: Icons.add,
                        size: KButtonSize.small,
                        onPressed: _openCreateSheet,
                      ),
                      child: Column(
                        children: _racks
                            .map(
                              (rack) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  radius: 18,
                                  child: Text(
                                    ((rack['code']?.toString().isNotEmpty ?? false)
                                            ? rack['code'].toString().substring(0, 1)
                                            : 'R')
                                        .toUpperCase(),
                                  ),
                                ),
                                title: Text(
                                  rack['code']?.toString() ?? 'Rack',
                                  style: KTypography.mono(size: 13, weight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  [
                                    rack['name']?.toString(),
                                    rack['zone']?.toString(),
                                    rack['aisle']?.toString(),
                                    rack['shelf']?.toString(),
                                    rack['bin']?.toString(),
                                  ].where((v) => v != null && v.isNotEmpty).join(' • '),
                                  style: KTypography.bodySmall,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    KSpacing.vGapMd,
                    KCard(
                      title: 'Suggested Demo Mapping',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('A1-01 -> Fast-moving tablets'),
                          Text('B1-01 -> Capsules'),
                          Text('B2-01 -> Syrups and bottles'),
                          Text('C1-01 -> Injections'),
                          Text('D1-01 -> Surgical and devices'),
                          Text('FRZ-01 -> Cold chain'),
                          Text('OTC-01 -> Front counter OTC'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
      floatingActionButton: _racks.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: _openCreateSheet,
              icon: const Icon(Icons.add),
              label: const Text('Add Rack'),
              tooltip: 'Add Rack (N)',
            ),
    );
  }
}

class _CreateRackSheet extends ConsumerStatefulWidget {
  final String warehouseId;
  final String warehouseName;

  const _CreateRackSheet({
    required this.warehouseId,
    required this.warehouseName,
  });

  @override
  ConsumerState<_CreateRackSheet> createState() => _CreateRackSheetState();
}

class _CreateRackSheetState extends ConsumerState<_CreateRackSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _zoneController = TextEditingController();
  final _aisleController = TextEditingController();
  final _shelfController = TextEditingController();
  final _binController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _zoneController.dispose();
    _aisleController.dispose();
    _shelfController.dispose();
    _binController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(itemRepositoryProvider).createRackLocation({
        'warehouseId': widget.warehouseId,
        'code': _codeController.text.trim().toUpperCase(),
        'name': _nameController.text.trim(),
        'zone': _zoneController.text.trim(),
        'aisle': _aisleController.text.trim(),
        'shelf': _shelfController.text.trim(),
        'bin': _binController.text.trim(),
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save rack: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Rack Location', style: KTypography.h3),
              KSpacing.vGapXs,
              Text(widget.warehouseName, style: KTypography.bodySmall),
              KSpacing.vGapMd,
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Rack Code',
                  hintText: 'A1-01',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Code is required' : null,
              ),
              KSpacing.vGapSm,
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Fast-moving tablets',
                  border: OutlineInputBorder(),
                ),
              ),
              KSpacing.vGapSm,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _zoneController,
                      decoration: const InputDecoration(
                        labelText: 'Zone',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: TextFormField(
                      controller: _aisleController,
                      decoration: const InputDecoration(
                        labelText: 'Aisle',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              KSpacing.vGapSm,
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _shelfController,
                      decoration: const InputDecoration(
                        labelText: 'Shelf',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: TextFormField(
                      controller: _binController,
                      decoration: const InputDecoration(
                        labelText: 'Bin',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              KSpacing.vGapMd,
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  KButton.outlined(
                    label: 'Cancel',
                    size: KButtonSize.small,
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  ),
                  KSpacing.hGapSm,
                  KButton.primary(
                    label: 'Save',
                    icon: Icons.save_outlined,
                    size: KButtonSize.small,
                    isLoading: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
