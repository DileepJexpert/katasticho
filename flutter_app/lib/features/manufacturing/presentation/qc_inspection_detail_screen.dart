import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
import '../data/qc_repository.dart';

class QcInspectionDetailScreen extends ConsumerStatefulWidget {
  const QcInspectionDetailScreen({super.key, required this.inspectionId});
  final String inspectionId;

  @override
  ConsumerState<QcInspectionDetailScreen> createState() =>
      _QcInspectionDetailScreenState();
}

class _QcInspectionDetailScreenState
    extends ConsumerState<QcInspectionDetailScreen> {
  Map<String, dynamic>? _inspection;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(qcRepositoryProvider);
      final data = await repo.getInspection(widget.inspectionId);
      if (mounted) setState(() => _inspection = data);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
          body: KErrorView(message: _error!, onRetry: _load));
    }
    if (_inspection == null) {
      return const Scaffold(
          body: KErrorView(message: 'Inspection not found'));
    }

    final ins = _inspection!;
    final status = ins['status']?.toString() ?? '';
    final results = (ins['results'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .toList() ??
        [];
    final isEditable =
        status == 'PENDING' || status == 'IN_PROGRESS';

    return Scaffold(
      appBar: AppBar(
        title: Text(
            ins['inspectionNumber']?.toString() ?? 'Inspection'),
        actions: isEditable
            ? [
                IconButton(
                  icon: const Icon(Icons.checklist_rtl),
                  tooltip: 'Record Results',
                  onPressed: () => _showRecordResultsDialog(results),
                ),
                IconButton(
                  icon: const Icon(Icons.verified_outlined),
                  tooltip: 'Finalize',
                  onPressed: _showFinalizeDialog,
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Status banner ───────────────────────────────────────────
            _StatusBanner(status: status),
            const SizedBox(height: 16),

            // ── Overview card ───────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Divider(height: 20),
                    _InfoRow('Inspection #',
                        ins['inspectionNumber']?.toString() ?? ''),
                    _InfoRow('Type',
                        ins['inspectionType']?.toString() ?? ''),
                    _InfoRow('Status', status),
                    if (ins['referenceType'] != null)
                      _InfoRow('Ref. Type',
                          ins['referenceType'].toString()),
                    if (ins['referenceId'] != null)
                      _InfoRow('Reference',
                          (ins['referenceLabel'] as String?) ??
                              _truncate(ins['referenceId'].toString())),
                    _InfoRow('Item',
                        (ins['itemName'] as String?) ??
                            _truncate(ins['itemId']?.toString() ?? '')),
                    if (ins['batchId'] != null)
                      _InfoRow('Batch',
                          (ins['batchNumber'] as String?) ??
                              _truncate(ins['batchId'].toString())),
                    _InfoRow('Inspected Qty',
                        ins['inspectedQty']?.toString() ?? '0'),
                    if (ins['acceptedQty'] != null)
                      _InfoRow('Accepted Qty',
                          ins['acceptedQty'].toString()),
                    if (ins['rejectedQty'] != null)
                      _InfoRow('Rejected Qty',
                          ins['rejectedQty'].toString()),
                    if (ins['inspectorId'] != null)
                      _InfoRow('Inspector',
                          (ins['inspectorName'] as String?) ??
                              _truncate(ins['inspectorId'].toString())),
                    if (ins['inspectedAt'] != null)
                      _InfoRow('Inspected At',
                          _formatDate(ins['inspectedAt'].toString())),
                    if (ins['notes'] != null &&
                        ins['notes'].toString().isNotEmpty)
                      _InfoRow('Notes', ins['notes'].toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Results card ────────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Inspection Results',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${results.length} parameter(s)',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No results recorded yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...results.map(
                          (r) => _ResultRow(result: r)),
                  ],
                ),
              ),
            ),

            // ── Action buttons (bottom area for PENDING / IN_PROGRESS) ──
            if (isEditable) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.checklist_rtl),
                      label: const Text('Record Results'),
                      onPressed: () =>
                          _showRecordResultsDialog(results),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('Finalize'),
                      onPressed: _showFinalizeDialog,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  Future<void> _showRecordResultsDialog(
      List<Map<String, dynamic>> existingResults) async {
    // Build editable result rows pre-populated from existing results.
    final rows = existingResults.isNotEmpty
        ? existingResults
            .map((r) => _ResultInput.fromMap(r))
            .toList()
        : [_ResultInput()];

    await showDialog<void>(
      context: context,
      builder: (ctx) => _RecordResultsDialog(
        initialRows: rows,
        onSubmit: (updatedRows) async {
          final payload = updatedRows
              .map((r) => r.toMap())
              .toList();
          try {
            await ref
                .read(qcRepositoryProvider)
                .recordResults(widget.inspectionId, payload);
            _invalidateAndReload('Results recorded');
          } catch (e) {
            _showError(e);
          }
        },
      ),
    );
  }

  Future<void> _showFinalizeDialog() async {
    final acceptedCtl = TextEditingController(
      text: _inspection?['acceptedQty']?.toString() ?? '',
    );
    final rejectedCtl = TextEditingController(
      text: _inspection?['rejectedQty']?.toString() ?? '',
    );
    final notesCtl = TextEditingController(
      text: _inspection?['notes']?.toString() ?? '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalize Inspection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: acceptedCtl,
              decoration: const InputDecoration(
                  labelText: 'Accepted Qty', border: OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: rejectedCtl,
              decoration: const InputDecoration(
                  labelText: 'Rejected Qty', border: OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtl,
              decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalize')),
        ],
      ),
    );

    if (confirmed != true) return;

    final accepted = double.tryParse(acceptedCtl.text.trim()) ?? 0;
    final rejected = double.tryParse(rejectedCtl.text.trim()) ?? 0;
    final notes = notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim();

    try {
      await ref.read(qcRepositoryProvider).finalizeInspection(
            widget.inspectionId,
            acceptedQty: accepted,
            rejectedQty: rejected,
            notes: notes,
          );
      _invalidateAndReload('Inspection finalized');
    } catch (e) {
      _showError(e);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _invalidateAndReload(String message) {
    ref.invalidate(qcInspectionDetailProvider(widget.inspectionId));
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  String _truncate(String value, {int max = 12}) =>
      value.length > max ? '${value.substring(0, max)}...' : value;

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Status banner ─────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      'PENDING' => (Colors.grey, Icons.hourglass_empty),
      'IN_PROGRESS' => (Colors.blue, Icons.science),
      'PASSED' => (Colors.green, Icons.check_circle),
      'FAILED' => (Colors.red, Icons.cancel),
      'PARTIAL' => (Colors.orange, Icons.adjust),
      _ => (Colors.grey, Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            status.replaceAll('_', ' '),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

// ── Result row (read-only) ───────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paramName = result['parameterName']?.toString();
    final rawParamId = result['parameterId']?.toString() ?? '';
    final paramId = (paramName != null && paramName.isNotEmpty)
        ? paramName
        : (rawParamId.length > 12
            ? '${rawParamId.substring(0, 12)}...'
            : rawParamId);
    final measuredValue = result['measuredValue']?.toString() ?? '';
    final numericValue = result['numericValue'];
    final isPassed = result['isPassed'] == true;
    final notes = result['notes']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isPassed ? Icons.check_circle : Icons.cancel,
            color: isPassed ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Param: $paramId',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (measuredValue.isNotEmpty)
                  Text('Value: $measuredValue',
                      style: theme.textTheme.bodySmall),
                if (numericValue != null)
                  Text('Numeric: $numericValue',
                      style: theme.textTheme.bodySmall),
                if (notes.isNotEmpty)
                  Text(
                    notes,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Record results dialog ─────────────────────────────────────────────────────

class _RecordResultsDialog extends StatefulWidget {
  const _RecordResultsDialog({
    required this.initialRows,
    required this.onSubmit,
  });
  final List<_ResultInput> initialRows;
  final Future<void> Function(List<_ResultInput> rows) onSubmit;

  @override
  State<_RecordResultsDialog> createState() => _RecordResultsDialogState();
}

class _RecordResultsDialogState extends State<_RecordResultsDialog> {
  late List<_ResultInput> _rows;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rows = List.from(widget.initialRows);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record Results'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Scroll area for rows
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ..._rows.asMap().entries.map(
                          (entry) => _ResultInputRow(
                            key: ValueKey(entry.key),
                            row: entry.value,
                            index: entry.key,
                            onRemove: _rows.length > 1
                                ? () => setState(
                                    () => _rows.removeAt(entry.key))
                                : null,
                            onChanged: () => setState(() {}),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Row'),
              onPressed: () => setState(() => _rows.add(_ResultInput())),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(_rows);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

// ── Individual result input row ───────────────────────────────────────────────

class _ResultInputRow extends StatefulWidget {
  const _ResultInputRow({
    super.key,
    required this.row,
    required this.index,
    required this.onRemove,
    required this.onChanged,
  });
  final _ResultInput row;
  final int index;
  final VoidCallback? onRemove;
  final VoidCallback onChanged;

  @override
  State<_ResultInputRow> createState() => _ResultInputRowState();
}

class _ResultInputRowState extends State<_ResultInputRow> {
  late TextEditingController _paramCtl;
  late TextEditingController _measuredCtl;
  late TextEditingController _numericCtl;
  late TextEditingController _notesCtl;

  @override
  void initState() {
    super.initState();
    _paramCtl = TextEditingController(text: widget.row.parameterId);
    _measuredCtl = TextEditingController(text: widget.row.measuredValue);
    _numericCtl = TextEditingController(
        text: widget.row.numericValue?.toString() ?? '');
    _notesCtl = TextEditingController(text: widget.row.notes);
  }

  @override
  void dispose() {
    _paramCtl.dispose();
    _measuredCtl.dispose();
    _numericCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  void _sync() {
    widget.row.parameterId = _paramCtl.text.trim();
    widget.row.measuredValue = _measuredCtl.text.trim();
    widget.row.numericValue =
        double.tryParse(_numericCtl.text.trim());
    widget.row.notes = _notesCtl.text.trim();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Row ${widget.index + 1}',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (widget.onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: widget.onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _paramCtl,
              decoration: const InputDecoration(
                labelText: 'Parameter ID (UUID)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _sync(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _measuredCtl,
              decoration: const InputDecoration(
                labelText: 'Measured Value',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _sync(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _numericCtl,
              decoration: const InputDecoration(
                labelText: 'Numeric Value',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _sync(),
            ),
            const SizedBox(height: 8),
            // isPassed toggle
            Row(
              children: [
                const Text('Passed?'),
                const SizedBox(width: 8),
                Switch(
                  value: widget.row.isPassed,
                  onChanged: (v) {
                    setState(() => widget.row.isPassed = v);
                    widget.onChanged();
                  },
                ),
                const Spacer(),
                Icon(
                  widget.row.isPassed
                      ? Icons.check_circle
                      : Icons.cancel,
                  color: widget.row.isPassed
                      ? Colors.green
                      : Colors.red,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              onChanged: (_) => _sync(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mutable result input model ────────────────────────────────────────────────

class _ResultInput {
  _ResultInput({
    this.parameterId = '',
    this.measuredValue = '',
    this.numericValue,
    this.isPassed = false,
    this.notes = '',
  });

  factory _ResultInput.fromMap(Map<String, dynamic> m) => _ResultInput(
        parameterId: m['parameterId']?.toString() ?? '',
        measuredValue: m['measuredValue']?.toString() ?? '',
        numericValue: (m['numericValue'] as num?)?.toDouble(),
        isPassed: m['isPassed'] == true,
        notes: m['notes']?.toString() ?? '',
      );

  String parameterId;
  String measuredValue;
  double? numericValue;
  bool isPassed;
  String notes;

  Map<String, dynamic> toMap() => {
        if (parameterId.isNotEmpty) 'parameterId': parameterId,
        if (measuredValue.isNotEmpty) 'measuredValue': measuredValue,
        if (numericValue != null) 'numericValue': numericValue,
        'isPassed': isPassed,
        if (notes.isNotEmpty) 'notes': notes,
      };
}
