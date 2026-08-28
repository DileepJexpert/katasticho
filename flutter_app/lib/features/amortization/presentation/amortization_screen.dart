import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';

class AmortizationScreen extends ConsumerStatefulWidget {
  const AmortizationScreen({super.key});

  @override
  ConsumerState<AmortizationScreen> createState() => _AmortizationScreenState();
}

class _AmortizationScreenState extends ConsumerState<AmortizationScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _schedules = [];
  late DateTime _period;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _period = DateTime(now.year, now.month);
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConfig.amortization);
      final data = res.data['data'];
      _schedules = (data is List ? data : const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } catch (e) {
      _error = _dioMessage(e, 'Failed to load amortization schedules');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _period,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 5, 12),
      helpText: 'Select recognition month',
    );
    if (picked != null && mounted) {
      setState(() => _period = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _runAmortization() async {
    setState(() => _running = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.post(
        ApiConfig.amortizationRun,
        queryParameters: {'year': _period.year, 'month': _period.month},
      );
      final data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final count = data['scheduleCount'] ?? 0;
      final total = _toDouble(data['totalRecognized']);
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Recognized $count schedule(s): ${CurrencyFormatter.formatIndian(total)}'),
      ));
      await _fetch();
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(_dioMessage(e, 'Could not run amortization'))));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _openSchedule(String id) async {
    Map<String, dynamic>? detail;
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.get(ApiConfig.amortizationById(id));
      detail = (res.data['data'] as Map?)?.cast<String, dynamic>();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_dioMessage(e, 'Could not load schedule'))));
      return;
    }
    if (detail == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScheduleDetailSheet(
        detail: detail!,
        onChanged: _fetch,
      ),
    );
  }

  Future<void> _addSchedule() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ScheduleForm(),
    );
    if (created == true) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Amortization')),
      body: Column(
        children: [
          _toolbar(),
          Expanded(child: _body()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSchedule,
        icon: const Icon(Icons.add),
        label: const Text('New schedule'),
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: KSpacing.pagePadding,
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _pickPeriod,
            icon: const Icon(Icons.calendar_month, size: 18),
            label: Text('${_monthName(_period.month)} ${_period.year}'),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: KButton(
              label: _running ? 'Running…' : 'Run amortization',
              icon: Icons.play_arrow,
              isLoading: _running,
              onPressed: _runAmortization,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return KErrorView(message: _error!, onRetry: _fetch);
    }
    if (_schedules.isEmpty) {
      return const KEmptyState(
        icon: Icons.event_repeat_outlined,
        title: 'No amortization schedules',
        subtitle:
            'Set up a prepaid, deferred income, or accrual schedule to spread it over time.',
      );
    }
    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: _schedules.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (context, i) {
          final s = _schedules[i];
          return _ScheduleCard(
            schedule: s,
            onTap: () {
              final id = s['id']?.toString();
              if (id != null) _openSchedule(id);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────── helpers ────────────────────────────────────────

String _dioMessage(Object e, String fallback) {
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map && body['message'] != null) return body['message'].toString();
  }
  return fallback;
}

double _toDouble(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _toInt(Object? v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

String _monthName(int m) {
  const names = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return (m >= 1 && m <= 12) ? names[m] : '$m';
}

Color _typeColor(String type) {
  switch (type) {
    case 'PREPAID':
      return KColors.info;
    case 'DEFERRED_INCOME':
      return Colors.teal;
    case 'ACCRUAL':
      return KColors.warning;
    default:
      return KColors.textSecondary;
  }
}

String _typeLabel(String type) {
  switch (type) {
    case 'PREPAID':
      return 'Prepaid';
    case 'DEFERRED_INCOME':
      return 'Deferred income';
    case 'ACCRUAL':
      return 'Accrual';
    default:
      return type;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'ACTIVE':
      return KColors.success;
    case 'COMPLETED':
      return KColors.textSecondary;
    case 'CANCELLED':
      return KColors.error;
    default:
      return KColors.textSecondary;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'ACTIVE':
      return 'Active';
    case 'COMPLETED':
      return 'Completed';
    case 'CANCELLED':
      return 'Cancelled';
    default:
      return status;
  }
}

Widget _chip(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(label, style: KTypography.labelSmall.copyWith(color: color)),
  );
}

// ─────────────────────────── schedule card ──────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final VoidCallback onTap;

  const _ScheduleCard({required this.schedule, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final description = schedule['description']?.toString() ?? '--';
    final reference = schedule['reference']?.toString();
    final type = schedule['scheduleType']?.toString() ?? '';
    final status = schedule['status']?.toString() ?? 'ACTIVE';
    final total = _toDouble(schedule['totalAmount']);
    final recognized = _toDouble(schedule['recognizedAmount']);
    final periods = _toInt(schedule['numberOfPeriods']);
    final startYear = _toInt(schedule['startYear']);
    final startMonth = _toInt(schedule['startMonth']);
    final debit = schedule['debitAccountCode']?.toString() ?? '--';
    final credit = schedule['creditAccountCode']?.toString() ?? '--';

    final progress =
        total > 0 ? (recognized / total).clamp(0.0, 1.0) : 0.0;

    return KCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(description, style: KTypography.labelLarge),
                    if (reference != null && reference.isNotEmpty) ...[
                      KSpacing.vGapXs,
                      Text(
                        reference,
                        style: KTypography.mono(
                            fontSize: 12, color: KColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              KSpacing.hGapSm,
              KMoney(
                total,
                size: KMoneySize.medium,
                style: const TextStyle(color: KColors.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              _chip(_typeLabel(type), _typeColor(type)),
              KSpacing.hGapSm,
              _chip(_statusLabel(status), _statusColor(status)),
            ],
          ),
          KSpacing.vGapSm,
          Row(
            children: [
              Text('Recognized ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
              KMoney(recognized, size: KMoneySize.small),
              Text(' of ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
              KMoney(total, size: KMoneySize.small),
            ],
          ),
          KSpacing.vGapXs,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: KColors.divider,
            ),
          ),
          KSpacing.vGapSm,
          Text.rich(
            TextSpan(
              style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
              children: [
                const TextSpan(text: 'DR '),
                TextSpan(text: debit, style: KTypography.mono(fontSize: 11)),
                const TextSpan(text: ' / CR '),
                TextSpan(text: credit, style: KTypography.mono(fontSize: 11)),
                TextSpan(text: ' · $periods periods from $startMonth/$startYear'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── schedule detail bottom sheet ───────────────────────

class _ScheduleDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> detail;
  final VoidCallback onChanged;

  const _ScheduleDetailSheet({required this.detail, required this.onChanged});

  @override
  ConsumerState<_ScheduleDetailSheet> createState() =>
      _ScheduleDetailSheetState();
}

class _ScheduleDetailSheetState extends ConsumerState<_ScheduleDetailSheet> {
  @override
  Widget build(BuildContext context) {
    final schedule =
        (widget.detail['schedule'] as Map?)?.cast<String, dynamic>() ?? {};
    final periodAmount = _toDouble(widget.detail['periodAmount']);
    final remaining = _toDouble(widget.detail['remaining']);
    final entries = (widget.detail['entries'] as List?) ?? const [];
    final status = schedule['status']?.toString() ?? 'ACTIVE';
    final type = schedule['scheduleType']?.toString() ?? '';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: KSpacing.pagePadding,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(schedule['description']?.toString() ?? '--',
                      style: KTypography.h3),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            KSpacing.vGapSm,
            Row(
              children: [
                _chip(_typeLabel(type), _typeColor(type)),
                KSpacing.hGapSm,
                _chip(_statusLabel(status), _statusColor(status)),
              ],
            ),
            KSpacing.vGapSm,
            KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _kv('Reference', schedule['reference']?.toString() ?? '--',
                      valueWidget: Text(
                        schedule['reference']?.toString() ?? '--',
                        style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
                      )),
                  _kv('Total amount', '',
                      valueWidget: KMoney(_toDouble(schedule['totalAmount']), size: KMoneySize.small)),
                  _kv('Per-period amount', '',
                      valueWidget: KMoney(periodAmount, size: KMoneySize.small)),
                  _kv('Recognized', '',
                      valueWidget: KMoney(_toDouble(schedule['recognizedAmount']), size: KMoneySize.small)),
                  _kv('Remaining', '',
                      valueWidget: KMoney(remaining,
                          size: KMoneySize.medium,
                          style: const TextStyle(color: KColors.primary, fontWeight: FontWeight.w700)),
                      highlight: true),
                  _kv('Periods',
                      '${_toInt(schedule['numberOfPeriods'])}'),
                  _kv('Starts',
                      '${_toInt(schedule['startMonth'])}/${_toInt(schedule['startYear'])}'),
                  _kv('Posting', '',
                      valueWidget: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'DR '),
                            TextSpan(text: '${schedule['debitAccountCode'] ?? '--'}', style: KTypography.mono(fontSize: 12)),
                            const TextSpan(text: ' / CR '),
                            TextSpan(text: '${schedule['creditAccountCode'] ?? '--'}', style: KTypography.mono(fontSize: 12)),
                          ],
                          style: KTypography.bodyMedium,
                        ),
                      )),
                ],
              ),
            ),
            if (status == 'ACTIVE') ...[
              KSpacing.vGapSm,
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: KColors.error),
                  onPressed: () => _cancelSchedule(schedule),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel schedule'),
                ),
              ),
            ],
            KSpacing.vGapLg,
            Text('Recognition history', style: KTypography.h3),
            KSpacing.vGapSm,
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No entries posted yet',
                    style: KTypography.bodyMedium
                        .copyWith(color: KColors.textHint)),
              )
            else
              ...entries.map((raw) {
                final e = Map<String, dynamic>.from(raw as Map);
                final year = _toInt(e['periodYear']);
                final month = _toInt(e['periodMonth']);
                final posted = e['journalEntryId'] != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: KSpacing.sm),
                  child: KCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_monthName(month)} $year',
                                  style: KTypography.labelLarge),
                              KSpacing.vGapXs,
                              Text(
                                posted ? 'Posted' : 'Pending',
                                style: KTypography.bodySmall.copyWith(
                                    color: posted
                                        ? KColors.success
                                        : KColors.textHint),
                              ),
                            ],
                          ),
                        ),
                        KMoney(
                          _toDouble(e['amount']),
                          size: KMoneySize.medium,
                          style: const TextStyle(color: KColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _kv(String label, String value, {bool highlight = false, Widget? valueWidget}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: KTypography.bodyMedium
                  .copyWith(color: KColors.textSecondary)),
          Flexible(
            child: valueWidget ??
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: highlight
                      ? KTypography.labelLarge.copyWith(color: KColors.primary)
                      : KTypography.bodyMedium,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSchedule(Map<String, dynamic> schedule) async {
    final id = schedule['id']?.toString();
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel schedule'),
        content: const Text(
            'No further amounts will be recognized. Already-posted entries are unaffected. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: KColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel schedule')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.amortizationCancel(id));
      messenger
          .showSnackBar(const SnackBar(content: Text('Schedule cancelled')));
      if (navigator.canPop()) navigator.pop();
      widget.onChanged();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(_dioMessage(e, 'Could not cancel schedule'))));
    }
  }
}

// ─────────────────────────── new-schedule form ──────────────────────────────

class _ScheduleForm extends ConsumerStatefulWidget {
  const _ScheduleForm();

  @override
  ConsumerState<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends ConsumerState<_ScheduleForm> {
  final _descriptionCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _totalAmountCtrl = TextEditingController();
  final _startYearCtrl =
      TextEditingController(text: '${DateTime.now().year}');
  final _startMonthCtrl =
      TextEditingController(text: '${DateTime.now().month}');
  final _numberOfPeriodsCtrl = TextEditingController();
  final _debitCtrl = TextEditingController();
  final _creditCtrl = TextEditingController();

  String _scheduleType = 'PREPAID';
  bool _saving = false;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _referenceCtrl.dispose();
    _totalAmountCtrl.dispose();
    _startYearCtrl.dispose();
    _startMonthCtrl.dispose();
    _numberOfPeriodsCtrl.dispose();
    _debitCtrl.dispose();
    _creditCtrl.dispose();
    super.dispose();
  }

  String _accountsHint(String type) {
    switch (type) {
      case 'PREPAID':
        return 'DR expense account / CR the prepaid-asset account';
      case 'DEFERRED_INCOME':
        return 'DR the deferred-income (liability) account / CR revenue account';
      case 'ACCRUAL':
        return 'DR expense account / CR the accrued-liability account';
      default:
        return '';
    }
  }

  Future<void> _save() async {
    if (_descriptionCtrl.text.trim().isEmpty ||
        _totalAmountCtrl.text.trim().isEmpty ||
        _numberOfPeriodsCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Description, total amount and number of periods are required')));
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'scheduleType': _scheduleType,
        'description': _descriptionCtrl.text.trim(),
        'reference': _referenceCtrl.text.trim(),
        'totalAmount': double.tryParse(_totalAmountCtrl.text.trim()) ?? 0,
        'startYear': int.tryParse(_startYearCtrl.text.trim()) ?? 0,
        'startMonth': int.tryParse(_startMonthCtrl.text.trim()) ?? 0,
        'numberOfPeriods':
            int.tryParse(_numberOfPeriodsCtrl.text.trim()) ?? 0,
        'debitAccountCode': _debitCtrl.text.trim(),
        'creditAccountCode': _creditCtrl.text.trim(),
      };
      await api.post(ApiConfig.amortization, data: body);
      messenger.showSnackBar(
          const SnackBar(content: Text('Amortization schedule created')));
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(_dioMessage(e, 'Could not create schedule'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: KSpacing.pagePadding,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text('New schedule', style: KTypography.h3)),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              KSpacing.vGapMd,
              DropdownButtonFormField<String>(
                initialValue: _scheduleType,
                decoration: const InputDecoration(
                  labelText: 'Schedule type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'PREPAID', child: Text('Prepaid')),
                  DropdownMenuItem(
                      value: 'DEFERRED_INCOME',
                      child: Text('Deferred income')),
                  DropdownMenuItem(value: 'ACCRUAL', child: Text('Accrual')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _scheduleType = v);
                },
              ),
              KSpacing.vGapXs,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  _accountsHint(_scheduleType),
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
              ),
              KSpacing.vGapMd,
              _field(_descriptionCtrl, 'Description'),
              KSpacing.vGapMd,
              _field(_referenceCtrl, 'Reference'),
              KSpacing.vGapMd,
              _field(_totalAmountCtrl, 'Total amount', number: true),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                      child: _field(_startYearCtrl, 'Start year',
                          number: true)),
                  KSpacing.hGapMd,
                  Expanded(
                      child: _field(_startMonthCtrl, 'Start month (1-12)',
                          number: true)),
                ],
              ),
              KSpacing.vGapMd,
              _field(_numberOfPeriodsCtrl, 'Number of periods', number: true),
              KSpacing.vGapMd,
              _field(_debitCtrl, 'Debit account code'),
              KSpacing.vGapMd,
              _field(_creditCtrl, 'Credit account code'),
              KSpacing.vGapLg,
              KButton(
                label: _saving ? 'Saving…' : 'Create schedule',
                icon: Icons.save,
                isLoading: _saving,
                onPressed: _save,
              ),
              KSpacing.vGapMd,
            ],
          );
        },
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {bool number = false}) {
    return TextField(
      controller: controller,
      keyboardType:
          number ? const TextInputType.numberWithOptions(decimal: true) : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
