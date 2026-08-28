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
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';

/// HR Attendance management — Core HR module.
/// Tabs: Summary (monthly), Regularize (my requests), Approvals.
class HrAttendanceScreen extends ConsumerStatefulWidget {
  const HrAttendanceScreen({super.key});

  @override
  ConsumerState<HrAttendanceScreen> createState() => _HrAttendanceScreenState();
}

class _HrAttendanceScreenState extends ConsumerState<HrAttendanceScreen> {
  bool _loading = true;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _myRegs = [];
  List<Map<String, dynamic>> _pending = [];
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? [];

  String _ymd(DateTime d) => d.toIso8601String().split('T').first;

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([
        api.get(ApiConfig.hrAttendanceSummaryMe,
            queryParameters: {'month': _ymd(_month)}),
        api.get(ApiConfig.hrAttendanceRegsMine),
        api.get(ApiConfig.hrAttendanceRegsPending),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = (results[0].data['data'] as Map?)?.cast<String, dynamic>() ?? {};
        _myRegs = _list(results[1].data['data']);
        _pending = _list(results[2].data['data']);
      });
    } catch (e) {
      _toast('Failed to load attendance: ${ApiErrorParser.message(e)}', isError: true);
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

  Future<void> _requestRegularization() async {
    DateTime date = DateTime.now();
    TimeOfDay? inT;
    TimeOfDay? outT;
    final reason = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Request Attendance Regularization', style: KTypography.titleLarge),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KCard(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(date.year - 1),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setD(() => date = d);
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
                              Text(DateFormatter.display(date), style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_calendar_outlined, size: 16, color: KColors.textSecondary),
                      ],
                    ),
                  ),
                  KSpacing.vGapSm,
                  KCard(
                    onTap: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: const TimeOfDay(hour: 9, minute: 0));
                      if (t != null) setD(() => inT = t);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.login_rounded, size: 16, color: KColors.success),
                        KSpacing.hGapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Punch In Time', style: KTypography.labelSmall),
                              Text(inT?.format(ctx) ?? 'Select time', style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const Icon(Icons.access_time_rounded, size: 16, color: KColors.textSecondary),
                      ],
                    ),
                  ),
                  KSpacing.vGapSm,
                  KCard(
                    onTap: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: const TimeOfDay(hour: 18, minute: 0));
                      if (t != null) setD(() => outT = t);
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.logout_rounded, size: 16, color: KColors.error),
                        KSpacing.hGapMd,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Punch Out Time', style: KTypography.labelSmall),
                              Text(outT?.format(ctx) ?? 'Select time', style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const Icon(Icons.access_time_rounded, size: 16, color: KColors.textSecondary),
                      ],
                    ),
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    controller: reason,
                    label: 'Reason for Regularization',
                    hint: 'e.g. Onsite client visit, biometric reader failure',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            KButton.primary(
              label: 'Submit Request',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (ok != true || (inT == null && outT == null)) return;

    String? iso(TimeOfDay? t) => t == null
        ? null
        : DateTime(date.year, date.month, date.day, t.hour, t.minute)
            .toUtc()
            .toIso8601String();
    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrAttendanceRegs, data: {
        'workDate': _ymd(date),
        'punchIn': iso(inT),
        'punchOut': iso(outT),
        'reason': reason.text.trim(),
      });
      _toast('Attendance regularization request submitted');
      await _load();
    } catch (e) {
      _toast('Failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  Future<void> _decide(String id, bool approve) async {
    try {
      final api = ref.read(apiClientProvider);
      if (approve) {
        await api.post(ApiConfig.hrAttendanceRegApprove(id));
      } else {
        await api.post(ApiConfig.hrAttendanceRegReject(id), data: {'reason': ''});
      }
      _toast(approve ? 'Regularization approved' : 'Regularization rejected');
      await _load();
    } catch (e) {
      _toast('Action failed: ${ApiErrorParser.message(e)}', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pending.length;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance & Regularization'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Monthly Summary'),
              const Tab(text: 'My Regularizations'),
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
            ? const Center(child: KLoading(message: 'Loading attendance data...'))
            : TabBarView(children: [_summaryTab(), _regularizeTab(), _approvalsTab()]),
      ),
    );
  }

  Widget _summaryTab() {
    final m = _summary;
    Widget kv(String k, Object? v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(k, style: KTypography.bodyMedium)),
              Text(
                '${v ?? '0'}',
                style: KTypography.mono(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );

    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _month,
              firstDate: DateTime(_month.year - 1),
              lastDate: DateTime.now(),
            );
            if (d != null) {
              setState(() => _month = DateTime(d.year, d.month, 1));
              _load();
            }
          },
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 20, color: KColors.primary),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Selected Attendance Month', style: KTypography.labelSmall),
                    Text(
                      DateFormatter.monthYear(_month),
                      style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.edit_calendar_rounded, size: 18, color: KColors.textSecondary),
            ],
          ),
        ),
        KSpacing.vGapMd,
        KCard(
          title: 'Monthly Duty & Attendance Breakdown',
          child: Column(
            children: [
              kv('Working Days in Month', m['workingDays']),
              const Divider(height: 1),
              kv('Present Days', m['presentDays'], color: KColors.success),
              const Divider(height: 1),
              kv('Approved Leave Days', m['leaveDays'], color: KColors.warning),
              const Divider(height: 1),
              kv('Public Holidays', m['holidays']),
              const Divider(height: 1),
              kv('Weekends', m['weekends']),
              const Divider(height: 1),
              kv('Absent / LOP Days', m['absentDays'], color: KColors.error),
              const Divider(height: 1),
              kv('Total Duty Hours', m['totalHours']),
              const Divider(height: 1),
              kv('Payable Salary Days', m['payableDays'], color: KColors.primary),
            ],
          ),
        ),
      ],
    );
  }

  Widget _regularizeTab() {
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Regularization Requests', style: KTypography.h3),
            KButton.primary(
              label: 'Request Regularization',
              icon: Icons.edit_calendar_rounded,
              size: KButtonSize.small,
              onPressed: _requestRegularization,
            ),
          ],
        ),
        KSpacing.vGapMd,
        if (_myRegs.isEmpty)
          const KEmptyState(
            icon: Icons.access_time_outlined,
            title: 'No Regularization Requests',
            subtitle: 'You have not submitted any attendance regularization requests.',
          )
        else
          ..._myRegs.map((r) {
            final status = r['status']?.toString() ?? 'PENDING';
            return KCard(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              padding: const EdgeInsets.all(KSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Work Date: ${r['workDate'] ?? '--'}',
                          style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        if (r['reason'] != null && r['reason'].toString().isNotEmpty) ...[
                          KSpacing.vGapXs,
                          Text(
                            r['reason'].toString(),
                            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  KStatusChip(status: status),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _approvalsTab() {
    if (_pending.isEmpty) {
      return const KEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No Pending Approvals',
        subtitle: 'All regularization requests from your team have been reviewed.',
      );
    }
    return ListView.separated(
      padding: KSpacing.pagePadding,
      itemCount: _pending.length,
      separatorBuilder: (_, __) => KSpacing.vGapSm,
      itemBuilder: (_, i) {
        final r = _pending[i];
        final id = r['id'].toString();
        final employeeName = r['employeeName'] as String?;

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
                    Text(
                      'Work Date: ${r['workDate'] ?? '--'}',
                      style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    if (r['reason'] != null && r['reason'].toString().isNotEmpty) ...[
                      KSpacing.vGapXs,
                      Text(
                        r['reason'].toString(),
                        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                      ),
                    ],
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
