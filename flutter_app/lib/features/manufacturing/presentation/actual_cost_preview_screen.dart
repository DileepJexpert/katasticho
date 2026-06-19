import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';

/// Tracker #80: actual costing from time tracking.
///
/// Lets the production manager preview a WO's actual labour + overhead
/// (computed from job-card logged minutes × workstation hourly rate +
/// the org-level overhead rate per hour) BEFORE the WO closes. The same
/// roll-up runs automatically into `ProductionCostSummary` on completion,
/// but planners want to eyeball it earlier so they can correct missing
/// workstation rates while they still have time.
class ActualCostPreviewScreen extends ConsumerStatefulWidget {
  const ActualCostPreviewScreen({super.key});

  @override
  ConsumerState<ActualCostPreviewScreen> createState() =>
      _ActualCostPreviewScreenState();
}

class _ActualCostPreviewScreenState
    extends ConsumerState<ActualCostPreviewScreen> {
  final _woCtl = TextEditingController();
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _woCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _woCtl.text.trim();
    if (id.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    try {
      final res = await ref.read(apiClientProvider).get(
            ApiConfig.manufacturingActualCostPreview(id),
          );
      setState(() {
        _data = (res.data['data'] as Map?)?.cast<String, dynamic>();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = ApiErrorParser.message(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Actual Cost Preview')),
      body: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _woCtl,
                    decoration: const InputDecoration(
                      labelText: 'Work order id',
                      helperText:
                          'Rolls up logged minutes × workstation rate + overhead rate × hours',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                FilledButton(onPressed: _load, child: const Text('Preview')),
              ],
            ),
            const SizedBox(height: KSpacing.md),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (_data != null) Expanded(child: _buildResult(_data!)),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> d) {
    final hours = d['totalHours']?.toString() ?? '0';
    final jcCount = d['jobCardCount']?.toString() ?? '0';
    final trackedLabor = d['trackedLaborCost'];
    final trackedOverhead = d['trackedOverheadCost'];
    final plannedLabor = d['plannedLaborCost'];
    final plannedOverhead = d['plannedOverheadCost'];
    final rmCost = d['rawMaterialCost'];

    Widget kv(String k, Object? v, {Color? c}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(k)),
              Text('${v ?? '—'}',
                  style: KTypography.bodyMedium.copyWith(
                      color: c, fontWeight: FontWeight.w600)),
            ],
          ),
        );

    return ListView(
      children: [
        Text('Work order: ${d['workOrderNumber'] ?? '?'}',
            style: KTypography.titleMedium),
        const SizedBox(height: KSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Time tracked', style: KTypography.titleSmall),
                kv('Total hours logged', hours),
                kv('Job cards counted', jcCount),
              ],
            ),
          ),
        ),
        const SizedBox(height: KSpacing.sm),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cost — tracked vs planned',
                    style: KTypography.titleSmall),
                kv('Raw material (actual)', rmCost),
                kv('Labour (tracked)', trackedLabor,
                    c: trackedLabor == null ? Colors.orange : null),
                kv('Labour (planned)', plannedLabor),
                kv('Overhead (tracked)', trackedOverhead,
                    c: trackedOverhead == null ? Colors.orange : null),
                kv('Overhead (planned)', plannedOverhead),
              ],
            ),
          ),
        ),
        if (trackedLabor == null || trackedOverhead == null)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.sm),
            child: Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Text(
                    trackedLabor == null
                        ? 'No workstation hourly rates set on any logged job card '
                            '— labour falls back to the planned estimate.'
                        : 'Set manufacturing.overhead_rate_per_hour in org settings '
                            'to absorb overhead from time tracking.',
                    style: const TextStyle(color: Colors.brown)),
              ),
            ),
          ),
      ],
    );
  }
}
