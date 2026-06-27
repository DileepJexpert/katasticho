import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';

/// Salary-structure builder for one employee. Loads the current active
/// structure (read-only) and lets HR compose a new effective-dated structure
/// with component lines (BASIC / HRA / DA / …). Each line resolves to a
/// SalaryComponent by code on the backend (`POST .../salary-structure`).
class SalaryStructureScreen extends ConsumerStatefulWidget {
  const SalaryStructureScreen({super.key, required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<SalaryStructureScreen> createState() =>
      _SalaryStructureScreenState();
}

/// Mutable draft for one component line in the builder.
class _LineDraft {
  String? componentCode;
  String calcType = 'FIXED';
  final amount = TextEditingController();
  final percentage = TextEditingController();
  String? baseComponentCode;
  void dispose() {
    amount.dispose();
    percentage.dispose();
  }
}

class _SalaryStructureScreenState extends ConsumerState<SalaryStructureScreen> {
  static final _dateFmt = DateFormat('yyyy-MM-dd');

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _components = [];
  Map<String, dynamic>? _current;

  DateTime _effectiveFrom =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _payType = 'SALARY';
  final _ctc = TextEditingController();
  final _gross = TextEditingController();
  final _hourlyRate = TextEditingController();
  final _pieceRate = TextEditingController();
  final List<_LineDraft> _lines = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctc.dispose();
    _gross.dispose();
    _hourlyRate.dispose();
    _pieceRate.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final comps = await api.get(ApiConfig.salaryComponents);
      _components = ((comps.data['data'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      try {
        final cur =
            await api.get(ApiConfig.employeeSalaryStructure(widget.employeeId));
        _current = cur.data['data'] as Map<String, dynamic>?;
      } catch (_) {
        _current = null; // 404 PAYROLL_NO_ACTIVE_STRUCTURE — none yet
      }
    } on DioException catch (e) {
      _error = _msg(e) ?? 'Failed to load';
    } catch (_) {
      _error = 'Failed to load';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final usable =
        _lines.where((l) => (l.componentCode ?? '').isNotEmpty).toList();
    if (usable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one component line')),
      );
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final lineBodies = [
        for (final l in usable)
          {
            'componentCode': l.componentCode,
            'calculationType': l.calcType,
            'amount': l.calcType == 'FIXED'
                ? double.tryParse(l.amount.text.trim())
                : null,
            'percentage': l.calcType == 'PERCENTAGE'
                ? double.tryParse(l.percentage.text.trim())
                : null,
            'baseComponentCode':
                l.calcType == 'PERCENTAGE' ? l.baseComponentCode : null,
          }
      ];
      final body = <String, dynamic>{
        'effectiveFrom': _dateFmt.format(_effectiveFrom),
        'ctcMonthly': double.tryParse(_ctc.text.trim()),
        'grossMonthly': double.tryParse(_gross.text.trim()),
        'payType': _payType,
        'hourlyRate':
            _payType == 'HOURLY' ? double.tryParse(_hourlyRate.text.trim()) : null,
        'pieceRate': _payType == 'PIECE_RATE'
            ? double.tryParse(_pieceRate.text.trim())
            : null,
        'lines': lineBodies,
      };
      await ref.read(apiClientProvider).post(
            ApiConfig.employeeSalaryStructure(widget.employeeId),
            data: body,
          );
      messenger.showSnackBar(
          const SnackBar(content: Text('Salary structure saved')));
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      _ctc.clear();
      _gross.clear();
      await _load();
    } on DioException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(_msg(e) ?? 'Save failed'),
        backgroundColor: KColors.error,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salary Structure')),
      body: _loading
          ? const KLoading(message: 'Loading…')
          : _error != null
              ? KErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: KSpacing.pagePadding,
                  children: [
                    if (_current != null) ...[
                      _currentCard(),
                      KSpacing.vGapMd,
                    ],
                    _newStructureForm(),
                    const SizedBox(height: 60),
                  ],
                ),
    );
  }

  // ── Current active structure (read-only) ──────────────────────────────────

  Widget _currentCard() {
    final c = _current!;
    final lines = (c['lines'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    return KCard(
      title: 'Current structure',
      subtitle: 'Effective from ${c['effectiveFrom'] ?? '--'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: KSpacing.sm,
              children: [
                KStatusChip(status: (c['status'] ?? 'ACTIVE').toString()),
                if (c['payType'] != null)
                  Chip(label: Text(c['payType'].toString())),
              ],
            ),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: KSpacing.sm),
                child: Text('No component lines on the active structure.',
                    style: KTypography.bodySmall),
              )
            else
              ...lines.map((l) {
                final comp = (l['salaryComponent'] as Map?) ?? const {};
                final code = comp['code'] ?? l['baseComponentCode'] ?? '--';
                final calc = l['calculationType'] ?? '';
                final detail = calc == 'PERCENTAGE'
                    ? '${l['percentage'] ?? 0}% of ${l['baseComponentCode'] ?? ''}'
                    : '₹${l['amount'] ?? 0}';
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(code.toString())),
                      Text(detail, style: KTypography.bodySmall),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── New structure builder ─────────────────────────────────────────────────

  Widget _newStructureForm() {
    return KCard(
      title: 'New structure',
      subtitle: 'Supersedes the current one from the effective date',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Effective from
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _effectiveFrom,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _effectiveFrom = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Effective from',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event_outlined),
                ),
                child: Text(_dateFmt.format(_effectiveFrom)),
              ),
            ),
            KSpacing.vGapSm,
            DropdownButtonFormField<String>(
              initialValue: _payType,
              decoration: const InputDecoration(
                labelText: 'Pay type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'SALARY', child: Text('Salary (monthly)')),
                DropdownMenuItem(value: 'HOURLY', child: Text('Hourly')),
                DropdownMenuItem(
                    value: 'PIECE_RATE', child: Text('Piece rate')),
              ],
              onChanged: (v) => setState(() => _payType = v ?? 'SALARY'),
            ),
            if (_payType == 'HOURLY') ...[
              KSpacing.vGapSm,
              _money('Hourly rate', _hourlyRate),
            ],
            if (_payType == 'PIECE_RATE') ...[
              KSpacing.vGapSm,
              _money('Piece rate', _pieceRate),
            ],
            KSpacing.vGapSm,
            KCompactRow(children: [
              _money('CTC / month (optional)', _ctc),
              _money('Gross / month (optional)', _gross),
            ]),
            const Divider(height: KSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: Text('Component lines',
                      style: KTypography.labelLarge),
                ),
                KButton(
                  label: 'Add line',
                  icon: Icons.add,
                  variant: KButtonVariant.outlined,
                  size: KButtonSize.small,
                  onPressed: () => setState(() => _lines.add(_LineDraft())),
                ),
              ],
            ),
            if (_lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KSpacing.sm),
                child: Text(
                  'Add the earning components that make up pay (BASIC, HRA, …). '
                  'Statutory deductions (PF/ESI/PT) are auto-computed.',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
              )
            else
              ...List.generate(_lines.length, (i) => _lineCard(i)),
            KSpacing.vGapMd,
            KButton(
              label: 'Save structure',
              icon: Icons.save_outlined,
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard(int i) {
    final l = _lines[i];
    return Card(
      margin: const EdgeInsets.only(top: KSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.sm),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: l.componentCode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Component',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final c in _components)
                        DropdownMenuItem(
                          value: c['code']?.toString(),
                          child: Text(
                            '${c['code']} · ${c['name'] ?? ''}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => l.componentCode = v),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove line',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(() {
                    _lines.removeAt(i).dispose();
                  }),
                ),
              ],
            ),
            KSpacing.vGapSm,
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: l.calcType,
                    decoration: const InputDecoration(
                      labelText: 'Calc',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'FIXED', child: Text('Fixed ₹')),
                      DropdownMenuItem(
                          value: 'PERCENTAGE', child: Text('% of base')),
                    ],
                    onChanged: (v) =>
                        setState(() => l.calcType = v ?? 'FIXED'),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: l.calcType == 'FIXED'
                      ? KTextField(
                          label: 'Amount',
                          controller: l.amount,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        )
                      : KTextField(
                          label: 'Percentage',
                          controller: l.percentage,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                ),
              ],
            ),
            if (l.calcType == 'PERCENTAGE') ...[
              KSpacing.vGapSm,
              DropdownButtonFormField<String>(
                initialValue: l.baseComponentCode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Base component (% applies to)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final c in _components)
                    DropdownMenuItem(
                      value: c['code']?.toString(),
                      child: Text('${c['code']}',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => l.baseComponentCode = v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _money(String label, TextEditingController c) {
    return KTextField(
      label: label,
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      prefixIcon: Icons.currency_rupee,
    );
  }

  static String? _msg(DioException e) {
    final body = e.response?.data;
    return body is Map ? body['message'] as String? : null;
  }
}
