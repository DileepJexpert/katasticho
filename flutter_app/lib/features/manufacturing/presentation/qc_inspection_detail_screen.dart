import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
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
    if (_loading) {
      return const Scaffold(
          body: Center(child: KLoading(message: 'Loading inspection...')));
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
    final isFinalized =
        status == 'PASSED' || status == 'FAILED' || status == 'PARTIAL';
    final hasDisposition = ins['disposition'] != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
            ins['inspectionNumber']?.toString() ?? 'Inspection'),
        actions: [
          if (isEditable) ...[
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
          ],
          if (isFinalized) ...[
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'Certificate of Analysis',
              onPressed: _showCoaDialog,
            ),
            if (!hasDisposition)
              IconButton(
                icon: const Icon(Icons.gavel_outlined),
                tooltip: 'Record Disposition',
                onPressed: _showDispositionDialog,
              ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            // ── Status banner ───────────────────────────────────────────
            _StatusBanner(status: status),
            KSpacing.vGapMd,

            // ── Overview card ───────────────────────────────────────────
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: KTypography.titleSmall,
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
                    if (ins['disposition'] != null) ...[
                      const Divider(height: 20),
                      _InfoRow('Disposition',
                          ins['disposition'].toString()),
                      if (ins['holdQty'] != null)
                        _InfoRow('Hold Qty', ins['holdQty'].toString()),
                      if (ins['dispositionNotes'] != null &&
                          ins['dispositionNotes'].toString().isNotEmpty)
                        _InfoRow('Disp. Notes',
                            ins['dispositionNotes'].toString()),
                      if (ins['dispositionAt'] != null)
                        _InfoRow('Disp. At',
                            _formatDate(ins['dispositionAt'].toString())),
                    ],
                  ],
                ),
              ),
            ),
            KSpacing.vGapMd,

            // ── Results card ────────────────────────────────────────────
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
                            'Inspection Results',
                            style: KTypography.titleSmall,
                          ),
                        ),
                        Text(
                          '${results.length} parameter(s)',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'No results recorded yet.',
                          style: TextStyle(color: KColors.textSecondary),
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
              KSpacing.vGapLg,
              Row(
                children: [
                  Expanded(
                    child: KButton.outlined(
                      icon: Icons.checklist_rtl,
                      label: 'Record Results',
                      onPressed: () =>
                          _showRecordResultsDialog(results),
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: KButton.primary(
                      icon: Icons.verified_outlined,
                      label: 'Finalize',
                      onPressed: _showFinalizeDialog,
                    ),
                  ),
                ],
              ),
            ],
            // ── Disposition / CoA (finalized inspections) ───────────────
            if (isFinalized) ...[
              KSpacing.vGapLg,
              Row(
                children: [
                  Expanded(
                    child: KButton.outlined(
                      icon: Icons.description_outlined,
                      label: 'View CoA',
                      onPressed: _showCoaDialog,
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: KButton.primary(
                      icon: Icons.gavel_outlined,
                      label: hasDisposition
                          ? 'Dispositioned'
                          : 'Record Disposition',
                      onPressed:
                          hasDisposition ? null : _showDispositionDialog,
                    ),
                  ),
                ],
              ),
            ],
            KSpacing.vGapLg,
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  Future<void> _showRecordResultsDialog(
      List<Map<String, dynamic>> existingResults) async {
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
            KSpacing.vGapSm,
            TextField(
              controller: rejectedCtl,
              decoration: const InputDecoration(
                  labelText: 'Rejected Qty', border: OutlineInputBorder()),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            KSpacing.vGapSm,
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
          KButton.outlined(
            size: KButtonSize.small,
            label: 'Cancel',
            onPressed: () => Navigator.pop(ctx, false),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            label: 'Finalize',
            onPressed: () => Navigator.pop(ctx, true),
          ),
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

  Future<void> _showDispositionDialog() async {
    String decision = 'ACCEPT';
    final inspected = (_inspection?['inspectedQty'] as num?)?.toDouble() ?? 0;
    final acceptedCtl = TextEditingController(
      text: (_inspection?['acceptedQty'] ?? inspected).toString(),
    );
    final rejectedCtl = TextEditingController(
      text: (_inspection?['rejectedQty'] ?? 0).toString(),
    );
    final holdCtl = TextEditingController(text: '0');
    final zoneCtl = TextEditingController();
    final notesCtl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Record Disposition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Inspected qty: $inspected. Accepted + Rejected + Hold '
                  'must equal the inspected quantity.',
                  style: KTypography.bodySmall,
                ),
                KSpacing.vGapSm,
                DropdownButtonFormField<String>(
                  initialValue: decision,
                  decoration: const InputDecoration(
                      labelText: 'Decision', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'ACCEPT', child: Text('Accept')),
                    DropdownMenuItem(value: 'REJECT', child: Text('Reject')),
                    DropdownMenuItem(value: 'HOLD', child: Text('Hold')),
                  ],
                  onChanged: (v) => setLocal(() => decision = v ?? decision),
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: acceptedCtl,
                  decoration: const InputDecoration(
                      labelText: 'Accepted Qty', border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: rejectedCtl,
                  decoration: const InputDecoration(
                      labelText: 'Rejected Qty', border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                KSpacing.vGapSm,
                TextField(
                  controller: holdCtl,
                  decoration: const InputDecoration(
                      labelText: 'Hold Qty', border: OutlineInputBorder()),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                if (decision == 'HOLD') ...[
                  KSpacing.vGapSm,
                  TextField(
                    controller: zoneCtl,
                    decoration: const InputDecoration(
                        labelText: 'Quarantine zone id',
                        helperText: 'Required for HOLD',
                        border: OutlineInputBorder()),
                  ),
                ],
                KSpacing.vGapSm,
                TextField(
                  controller: notesCtl,
                  decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            KButton.outlined(
              size: KButtonSize.small,
              label: 'Cancel',
              onPressed: () => Navigator.pop(ctx, false),
            ),
            KSpacing.hGapSm,
            KButton.primary(
              size: KButtonSize.small,
              label: 'Record',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(qcRepositoryProvider).recordDisposition(
            widget.inspectionId,
            decision: decision,
            acceptedQty: double.tryParse(acceptedCtl.text.trim()) ?? 0,
            rejectedQty: double.tryParse(rejectedCtl.text.trim()) ?? 0,
            holdQty: double.tryParse(holdCtl.text.trim()) ?? 0,
            quarantineZoneId:
                zoneCtl.text.trim().isEmpty ? null : zoneCtl.text.trim(),
            notes: notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
          );
      _invalidateAndReload('Disposition recorded');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _showCoaDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Certificate of Analysis'),
        content: FutureBuilder<Map<String, dynamic>>(
          future: ref.read(qcRepositoryProvider).getCoa(widget.inspectionId),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                  height: 80, child: Center(child: KLoading(message: 'Generating CoA...')));
            }
            if (snap.hasError) {
              return Text('Could not load CoA: ${snap.error}');
            }
            final pretty =
                const JsonEncoder.withIndent('  ').convert(snap.data ?? {});
            return SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(pretty,
                    style: KTypography.mono(fontSize: 12)),
              ),
            );
          },
        ),
        actions: [
          KButton.primary(
            size: KButtonSize.small,
            label: 'Close',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _invalidateAndReload(String message) {
    ref.invalidate(qcInspectionDetailProvider(widget.inspectionId));
    _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(message), backgroundColor: KColors.success),
      );
    }
  }

  void _showError(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
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
    return KCard(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Row(
          children: [
            KStatusChip(status: status),
            KSpacing.hGapMd,
            Expanded(
              child: Text(
                'Status: ${status.replaceAll('_', ' ')}',
                style: KTypography.labelLarge,
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(value, style: KTypography.bodyMedium),
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
            color: isPassed ? KColors.success : KColors.error,
            size: 20,
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Param: $paramId',
                  style: KTypography.labelLarge,
                ),
                if (measuredValue.isNotEmpty)
                  Text('Value: $measuredValue', style: KTypography.bodySmall),
                if (numericValue != null)
                  Text('Numeric: $numericValue', style: KTypography.bodySmall),
                if (notes.isNotEmpty)
                  Text(
                    notes,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
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
            KSpacing.vGapSm,
            KButton.outlined(
              size: KButtonSize.small,
              icon: Icons.add,
              label: 'Add Row',
              onPressed: () => setState(() => _rows.add(_ResultInput())),
            ),
          ],
        ),
      ),
      actions: [
        KButton.outlined(
          size: KButtonSize.small,
          label: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        KSpacing.hGapSm,
        KButton.primary(
          size: KButtonSize.small,
          onPressed: _submitting ? null : _submit,
          isLoading: _submitting,
          label: 'Save',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KCard(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Row ${widget.index + 1}',
                    style: KTypography.labelLarge,
                  ),
                  const Spacer(),
                  if (widget.onRemove != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: KColors.error),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onRemove,
                    ),
                ],
              ),
              KSpacing.vGapSm,
              TextField(
                controller: _paramCtl,
                decoration: const InputDecoration(
                  labelText: 'Parameter ID (UUID)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _sync(),
              ),
              KSpacing.vGapSm,
              TextField(
                controller: _measuredCtl,
                decoration: const InputDecoration(
                  labelText: 'Measured Value',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _sync(),
              ),
              KSpacing.vGapSm,
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
              KSpacing.vGapSm,
              Row(
                children: [
                  const Text('Passed?'),
                  KSpacing.hGapSm,
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
                        ? KColors.success
                        : KColors.error,
                    size: 20,
                  ),
                ],
              ),
              KSpacing.vGapSm,
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
