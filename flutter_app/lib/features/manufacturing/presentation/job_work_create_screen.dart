import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/widgets.dart';
import '../data/manufacturing_repository.dart';

class JobWorkCreateScreen extends ConsumerStatefulWidget {
  const JobWorkCreateScreen({super.key});

  @override
  ConsumerState<JobWorkCreateScreen> createState() => _JobWorkCreateScreenState();
}

class _JobWorkCreateScreenState extends ConsumerState<JobWorkCreateScreen> {
  final _vendorCtl = TextEditingController();
  final _warehouseCtl = TextEditingController();
  final _processingChargesCtl = TextEditingController();
  final _notesCtl = TextEditingController();

  DateTime? _plannedSendDate;
  DateTime? _plannedReturnDate;

  // Each material row: {itemIdCtl, qtyCtl}
  final List<_MaterialRow> _materialRows = [];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Start with one blank material row
    _materialRows.add(_MaterialRow());
  }

  @override
  void dispose() {
    _vendorCtl.dispose();
    _warehouseCtl.dispose();
    _processingChargesCtl.dispose();
    _notesCtl.dispose();
    for (final row in _materialRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New Job Work Order')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Vendor
          KTextField(
            controller: _vendorCtl,
            label: 'Vendor ID (UUID)',
            hintText: 'e.g. 3fa85f64-5717-4562-b3fc-2c963f66afa6',
          ),

          const SizedBox(height: 16),

          // Warehouse
          KTextField(
            controller: _warehouseCtl,
            label: 'Warehouse ID (UUID)',
            hintText: 'e.g. 3fa85f64-5717-4562-b3fc-2c963f66afa6',
          ),

          const SizedBox(height: 16),

          // Processing charges
          KTextField(
            controller: _processingChargesCtl,
            label: 'Processing Charges (₹)',
            keyboardType: TextInputType.number,
            hintText: '0.00',
          ),

          const SizedBox(height: 16),

          // Dates
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Planned Send Date',
                  value: _plannedSendDate,
                  onPick: (d) => setState(() => _plannedSendDate = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Planned Return Date',
                  value: _plannedReturnDate,
                  onPick: (d) => setState(() => _plannedReturnDate = d),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Notes
          KTextField(
            controller: _notesCtl,
            label: 'Notes',
            maxLines: 3,
          ),

          const SizedBox(height: 24),

          // Materials section
          Row(
            children: [
              Expanded(
                child: Text(
                  'Materials to Send',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _materialRows.add(_MaterialRow())),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Row'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Item ID (UUID)',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Qty',
                      style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                ),
                const SizedBox(width: 36), // remove button space
              ],
            ),
          ),

          ..._materialRows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: row.itemIdCtl,
                      decoration: InputDecoration(
                        hintText: 'Item UUID',
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.qtyCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '0',
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    color: Colors.red.shade400,
                    tooltip: 'Remove row',
                    onPressed: _materialRows.length > 1
                        ? () {
                            setState(() {
                              _materialRows[index].dispose();
                              _materialRows.removeAt(index);
                            });
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: const Text('Create Job Work Order'),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final vendorId = _vendorCtl.text.trim();
    final warehouseId = _warehouseCtl.text.trim();

    if (vendorId.isEmpty || warehouseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor ID and Warehouse ID are required')),
      );
      return;
    }

    // Build materials list; skip rows where itemId is blank
    final materials = <Map<String, dynamic>>[];
    for (final row in _materialRows) {
      final itemId = row.itemIdCtl.text.trim();
      final qty = double.tryParse(row.qtyCtl.text.trim());
      if (itemId.isNotEmpty && qty != null && qty > 0) {
        materials.add({'itemId': itemId, 'qty': qty});
      }
    }

    if (materials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one material with a valid qty')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(manufacturingRepositoryProvider);
      final result = await repo.createJobWorkOrder(
        vendorId: vendorId,
        warehouseId: warehouseId,
        materials: materials,
        processingCharges: double.tryParse(_processingChargesCtl.text.trim()),
        plannedSendDate: _plannedSendDate != null ? _formatDate(_plannedSendDate!) : null,
        plannedReturnDate: _plannedReturnDate != null ? _formatDate(_plannedReturnDate!) : null,
        notes: _notesCtl.text.trim().isEmpty ? null : _notesCtl.text.trim(),
      );

      ref.invalidate(jobWorkOrdersProvider(null));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job work order ${result['jobWorkNumber'] ?? ''} created'),
            backgroundColor: Colors.green,
          ),
        );
        final id = result['id']?.toString();
        if (id != null) {
          context.go('/manufacturing/job-work/$id');
        } else {
          context.go('/manufacturing/job-work');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Holds the controllers for a single material row.
class _MaterialRow {
  final itemIdCtl = TextEditingController();
  final qtyCtl = TextEditingController();

  void dispose() {
    itemIdCtl.dispose();
    qtyCtl.dispose();
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
          lastDate: DateTime(2035),
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
