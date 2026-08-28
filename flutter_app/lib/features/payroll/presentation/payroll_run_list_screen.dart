import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';

class PayrollRunListScreen extends ConsumerStatefulWidget {
  const PayrollRunListScreen({super.key});

  @override
  ConsumerState<PayrollRunListScreen> createState() =>
      _PayrollRunListScreenState();
}

class _PayrollRunListScreenState extends ConsumerState<PayrollRunListScreen> {
  String? _status;
  String _search = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _runs = [];

  @override
  void initState() {
    super.initState();
    _fetchRuns();
  }

  Future<void> _fetchRuns() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.payrollRuns);
      final data = response.data['data'] ?? response.data;
      final content = data is Map ? (data['content'] as List?) ?? [] : data;
      _runs = (content as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } on DioException catch (e) {
      _error = ApiErrorParser.message(e);
    } catch (e) {
      _error = 'Failed to load payroll runs';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredRuns {
    return _runs.where((run) {
      final status = run['status']?.toString().toUpperCase();
      if (_status != null && status != _status) return false;
      if (_search.isEmpty) return true;
      final haystack = [
        run['runNumber'],
        run['periodStart'],
        run['periodEnd'],
        run['status'],
        run['notes'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(_search);
    }).toList();
  }

  Future<void> _showCreateDialog() async {
    final now = DateTime.now();
    var periodStart = DateTime(now.year, now.month, 1);
    var periodEnd = DateTime(now.year, now.month + 1, 0); // last day of month

    final result = await showDialog<Map<String, DateTime>>(
      context: context,
      builder: (ctx) => _CreatePayrollRunDialog(
        initialStart: periodStart,
        initialEnd: periodEnd,
      ),
    );

    if (result == null || !mounted) return;

    periodStart = result['periodStart']!;
    periodEnd = result['periodEnd']!;

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.post(
        ApiConfig.payrollRuns,
        data: {
          'periodStart': DateFormatter.api(periodStart),
          'periodEnd': DateFormatter.api(periodEnd),
        },
      );

      final data = response.data['data'] ?? response.data;
      final newId = data is Map ? data['id']?.toString() : null;

      await _fetchRuns();

      if (mounted && newId != null) {
        context.push('/payroll/runs/$newId');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create payroll run'), backgroundColor: KColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => _filteredRuns.length,
      onNew: _showCreateDialog,
      onRefresh: _fetchRuns,
      onOpen: (index) {
        final filtered = _filteredRuns;
        if (index < filtered.length) {
          final id = filtered[index]['id']?.toString();
          if (id != null) context.push('/payroll/runs/$id');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Monthly Payroll Runs & Processing'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchRuns,
            ),
          ],
        ),
        body: _loading
            ? const KLoading(message: 'Loading monthly payroll runs...')
            : _error != null
                ? Padding(
                    padding: KSpacing.pagePadding,
                    child: KErrorView(message: _error!, onRetry: _fetchRuns),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchRuns,
                    child: ListView(
                      padding: KSpacing.pagePadding,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Payroll Runs & Cycles',
                                    style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Execute monthly cycles: Draft → Auto-Calculate → Review & Approve → Post GL Journals.',
                                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            KButton.primary(
                              label: 'New Run',
                              icon: Icons.add_rounded,
                              onPressed: _showCreateDialog,
                            ),
                          ],
                        ),
                        KSpacing.vGapMd,
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterChip(
                                label: 'All (${_runs.length})',
                                selected: _status == null,
                                onSelected: () => setState(() => _status = null),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Draft',
                                selected: _status == 'DRAFT',
                                onSelected: () => setState(() => _status = 'DRAFT'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Calculated',
                                selected: _status == 'CALCULATED',
                                onSelected: () => setState(() => _status = 'CALCULATED'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Approved',
                                selected: _status == 'APPROVED',
                                onSelected: () => setState(() => _status = 'APPROVED'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Posted',
                                selected: _status == 'POSTED',
                                onSelected: () => setState(() => _status = 'POSTED'),
                              ),
                              const SizedBox(width: 8),
                              _FilterChip(
                                label: 'Cancelled',
                                selected: _status == 'CANCELLED',
                                onSelected: () => setState(() => _status = 'CANCELLED'),
                              ),
                            ],
                          ),
                        ),
                        KSpacing.vGapMd,
                        TextFormField(
                          decoration: InputDecoration(
                            hintText: 'Search by run reference number or pay period...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
                          ),
                          onChanged: (val) => setState(() => _search = val.trim().toLowerCase()),
                        ),
                        KSpacing.vGapMd,
                        if (_filteredRuns.isEmpty)
                          KEmptyState(
                            icon: Icons.account_balance_wallet_outlined,
                            title: _runs.isEmpty ? 'No payroll runs created' : 'No matching payroll runs',
                            subtitle: _runs.isEmpty
                                ? 'Create your first payroll run to calculate employee salaries, taxes, and statutory deductions.'
                                : 'Try changing status filters or searching a different term.',
                            actionLabel: _runs.isEmpty ? 'Start New Run' : 'Clear Filters',
                            onAction: _runs.isEmpty
                                ? _showCreateDialog
                                : () => setState(() {
                                      _status = null;
                                      _search = '';
                                    }),
                          )
                        else
                          ..._filteredRuns.map((run) {
                            return _PayrollRunCard(
                              run: run,
                              onTap: () async {
                                final id = run['id']?.toString();
                                if (id != null) {
                                  await context.push('/payroll/runs/$id');
                                  _fetchRuns();
                                }
                              },
                            );
                          }),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: KTypography.labelSmall.copyWith(
        color: selected ? cs.onPrimaryContainer : cs.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selectedColor: cs.primaryContainer,
      showCheckmark: false,
    );
  }
}

// ---------------------------------------------------------------------------
// Create dialog
// ---------------------------------------------------------------------------

class _CreatePayrollRunDialog extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;

  const _CreatePayrollRunDialog({
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  State<_CreatePayrollRunDialog> createState() =>
      _CreatePayrollRunDialogState();
}

class _CreatePayrollRunDialogState extends State<_CreatePayrollRunDialog> {
  late DateTime _periodStart;
  late DateTime _periodEnd;

  @override
  void initState() {
    super.initState();
    _periodStart = widget.initialStart;
    _periodEnd = widget.initialEnd;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _periodStart : _periodEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _periodStart = picked;
          if (_periodStart.isAfter(_periodEnd)) {
            _periodEnd = DateTime(picked.year, picked.month + 1, 0);
          }
        } else {
          _periodEnd = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Initiate Monthly Payroll Run'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select pay cycle date boundaries for gross salary, PF/ESI/PT calculations, and attendance regularization.',
              style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
            KSpacing.vGapMd,
            KCard(
              onTap: () => _pickDate(isStart: true),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Period Start Date *', style: KTypography.labelSmall),
                        Text(DateFormatter.display(_periodStart), style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_calendar_rounded, size: 16, color: cs.onSurfaceVariant),
                ],
              ),
            ),
            KSpacing.vGapSm,
            KCard(
              onTap: () => _pickDate(isStart: false),
              child: Row(
                children: [
                  Icon(Icons.event_rounded, size: 18, color: cs.primary),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Period End Date *', style: KTypography.labelSmall),
                        Text(DateFormatter.display(_periodEnd), style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_calendar_rounded, size: 16, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        KButton.primary(
          label: 'Create Run',
          size: KButtonSize.small,
          icon: Icons.check_rounded,
          onPressed: () {
            if (_periodEnd.isBefore(_periodStart)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Period end date must be after start date')),
              );
              return;
            }
            Navigator.of(context).pop({
              'periodStart': _periodStart,
              'periodEnd': _periodEnd,
            });
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Payroll run card
// ---------------------------------------------------------------------------

class _PayrollRunCard extends StatelessWidget {
  final Map<String, dynamic> run;
  final VoidCallback onTap;

  const _PayrollRunCard({required this.run, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = (run['status']?.toString() ?? 'DRAFT').toUpperCase();
    final runNumber = run['runNumber']?.toString();
    final employeeCount = (run['employeeCount'] as num?)?.toInt() ?? 0;
    final grossTotal = (run['totalGross'] as num?)?.toDouble() ?? 0;
    final netTotal = (run['totalNet'] as num?)?.toDouble() ?? 0;

    final periodStartRaw = run['periodStart']?.toString();
    final periodEndRaw = run['periodEnd']?.toString();
    final periodLabel = _formatPeriodLabel(periodStartRaw, periodEndRaw);

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(KSpacing.radiusMd),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: cs.primary,
                size: 22,
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Payroll: $periodLabel',
                                style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (runNumber != null && runNumber.isNotEmpty) ...[
                              KSpacing.hGapSm,
                              Text(
                                runNumber,
                                style: KTypography.mono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      KSpacing.hGapSm,
                      KStatusChip(status: status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, size: 14, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        '$employeeCount',
                        style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        ' employee${employeeCount == 1 ? '' : 's'} included',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Gross: ',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                      KMoney(grossTotal, size: KMoneySize.small),
                      const SizedBox(width: 14),
                      Text(
                        'Net Pay: ',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                      KMoney(
                        netTotal,
                        size: KMoneySize.small,
                        style: const TextStyle(
                          color: KColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            KSpacing.hGapSm,
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  String _formatPeriodLabel(String? startRaw, String? endRaw) {
    if (startRaw == null || endRaw == null) return '--';
    try {
      final start = DateTime.parse(startRaw);
      final end = DateTime.parse(endRaw);

      if (start.year == end.year && start.month == end.month) {
        return DateFormatter.monthYear(start);
      }
      return '${DateFormatter.display(start)} - ${DateFormatter.display(end)}';
    } catch (_) {
      return '$startRaw - $endRaw';
    }
  }
}
