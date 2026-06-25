import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/field_sales_repository.dart';

/// Set and track sales targets per salesperson — revenue / volume / visits /
/// collections / new-customer goals over a period, with an incentive rate and
/// live achievement %. The backend target endpoints existed but had no
/// management UI (only the dashboard read achievement).
class SalesmanTargetsScreen extends ConsumerStatefulWidget {
  const SalesmanTargetsScreen({super.key});

  @override
  ConsumerState<SalesmanTargetsScreen> createState() =>
      _SalesmanTargetsScreenState();
}

class _SalesmanTargetsScreenState extends ConsumerState<SalesmanTargetsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _targets = [];

  static const _targetTypes = [
    'REVENUE',
    'VOLUME',
    'VISITS',
    'COLLECTIONS',
    'NEW_CUSTOMERS',
  ];
  static const _periodTypes = ['MONTHLY', 'QUARTERLY', 'YEARLY'];

  Dio get _dio => ref.read(apiClientProvider).dio;
  FieldSalesRepository get _repo => ref.read(fieldSalesRepositoryProvider);

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
      final usersResp = await _dio.get<Map<String, dynamic>>(ApiConfig.orgUsers);
      final usersData =
          (usersResp.data?['data'] as List?) ?? (usersResp.data as List? ?? []);
      final targets = await _repo.listTargets();
      if (!mounted) return;
      setState(() {
        _users = usersData
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
        _targets = targets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _userName(String? id) {
    if (id == null) return '—';
    final u = _users.firstWhere(
      (e) => e['id']?.toString() == id,
      orElse: () => <String, dynamic>{},
    );
    return (u['fullName'] ?? u['email'] ?? id).toString();
  }

  /// Revenue / collections render as ₹; counts render plain.
  String _fmtValue(String? type, num value) {
    if (type == 'REVENUE' || type == 'COLLECTIONS') {
      return CurrencyFormatter.formatIndian(value.toDouble());
    }
    return value.toDouble() == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salesman Targets'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _users.isEmpty ? null : _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New target'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? KErrorView(message: _error!, onRetry: _load)
              : _targets.isEmpty
                  ? KEmptyState(
                      icon: Icons.flag_outlined,
                      title: 'No targets set',
                      subtitle:
                          'Set monthly or quarterly goals for your field team '
                          'and track achievement + incentives here.',
                      actionLabel: 'New target',
                      onAction: _users.isEmpty ? null : _openCreateSheet,
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: KSpacing.pagePadding,
                        itemCount: _targets.length,
                        separatorBuilder: (_, __) => KSpacing.vGapSm,
                        itemBuilder: (_, i) => _targetCard(_targets[i]),
                      ),
                    ),
    );
  }

  Widget _targetCard(Map<String, dynamic> t) {
    final type = t['targetType']?.toString() ?? '';
    final target = (t['targetValue'] as num?) ?? 0;
    final achieved = (t['achievedValue'] as num?) ?? 0;
    final pct = ((t['achievementPct'] as num?) ?? 0).toDouble();
    final incentiveRate = ((t['incentiveRate'] as num?) ?? 0).toDouble();
    final incentiveAmount = ((t['incentiveAmount'] as num?) ?? 0).toDouble();
    final progress = (pct / 100).clamp(0.0, 1.0);
    final progressColor = pct >= 100
        ? KColors.success
        : pct >= 60
            ? KColors.warning
            : KColors.error;

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_userName(t['salespersonId']?.toString()),
                    style: KTypography.labelLarge),
              ),
              KStatusChip(status: type.replaceAll('_', ' ')),
            ],
          ),
          KSpacing.vGapXs,
          Text(
            '${t['periodType'] ?? 'MONTHLY'} · '
            '${_fmtDate(t['periodStart'])} – ${_fmtDate(t['periodEnd'])}',
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
          KSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Achieved ${_fmtValue(type, achieved)}',
                  style: KTypography.bodyMedium),
              Text('of ${_fmtValue(type, target)}',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary)),
            ],
          ),
          KSpacing.vGapXs,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: KColors.divider,
              color: progressColor,
            ),
          ),
          KSpacing.vGapXs,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${pct.toStringAsFixed(1)}%',
                  style: KTypography.labelMedium
                      .copyWith(color: progressColor)),
              if (incentiveRate > 0)
                Text(
                  'Incentive ${incentiveRate.toStringAsFixed(1)}% · '
                  '${CurrencyFormatter.formatIndian(incentiveAmount)}',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
            ],
          ),
          KSpacing.vGapSm,
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _openAchievementDialog(t),
              icon: const Icon(Icons.trending_up, size: 16),
              label: const Text('Record achievement'),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(Object? iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    return d == null ? '—' : DateFormatter.display(d);
  }

  // ── Record achievement ──────────────────────────────────────────────

  Future<void> _openAchievementDialog(Map<String, dynamic> t) async {
    final ctrl = TextEditingController(
        text: ((t['achievedValue'] as num?) ?? 0).toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record achievement — ${_userName(t['salespersonId']?.toString())}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            labelText: 'Achieved value',
            helperText: 'Target ${_fmtValue(t['targetType']?.toString(), (t['targetValue'] as num?) ?? 0)}',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final value = double.tryParse(ctrl.text.trim());
    if (value == null) return;
    try {
      await _repo.updateTargetAchievement(t['id'].toString(), value);
      await _load();
    } catch (e) {
      _toast('Could not update: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  // ── Create target ───────────────────────────────────────────────────

  Future<void> _openCreateSheet() async {
    final now = DateTime.now();
    String? salespersonId;
    String targetType = 'REVENUE';
    String periodType = 'MONTHLY';
    DateTime periodStart = DateTime(now.year, now.month, 1);
    DateTime periodEnd = DateTime(now.year, now.month + 1, 0); // last of month
    final targetCtrl = TextEditingController();
    final incentiveCtrl = TextEditingController();

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Future<void> pickDate(bool isStart) async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: isStart ? periodStart : periodEnd,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) {
                setSheet(() {
                  if (isStart) {
                    periodStart = picked;
                  } else {
                    periodEnd = picked;
                  }
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: KSpacing.lg,
                right: KSpacing.lg,
                top: KSpacing.lg,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + KSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('New target', style: KTypography.h3),
                    KSpacing.vGapMd,
                    DropdownButtonFormField<String>(
                      initialValue: salespersonId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Salesperson',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _users.map((u) {
                        final id = u['id']?.toString() ?? '';
                        final name = (u['fullName'] ?? u['email'] ?? id).toString();
                        final role = u['role']?.toString() ?? '';
                        return DropdownMenuItem(
                          value: id,
                          child: Text(role.isEmpty ? name : '$name ($role)',
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (v) => setSheet(() => salespersonId = v),
                    ),
                    KSpacing.vGapMd,
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: targetType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Target type',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _targetTypes
                                .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t.replaceAll('_', ' '))))
                                .toList(),
                            onChanged: (v) =>
                                setSheet(() => targetType = v ?? targetType),
                          ),
                        ),
                        KSpacing.hGapMd,
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: periodType,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Period',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: _periodTypes
                                .map((p) => DropdownMenuItem(
                                    value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) =>
                                setSheet(() => periodType = v ?? periodType),
                          ),
                        ),
                      ],
                    ),
                    KSpacing.vGapMd,
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickDate(true),
                            child: Text('From ${DateFormatter.short(periodStart)}'),
                          ),
                        ),
                        KSpacing.hGapMd,
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickDate(false),
                            child: Text('To ${DateFormatter.short(periodEnd)}'),
                          ),
                        ),
                      ],
                    ),
                    KSpacing.vGapMd,
                    TextField(
                      controller: targetCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: InputDecoration(
                        labelText: targetType == 'REVENUE' ||
                                targetType == 'COLLECTIONS'
                            ? 'Target amount (₹)'
                            : 'Target count',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    KSpacing.vGapMd,
                    TextField(
                      controller: incentiveCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Incentive rate % (optional)',
                        helperText: 'Incentive = achieved × rate ÷ 100',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    KSpacing.vGapLg,
                    KButton(
                      label: 'Create target',
                      icon: Icons.check,
                      onPressed: () async {
                        if (salespersonId == null) {
                          _toast('Pick a salesperson');
                          return;
                        }
                        final targetValue =
                            double.tryParse(targetCtrl.text.trim());
                        if (targetValue == null || targetValue <= 0) {
                          _toast('Enter a target value');
                          return;
                        }
                        if (periodEnd.isBefore(periodStart)) {
                          _toast('End date must be after start date');
                          return;
                        }
                        try {
                          await _repo.createTarget({
                            'salespersonId': salespersonId,
                            'periodType': periodType,
                            'periodStart': DateFormatter.api(periodStart),
                            'periodEnd': DateFormatter.api(periodEnd),
                            'targetType': targetType,
                            'targetValue': targetValue,
                            'incentiveRate':
                                double.tryParse(incentiveCtrl.text.trim()) ?? 0,
                          });
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          _toast(
                              'Could not create: ${e.toString().replaceAll('Exception: ', '')}');
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (created == true) await _load();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
