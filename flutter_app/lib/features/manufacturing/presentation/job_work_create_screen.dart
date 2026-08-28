import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
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
  final _outputItemCtl = TextEditingController();
  final _outputQtyCtl = TextEditingController();

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
    _outputItemCtl.dispose();
    _outputQtyCtl.dispose();
    for (final row in _materialRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardFormWrapper(
      onSubmit: _submit,
      onCancel: () => context.pop(),
      child: Scaffold(
        appBar: AppBar(title: const Text('New Job Work Order')),
        body: ListView(
          padding: KSpacing.pagePadding,
          children: [
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order Information', style: KTypography.titleMedium),
                    KSpacing.vGapMd,
                    // Vendor
                    KTextField(
                      controller: _vendorCtl,
                      label: 'Vendor ID *',
                      hint: 'e.g. 3fa85f64-5717-4562-b3fc-2c963f66afa6',
                    ),

                    KSpacing.vGapMd,

                    // Warehouse
                    KTextField(
                      controller: _warehouseCtl,
                      label: 'Warehouse ID *',
                      hint: 'e.g. 3fa85f64-5717-4562-b3fc-2c963f66afa6',
                    ),

                    KSpacing.vGapMd,

                    // Processing charges
                    KTextField(
                      controller: _processingChargesCtl,
                      label: 'Processing Charges (₹)',
                      keyboardType: TextInputType.number,
                      hint: '0.00',
                    ),

                    KSpacing.vGapMd,

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
                        KSpacing.hGapMd,
                        Expanded(
                          child: _DateField(
                            label: 'Planned Return Date',
                            value: _plannedReturnDate,
                            onPick: (d) => setState(() => _plannedReturnDate = d),
                          ),
                        ),
                      ],
                    ),

                    KSpacing.vGapMd,

                    // Notes
                    KTextField(
                      controller: _notesCtl,
                      label: 'Notes',
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            KSpacing.vGapMd,

            // Materials section
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Materials to Send (Raw / Semi-finished)',
                            style: KTypography.titleMedium,
                          ),
                        ),
                        KButton.outlined(
                          size: KButtonSize.small,
                          onPressed: () => setState(() => _materialRows.add(_MaterialRow())),
                          icon: Icons.add,
                          label: 'Add Row',
                        ),
                      ],
                    ),
                    KSpacing.vGapMd,

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
                                decoration: const InputDecoration(
                                  labelText: 'Item ID (UUID) *',
                                  hintText: 'Item UUID',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            KSpacing.hGapSm,
                            Expanded(
                              child: TextField(
                                controller: row.qtyCtl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Qty *',
                                  hintText: '0',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            KSpacing.hGapXs,
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, size: 20),
                              color: KColors.error,
                              tooltip: 'Remove row',
                              onPressed: _materialRows.length > 1
                                  ? () {
                                      setState(() {
                                        _materialRows[index].dispose();
                                        _materialRows.removeAt(index);
                                      });
                                    }
                                  : null,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            KSpacing.vGapMd,

            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finished Good to Receive',
                      style: KTypography.titleMedium,
                    ),
                    KSpacing.vGapXs,
                    Text(
                      'Specify the finished output item the subcontractor will return after processing.',
                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                    ),
                    KSpacing.vGapMd,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _outputItemCtl,
                            decoration: const InputDecoration(
                              labelText: 'Finished Good Item ID (UUID) *',
                              hintText: 'Item UUID',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        KSpacing.hGapSm,
                        Expanded(
                          child: TextField(
                            controller: _outputQtyCtl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Expected Qty *',
                              hintText: '0',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            KSpacing.vGapLg,

            KButton.primary(
              fullWidth: true,
              onPressed: _submitting ? null : _submit,
              label: _submitting ? 'Creating Order...' : 'Create Job Work Order',
            ),

            KSpacing.vGapMd,
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final vendorId = _vendorCtl.text.trim();
    final warehouseId = _warehouseCtl.text.trim();

    if (vendorId.isEmpty || warehouseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vendor ID and Warehouse ID are required'), backgroundColor: KColors.error),
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
        const SnackBar(content: Text('Add at least one material with a valid qty'), backgroundColor: KColors.error),
      );
      return;
    }

    final outputItemId = _outputItemCtl.text.trim();
    final outputQty = double.tryParse(_outputQtyCtl.text.trim());
    if (outputItemId.isEmpty || outputQty == null || outputQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add the finished-good item and expected quantity'), backgroundColor: KColors.error),
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
        outputs: [{'itemId': outputItemId, 'qty': outputQty}],
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
            backgroundColor: KColors.success,
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
          SnackBar(content: Text('Failed: ${ApiErrorParser.message(e)}'), backgroundColor: KColors.error),
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
          border: const OutlineInputBorder(),
        ),
        child: Text(
          value != null
              ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
              : 'Not set',
          style: TextStyle(color: value != null ? null : KColors.textSecondary),
        ),
      ),
    );
  }
}
