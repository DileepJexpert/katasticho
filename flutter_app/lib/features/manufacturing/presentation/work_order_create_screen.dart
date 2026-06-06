import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/manufacturing_repository.dart';

class WorkOrderCreateScreen extends ConsumerStatefulWidget {
  const WorkOrderCreateScreen({super.key});

  @override
  ConsumerState<WorkOrderCreateScreen> createState() => _WorkOrderCreateScreenState();
}

class _WorkOrderCreateScreenState extends ConsumerState<WorkOrderCreateScreen> {
  final _qtyCtl = TextEditingController(text: '1');
  final _laborCtl = TextEditingController();
  final _overheadCtl = TextEditingController();
  final _notesCtl = TextEditingController();
  final _itemSearchCtl = TextEditingController();
  final _warehouseSearchCtl = TextEditingController();

  DateTime? _plannedStart;
  DateTime? _plannedEnd;

  String? _selectedItemId;
  String? _selectedItemLabel;
  String? _selectedWarehouseId;
  String? _selectedWarehouseLabel;

  List<Map<String, dynamic>> _itemResults = [];
  List<Map<String, dynamic>> _warehouseResults = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadWarehouses();
  }

  Future<void> _loadWarehouses() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConfig.warehouses);
      final data = res.data;
      if (data is Map && data['data'] is List) {
        setState(() {
          _warehouseResults = (data['data'] as List).whereType<Map<String, dynamic>>().toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _searchItems(String query) async {
    if (query.length < 2) {
      setState(() => _itemResults = []);
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConfig.items, queryParameters: {
        'search': query,
        'size': 10,
        'itemType': 'COMPOSITE',
      });
      final data = res.data;
      List<Map<String, dynamic>> items = [];
      if (data is Map) {
        final d = data['data'];
        if (d is Map && d['content'] is List) {
          items = (d['content'] as List).whereType<Map<String, dynamic>>().toList();
        } else if (d is List) {
          items = d.whereType<Map<String, dynamic>>().toList();
        }
      }
      if (mounted) setState(() => _itemResults = items);
    } catch (_) {}
  }

  @override
  void dispose() {
    _qtyCtl.dispose();
    _laborCtl.dispose();
    _overheadCtl.dispose();
    _notesCtl.dispose();
    _itemSearchCtl.dispose();
    _warehouseSearchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New Work Order')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Finished Good (Composite Item)', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          if (_selectedItemId != null)
            KCard(
              child: ListTile(
                title: Text(_selectedItemLabel ?? _selectedItemId!),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _selectedItemId = null;
                    _selectedItemLabel = null;
                    _itemSearchCtl.clear();
                  }),
                ),
              ),
            )
          else ...[
            TextField(
              controller: _itemSearchCtl,
              decoration: const InputDecoration(
                hintText: 'Search composite items...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _searchItems,
            ),
            if (_itemResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _itemResults.length,
                  itemBuilder: (ctx, i) {
                    final item = _itemResults[i];
                    final sku = item['sku']?.toString() ?? '';
                    final name = item['name']?.toString() ?? '';
                    final type = item['itemType']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      title: Text('$sku - $name'),
                      subtitle: Text(type),
                      onTap: () => setState(() {
                        _selectedItemId = item['id']?.toString();
                        _selectedItemLabel = '$sku - $name';
                        _itemResults = [];
                        _itemSearchCtl.clear();
                      }),
                    );
                  },
                ),
              ),
          ],

          const SizedBox(height: 16),
          Text('Warehouse', style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _selectedWarehouseId,
            decoration: const InputDecoration(hintText: 'Select warehouse'),
            items: _warehouseResults.map((w) {
              final id = w['id']?.toString() ?? '';
              final name = w['name']?.toString() ?? id;
              return DropdownMenuItem(value: id, child: Text(name));
            }).toList(),
            onChanged: (v) => setState(() {
              _selectedWarehouseId = v;
              _selectedWarehouseLabel = _warehouseResults
                  .firstWhere((w) => w['id']?.toString() == v, orElse: () => {})['name']?.toString();
            }),
          ),

          const SizedBox(height: 16),
          KTextField(
            controller: _qtyCtl,
            label: 'Quantity to Produce',
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Planned Start',
                  value: _plannedStart,
                  onPick: (d) => setState(() => _plannedStart = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Planned End',
                  value: _plannedEnd,
                  onPick: (d) => setState(() => _plannedEnd = d),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: KTextField(
                  controller: _laborCtl,
                  label: 'Direct Labor Cost',
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KTextField(
                  controller: _overheadCtl,
                  label: 'Overhead Cost',
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          KTextField(
            controller: _notesCtl,
            label: 'Notes',
            maxLines: 3,
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Create Work Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_selectedItemId == null || _selectedWarehouseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a composite item and warehouse')),
      );
      return;
    }
    final qty = double.tryParse(_qtyCtl.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(manufacturingRepositoryProvider);
      final result = await repo.createWorkOrder(
        finishedGoodId: _selectedItemId!,
        warehouseId: _selectedWarehouseId!,
        quantityToProduce: qty,
        plannedStartDate: _plannedStart != null
            ? '${_plannedStart!.year}-${_plannedStart!.month.toString().padLeft(2, '0')}-${_plannedStart!.day.toString().padLeft(2, '0')}'
            : null,
        plannedEndDate: _plannedEnd != null
            ? '${_plannedEnd!.year}-${_plannedEnd!.month.toString().padLeft(2, '0')}-${_plannedEnd!.day.toString().padLeft(2, '0')}'
            : null,
        directLaborCost: double.tryParse(_laborCtl.text.trim()),
        overheadCost: double.tryParse(_overheadCtl.text.trim()),
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );

      ref.invalidate(workOrdersProvider(null));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Work order ${result['workOrderNumber'] ?? ''} created'),
            backgroundColor: Colors.green,
          ),
        );
        final id = result['id']?.toString();
        if (id != null) {
          context.go('/manufacturing/work-orders/$id');
        } else {
          context.go(Routes.manufacturingWorkOrders);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onPick});
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value != null
              ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
              : 'Not set',
          style: TextStyle(color: value != null ? null : Colors.grey),
        ),
      ),
    );
  }
}
