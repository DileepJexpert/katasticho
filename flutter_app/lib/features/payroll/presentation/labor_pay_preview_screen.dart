import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';

/// Production→payroll preview (tracker #57). HR selects an employee +
/// a period and sees the total hours, pieces, and computed labour pay
/// that the payroll run would post for that worker — before actually
/// running the run.
class LaborPayPreviewScreen extends ConsumerStatefulWidget {
  const LaborPayPreviewScreen({super.key});

  @override
  ConsumerState<LaborPayPreviewScreen> createState() =>
      _LaborPayPreviewScreenState();
}

class _LaborPayPreviewScreenState extends ConsumerState<LaborPayPreviewScreen> {
  String? _selectedEmpId;
  List<Map<String, dynamic>> _employees = [];
  bool _loadingEmployees = true;
  late DateTime _from;
  late DateTime _to;
  ({String empId, DateTime from, DateTime to})? _query;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0); // last day of current month
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConfig.payrollEmployees);
      final data = res.data['data'] ?? res.data;
      final content = data is Map ? (data['content'] as List?) ?? [] : data;
      if (mounted) {
        setState(() {
          _employees = (content as List)
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
          _loadingEmployees = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _from = picked.start;
        _to = picked.end;
      });
      if (_selectedEmpId != null) {
        setState(() => _query = (empId: _selectedEmpId!, from: _from, to: _to));
      }
    }
  }

  void _run() {
    if (_selectedEmpId == null) return;
    setState(() => _query = (empId: _selectedEmpId!, from: _from, to: _to));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Production Labor Pay & Piece-Rate Preview'),
      ),
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          KCard(
            title: 'Calculate Production Wage Estimate',
            subtitle: 'Preview piece-rate and hourly production wages derived from shopfloor work orders before executing payroll runs.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_loadingEmployees)
                  const KLoading(message: 'Loading employees...')
                else
                  DropdownButtonFormField<String>(
                    initialValue: _selectedEmpId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Select Worker / Employee *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final emp in _employees)
                        DropdownMenuItem(
                          value: emp['id']?.toString(),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: '${emp['fullName'] ?? '--'} ('),
                                TextSpan(
                                  text: emp['employeeCode'] ?? 'No Code',
                                  style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                TextSpan(text: ') · ${emp['designation'] ?? 'Worker'}'),
                              ],
                            ),
                            style: KTypography.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _selectedEmpId = v),
                  ),
                KSpacing.vGapMd,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range_rounded, size: 18),
                        label: Text(
                          '${DateFormatter.display(_from)} → ${DateFormatter.display(_to)}',
                          style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    KSpacing.hGapMd,
                    KButton.primary(
                      label: 'Preview Wages',
                      icon: Icons.calculate_rounded,
                      onPressed: _selectedEmpId == null ? null : _run,
                    ),
                  ],
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,
          if (_query == null)
            const KEmptyState(
              icon: Icons.calculate_outlined,
              title: 'Select Worker & Period',
              subtitle: 'Pick an employee and work duration to inspect job cards, piece outputs, and rate calculations.',
            )
          else
            _PreviewView(query: _query!),
        ],
      ),
    );
  }
}

class _PreviewView extends ConsumerWidget {
  final ({String empId, DateTime from, DateTime to}) query;
  const _PreviewView({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_previewProvider(query));
    final cs = Theme.of(context).colorScheme;

    return async.when(
      loading: () => const Center(child: KLoading(message: 'Calculating production pay...')),
      error: (e, _) => KErrorView(message: ApiErrorParser.message(e)),
      data: (pay) {
        final payType = pay['payType']?.toString() ?? 'SALARY';
        final salary = payType == 'SALARY';
        final amt = (pay['amount'] as num?)?.toDouble() ?? 0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Pay Structure Model: ', style: KTypography.labelSmall),
                      KSpacing.hGapSm,
                      KStatusChip(status: payType),
                    ],
                  ),
                  KSpacing.vGapMd,
                  if (salary)
                    Text(
                      'This employee is on a fixed monthly salary — the piece-rate production bridge does not apply. '
                      'Their earnings derive directly from the monthly salary structure components.',
                      style: KTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                    )
                  else ...[
                    Row(
                      children: [
                        Text('Calculated Production Pay: ', style: KTypography.titleMedium),
                        KMoney(amt, style: KTypography.titleLarge.copyWith(color: KColors.success, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Aggregated across approved shopfloor job cards completed over the selected period.',
                      style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            KSpacing.vGapMd,
            KCard(
              title: 'Production Metrics Breakdown',
              child: Column(
                children: [
                  _Metric(label: 'Total Production Hours', value: '${pay['totalHours'] ?? 0} hrs'),
                  const Divider(height: 1),
                  _Metric(label: 'Total Finished Pieces', value: '${pay['totalPieces'] ?? 0} units'),
                  const Divider(height: 1),
                  _Metric(
                    label: 'Completed Job Cards',
                    value: '${pay['jobCardCount'] ?? 0}',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: KTypography.bodyMedium)),
          Text(value, style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

final _previewProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({String empId, DateTime from, DateTime to})>(
        (ref, q) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.get(
    ApiConfig.employeeLaborPayPreview(q.empId),
    queryParameters: {
      'periodStart': q.from.toIso8601String().split('T').first,
      'periodEnd': q.to.toIso8601String().split('T').first,
    },
  );
  final data = res.data['data'];
  return data is Map<String, dynamic>
      ? data
      : <String, dynamic>{
          'payType': 'SALARY',
          'amount': 0,
          'totalHours': 0,
          'totalPieces': 0,
          'jobCardCount': 0,
        };
});
