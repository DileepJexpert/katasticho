import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';

/// Tracker #80: actual costing from time tracking.
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
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _woCtl,
                    decoration: const InputDecoration(
                      labelText: 'Work order ID / Number',
                      helperText:
                          'Rolls up logged minutes × workstation rate + overhead rate × hours',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                KSpacing.hGapSm,
                KButton.primary(
                  onPressed: _loading ? null : _load,
                  isLoading: _loading,
                  icon: Icons.preview,
                  label: 'Preview',
                ),
              ],
            ),
            KSpacing.vGapMd,
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!, style: const TextStyle(color: KColors.error)),
              ),
            if (_data != null) Expanded(child: _buildResult(_data!)),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> d) {
    final hours = d['totalHours']?.toString() ?? '0';
    final jcCount = d['jobCardCount']?.toString() ?? '0';
    final trackedLabor = (d['trackedLaborCost'] as num?)?.toDouble();
    final trackedOverhead = (d['trackedOverheadCost'] as num?)?.toDouble();
    final plannedLabor = (d['plannedLaborCost'] as num?)?.toDouble();
    final plannedOverhead = (d['plannedOverheadCost'] as num?)?.toDouble();
    final rmCost = (d['rawMaterialCost'] as num?)?.toDouble();

    Widget moneyRow(String label, double? amount, {bool isWarning = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: KTypography.bodyMedium)),
              if (amount != null)
                KMoney(amount, size: KMoneySize.small)
              else
                Text('— (fallback)', style: KTypography.bodySmall.copyWith(color: KColors.warning)),
            ],
          ),
        );

    return ListView(
      children: [
        Row(
          children: [
            Text('Work order: ', style: KTypography.bodyMedium),
            Text(
              d['workOrderNumber']?.toString() ?? '—',
              style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        KSpacing.vGapMd,
        KCard(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Time Tracked', style: KTypography.titleSmall),
                const Divider(height: 16),
                Row(
                  children: [
                    Expanded(child: Text('Total hours logged', style: KTypography.bodyMedium)),
                    Text(hours, style: KTypography.labelLarge),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Expanded(child: Text('Job cards counted', style: KTypography.bodyMedium)),
                    Text(jcCount, style: KTypography.labelLarge),
                  ],
                ),
              ],
            ),
          ),
        ),
        KSpacing.vGapSm,
        KCard(
          child: Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cost — Tracked vs Planned', style: KTypography.titleSmall),
                const Divider(height: 16),
                moneyRow('Raw material (actual)', rmCost),
                moneyRow('Labour (tracked)', trackedLabor, isWarning: trackedLabor == null),
                moneyRow('Labour (planned)', plannedLabor),
                moneyRow('Overhead (tracked)', trackedOverhead, isWarning: trackedOverhead == null),
                moneyRow('Overhead (planned)', plannedOverhead),
              ],
            ),
          ),
        ),
        if (trackedLabor == null || trackedOverhead == null)
          Padding(
            padding: const EdgeInsets.only(top: KSpacing.sm),
            child: KCard(
              child: Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: KColors.warning),
                    KSpacing.hGapMd,
                    Expanded(
                      child: Text(
                        trackedLabor == null
                            ? 'No workstation hourly rates set on logged job cards — labour falls back to planned estimate.'
                            : 'Set manufacturing.overhead_rate_per_hour in org settings to absorb overhead from time tracking.',
                        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
