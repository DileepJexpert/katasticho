import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';

/// Production→payroll preview (tracker #57). HR pastes an employee id +
/// a period and sees the total hours, pieces, and computed labour pay
/// that the payroll run would post for that worker — before actually
/// running the run.
///
/// The bridge only produces a non-zero amount when the employee's
/// current salary structure has `payType=HOURLY` or
/// `PIECE_RATE` AND the corresponding rate is set. SALARY workers
/// always return zero (their pay comes from the structure components).
class LaborPayPreviewScreen extends ConsumerStatefulWidget {
  const LaborPayPreviewScreen({super.key});

  @override
  ConsumerState<LaborPayPreviewScreen> createState() =>
      _LaborPayPreviewScreenState();
}

class _LaborPayPreviewScreenState extends ConsumerState<LaborPayPreviewScreen> {
  final _empCtl = TextEditingController();
  late DateTime _from;
  late DateTime _to;
  ({String empId, DateTime from, DateTime to})? _query;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0); // last day of current month
  }

  @override
  void dispose() {
    _empCtl.dispose();
    super.dispose();
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
    }
  }

  void _run() {
    final id = _empCtl.text.trim();
    if (id.isEmpty) return;
    setState(() => _query = (empId: id, from: _from, to: _to));
  }

  String _iso(DateTime d) => d.toIso8601String().split('T').first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Labor Pay Preview')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              children: [
                TextField(
                  controller: _empCtl,
                  decoration: const InputDecoration(
                    labelText: 'Employee id',
                    helperText:
                        'The payroll employee whose production-driven pay you want to preview',
                    prefixIcon: Icon(Icons.engineering_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: KSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range),
                        label: Text('${_iso(_from)} → ${_iso(_to)}'),
                      ),
                    ),
                    const SizedBox(width: KSpacing.sm),
                    FilledButton(
                        onPressed: _run, child: const Text('Preview')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _query == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calculate_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: KSpacing.md),
                        Text('Enter an employee id + period to preview labour pay'),
                      ],
                    ),
                  )
                : _PreviewView(query: _query!),
          ),
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
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (pay) {
        final payType = pay['payType']?.toString() ?? 'SALARY';
        final salary = payType == 'SALARY';
        return ListView(
          padding: KSpacing.pagePadding,
          children: [
            Card(
              color: salary ? Colors.amber.shade50 : Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(salary ? Icons.info_outline : Icons.attach_money,
                          color: salary ? Colors.orange : Colors.green),
                      const SizedBox(width: 8),
                      Text('Pay type: $payType', style: KTypography.titleMedium),
                    ]),
                    const SizedBox(height: 8),
                    if (salary)
                      const Text(
                        'This employee is on a fixed monthly salary — the production bridge does not apply. '
                        'Their pay comes from the salary structure components.',
                      ),
                    if (!salary) ...[
                      Text('₹${pay['amount']}',
                          style: KTypography.h3),
                      const SizedBox(height: 4),
                      Text('over the selected period from production data',
                          style: KTypography.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: KSpacing.md),
            Card(
              child: Column(
                children: [
                  _Metric(label: 'Total hours', value: '${pay['totalHours']}'),
                  const Divider(height: 1),
                  _Metric(label: 'Total pieces', value: '${pay['totalPieces']}'),
                  const Divider(height: 1),
                  _Metric(
                      label: 'Job cards counted',
                      value: '${pay['jobCardCount']}'),
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
    return ListTile(title: Text(label), trailing: Text(value, style: KTypography.titleSmall));
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
