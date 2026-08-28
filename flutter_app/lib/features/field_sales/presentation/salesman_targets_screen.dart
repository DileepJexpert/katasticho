import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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
        title: const Text('Sales Targets & Quotas'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: _users.isEmpty ? null : _openCreateSheet,
        icon: const Icon(Icons.add),
        label: const Text('New Target'),
      ),
      body: _loading
          ? const Center(child: KLoading())
          : _error != null
              ? KErrorView(message: _error!, onRetry: _load)
              : _targets.isEmpty
                  ? KEmptyState(
                      icon: Icons.flag_outlined,
                      title: 'No sales targets configured',
                      subtitle:
                          'Set monthly, quarterly or yearly revenue and visit goals for field representatives to track quotas and incentives.',
                      actionLabel: 'New Target',
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
      statusAccent: progressColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_userName(t['salespersonId']?.toString()),
                    style: KTypography.titleMedium),
              ),
              KStatusChip(status: type.replaceAll('_', ' ')),
            ],
          ),
          KSpacing.vGapXs,
          Text(
            '${t['periodType'] ?? 'MONTHLY'} · '
            '${_fmtDate(t['periodStart'])} – ${_fmtDate(t['periodEnd'])}',
            style: KTypography.mono(fontSize: 12, color: KColors.textSecondary),
          ),
          KSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Achieved: ', style: KTypography.bodyMedium),
                  if (type == 'REVENUE' || type == 'COLLECTIONS')
                    KMoney(achieved.toDouble(), size: KMoneySize.small, style: const TextStyle(fontWeight: FontWeight.w700))
                  else
                    Text(_fmtValue(type, achieved), style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
              Row(
                children: [
                  Text('of Target ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                  if (type == 'REVENUE' || type == 'COLLECTIONS')
                    KMoney(target.toDouble(), size: KMoneySize.small)
                  else
                    Text(_fmtValue(type, target), style: KTypography.mono(fontSize: 12, color: KColors.textSecondary)),
                ],
              ),
            ],
          ),
          KSpacing.vGapXs,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: progressColor.withValues(alpha: 0.15),
              color: progressColor,
            ),
          ),
          KSpacing.vGapXs,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${pct.toStringAsFixed(1)}%',
                  style: KTypography.mono(
                    fontSize: 13,
                    color: progressColor,
                    fontWeight: FontWeight.w700,
                  )),
              if (incentiveRate > 0)
                Row(
                  children: [
                    Text(
                      'Incentive (${incentiveRate.toStringAsFixed(1)}%): ',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                    KMoney(
                      incentiveAmount,
                      size: KMoneySize.small,
                      style: const TextStyle(color: KColors.success, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
          KSpacing.vGapSm,
          Align(
            alignment: Alignment.centerRight,
            child: KButton.outlined(
              label: 'Update Achievement',
              icon: Icons.trending_up,
              size: KButtonSize.small,
              onPressed: () => _openAchievementDialog(t),
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
        title: Text('Update Achievement — ${_userName(t['salespersonId']?.toString())}'),
        content: SizedBox(
          width: 360,
          child: KTextField.amount(
            controller: ctrl,
            label: 'Achieved value',
            hint: 'Target is ${_fmtValue(t['targetType']?.toString(), (t['targetValue'] as num?) ?? 0)}',
          ),
        ),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx, false),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            label: 'Save Achievement',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final value = double.tryParse(ctrl.text.trim());
    if (value == null) return;
    try {
      await _repo.updateTargetAchievement(t['id'].toString(), value);
      _toast('Achievement updated');
      await _load();
    } catch (e) {
      _toast('Could not update: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
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
                    Text('New Target / Quota', style: KTypography.titleLarge),
                    KSpacing.vGapMd,
                    DropdownButtonFormField<String>(
                      initialValue: salespersonId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Salesperson *',
                        border: OutlineInputBorder(),
                      ),
                      items: _users.map((u) {
                        final id = (u['userId'] ?? u['id'])?.toString() ?? '';
                        final name = (u['fullName'] ?? u['displayName'] ?? u['email'] ?? id).toString();
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
                              labelText: 'Target Metric Type',
                              border: OutlineInputBorder(),
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
                              labelText: 'Frequency Period',
                              border: OutlineInputBorder(),
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
                            child: Text('From: ${DateFormatter.short(periodStart)}'),
                          ),
                        ),
                        KSpacing.hGapMd,
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => pickDate(false),
                            child: Text('To: ${DateFormatter.short(periodEnd)}'),
                          ),
                        ),
                      ],
                    ),
                    KSpacing.vGapMd,
                    KTextField.amount(
                      controller: targetCtrl,
                      label: targetType == 'REVENUE' ||
                              targetType == 'COLLECTIONS'
                          ? 'Target Amount'
                          : 'Target Count',
                    ),
                    KSpacing.vGapSm,
                    KTextField(
                      controller: incentiveCtrl,
                      label: 'Incentive Rate % (Optional)',
                      hint: 'e.g. 2.5',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    KSpacing.vGapLg,
                    KButton.primary(
                      label: 'Create Target',
                      icon: Icons.check,
                      onPressed: () async {
                        if (salespersonId == null) {
                          _toast('Pick a salesperson', isError: true);
                          return;
                        }
                        final targetValue =
                            double.tryParse(targetCtrl.text.trim());
                        if (targetValue == null || targetValue <= 0) {
                          _toast('Enter a valid positive target value', isError: true);
                          return;
                        }
                        if (periodEnd.isBefore(periodStart)) {
                          _toast('End date must be after start date', isError: true);
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
                              'Could not create: ${e.toString().replaceAll('Exception: ', '')}', isError: true);
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

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? KColors.error : KColors.success,
      ),
    );
  }
}
