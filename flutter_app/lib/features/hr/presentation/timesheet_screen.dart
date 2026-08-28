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
import '../../../core/widgets/k_compact_row.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';

/// HR Timesheets — Core HR module.
/// Tabs: My Timesheet (log + week entries + submit), Approvals.
class TimesheetScreen extends ConsumerStatefulWidget {
  const TimesheetScreen({super.key});

  @override
  ConsumerState<TimesheetScreen> createState() => _TimesheetScreenState();
}

class _TimesheetScreenState extends ConsumerState<TimesheetScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _pending = [];

  // Log form
  DateTime _date = DateTime.now();
  final _project = TextEditingController();
  final _task = TextEditingController();
  final _hours = TextEditingController();
  bool _billable = false;

  late DateTime _weekFrom;
  late DateTime _weekTo;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekFrom = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    _weekTo = _weekFrom.add(const Duration(days: 6));
    _load();
  }

  @override
  void dispose() {
    _project.dispose();
    _task.dispose();
    _hours.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) => d.toIso8601String().split('T').first;

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? [];

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([
        api.get(ApiConfig.hrTimesheetMine,
            queryParameters: {'from': _ymd(_weekFrom), 'to': _ymd(_weekTo)}),
        api.get(ApiConfig.hrTimesheetPending),
      ]);
      if (!mounted) return;
      setState(() {
        _mine = _list(results[0].data['data']);
        _pending = _list(results[1].data['data']);
      });
    } catch (e) {
      _toast('Failed to load: ${ApiErrorParser.message(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: isError ? KColors.error : null,
      ),
    );
  }

  Future<void> _logTime() async {
    final h = double.tryParse(_hours.text.trim());
    if (h == null || h <= 0) {
      _toast('Enter valid work hours (e.g. 7.5)', isError: true);
      return;
    }
    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrTimesheets, data: {
        'workDate': _ymd(_date),
        'project': _project.text.trim(),
        'task': _task.text.trim(),
        'hours': h,
        'billable': _billable,
      });
      _project.clear();
      _task.clear();
      _hours.clear();
      setState(() => _billable = false);
      _toast('Time entry logged successfully');
      await _load();
    } catch (e) {
      _toast('Log failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  Future<void> _submitWeek() async {
    try {
      final res = await ref.read(apiClientProvider).post(
        ApiConfig.hrTimesheetSubmit,
        queryParameters: {'from': _ymd(_weekFrom), 'to': _ymd(_weekTo)},
      );
      final n = (res.data['data'] as Map?)?['submitted'] ?? 0;
      _toast('$n entries submitted for manager approval');
      await _load();
    } catch (e) {
      _toast('Submit failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  Future<void> _decide(String id, bool approve) async {
    try {
      final api = ref.read(apiClientProvider);
      if (approve) {
        await api.post(ApiConfig.hrTimesheetApprove(id));
      } else {
        await api.post(ApiConfig.hrTimesheetReject(id), data: {'reason': ''});
      }
      _toast(approve ? 'Timesheet entry approved' : 'Timesheet entry rejected');
      await _load();
    } catch (e) {
      _toast('Action failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  double get _weekHours => _mine.fold<double>(
      0, (sum, e) => sum + (double.tryParse('${e['hours']}') ?? 0));

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pending.length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Timesheets & Project Hours'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'My Timesheet Log'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Manager Approvals'),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: KColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: KLoading(message: 'Loading timesheets...'))
            : TabBarView(children: [_myTab(), _approvalsTab()]),
      ),
    );
  }

  Widget _myTab() {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          title: 'Log Work Hours',
          subtitle: 'Record daily activity hours against assigned projects and client tasks.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KCard(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(_date.year - 1),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: KColors.primary),
                    KSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Work Date', style: KTypography.labelSmall),
                          Text(DateFormatter.display(_date), style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_outlined, size: 16, color: KColors.textSecondary),
                  ],
                ),
              ),
              KSpacing.vGapSm,
              KCompactRow(children: [
                KTextField(controller: _project, label: 'Project Name *', hint: 'e.g. ERP Implementation'),
                KTextField(controller: _task, label: 'Task / Activity *', hint: 'e.g. Frontend Refactor'),
              ]),
              KSpacing.vGapSm,
              KCompactRow(children: [
                KTextField(
                  controller: _hours,
                  label: 'Hours Spent *',
                  hint: 'e.g. 7.5',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Client Billable'),
                  value: _billable,
                  activeThumbColor: KColors.primary,
                  onChanged: (v) => setState(() => _billable = v),
                ),
              ]),
              KSpacing.vGapMd,
              KButton.primary(
                onPressed: _logTime,
                icon: Icons.add_rounded,
                label: 'Log Time Entry',
              ),
            ],
          ),
        ),
        KSpacing.vGapLg,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text('Logged This Week: ', style: KTypography.h3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_weekHours.toStringAsFixed(1)} hrs',
                    style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
              ],
            ),
            if (_mine.isNotEmpty)
              KButton.outlined(
                size: KButtonSize.small,
                onPressed: _submitWeek,
                icon: Icons.send_rounded,
                label: 'Submit Week',
              ),
          ],
        ),
        KSpacing.vGapSm,
        if (_mine.isEmpty)
          const KEmptyState(
            icon: Icons.access_time_outlined,
            title: 'No Logged Hours This Week',
            subtitle: 'Log your daily work hours above to track time and project activities.',
          )
        else
          ..._mine.map((e) {
            final isBillable = e['billable'] == true;
            final status = e['status']?.toString() ?? 'DRAFT';
            return KCard(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              padding: const EdgeInsets.all(KSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${e['project'] ?? 'General'}',
                              style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                            ),
                            KSpacing.hGapSm,
                            Text(
                              '${e['hours']} hrs',
                              style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary),
                            ),
                          ],
                        ),
                        KSpacing.vGapXs,
                        Text(
                          '${e['workDate']} • ${e['task'] ?? 'General Task'}',
                          style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (isBillable) ...[
                    const KStatusChip(status: 'Billable'),
                    KSpacing.hGapSm,
                  ],
                  KStatusChip(status: status),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _approvalsTab() {
    final cs = Theme.of(context).colorScheme;

    if (_pending.isEmpty) {
      return const KEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'All Timesheets Reviewed',
        subtitle: 'All team timesheet submissions have been processed.',
      );
    }
    return ListView.separated(
      padding: KSpacing.pagePadding,
      itemCount: _pending.length,
      separatorBuilder: (_, __) => KSpacing.vGapSm,
      itemBuilder: (_, i) {
        final e = _pending[i];
        final id = e['id'].toString();
        final employeeName = e['employeeName'] as String?;

        return KCard(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (employeeName != null && employeeName.isNotEmpty) ...[
                      Text(
                        employeeName,
                        style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                      KSpacing.vGapXxs,
                    ],
                    Row(
                      children: [
                        Text('${e['project'] ?? 'General'}', style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w600)),
                        KSpacing.hGapSm,
                        Text('${e['hours']} hrs', style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700, color: cs.primary)),
                      ],
                    ),
                    KSpacing.vGapXs,
                    Text(
                      '${e['workDate']} • ${e['task'] ?? ''}',
                      style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              KButton.primary(
                label: 'Approve',
                size: KButtonSize.small,
                icon: Icons.check_rounded,
                onPressed: () => _decide(id, true),
              ),
              KSpacing.hGapSm,
              KButton.danger(
                label: 'Reject',
                size: KButtonSize.small,
                icon: Icons.close_rounded,
                onPressed: () => _decide(id, false),
              ),
            ],
          ),
        );
      },
    );
  }
}
