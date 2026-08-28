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

/// HR Leave Management (Time off) — Core HR module.
/// Tabs: Apply, My Leave (balances + requests), Approvals (admin).
class LeaveManagementScreen extends ConsumerStatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  ConsumerState<LeaveManagementScreen> createState() => _LeaveManagementScreenState();
}

class _LeaveManagementScreenState extends ConsumerState<LeaveManagementScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _types = [];
  List<Map<String, dynamic>> _balances = [];
  List<Map<String, dynamic>> _myLeaves = [];
  List<Map<String, dynamic>> _pending = [];

  // Apply form
  String? _typeId;
  DateTime? _from;
  DateTime? _to;
  final _reasonCtl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonCtl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _list(Object? data) =>
      (data as List?)?.cast<Map<String, dynamic>>() ?? [];

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([
        api.get(ApiConfig.hrLeaveTypes, queryParameters: {'activeOnly': true}),
        api.get(ApiConfig.hrLeaveBalances),
        api.get(ApiConfig.hrLeaveMine),
        api.get(ApiConfig.hrLeavePending),
      ]);
      if (!mounted) return;
      setState(() {
        _types = _list(results[0].data['data']);
        _balances = _list(results[1].data['data']);
        _myLeaves = _list(results[2].data['data']);
        _pending = _list(results[3].data['data']);
      });
    } catch (e) {
      _toast('Failed to load leave data: ${ApiErrorParser.message(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? KColors.error : null,
      ),
    );
  }

  String _fmt(DateTime? d) => d == null ? '' : d.toIso8601String().split('T').first;

  Future<void> _apply() async {
    if (_typeId == null || _from == null || _to == null) {
      _toast('Please pick a leave type and valid date range', isError: true);
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrLeaveApply, data: {
        'leaveTypeId': _typeId,
        'fromDate': _fmt(_from),
        'toDate': _fmt(_to),
        'reason': _reasonCtl.text.trim(),
      });
      _reasonCtl.clear();
      setState(() {
        _typeId = null;
        _from = null;
        _to = null;
      });
      _toast('Leave application submitted successfully');
      await _load();
    } catch (e) {
      _toast('Apply failed: ${ApiErrorParser.message(e)}', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _decide(String id, bool approve) async {
    String? reason;
    if (!approve) {
      final ctl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Reject Leave Application', style: KTypography.titleLarge),
          content: SizedBox(
            width: 400,
            child: KTextField(
              controller: ctl,
              label: 'Rejection Reason',
              hint: 'Provide reason for rejecting this leave request',
              maxLines: 2,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            KButton.danger(
              label: 'Reject Leave',
              icon: Icons.close_rounded,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (ok != true) return;
      reason = ctl.text.trim();
    }
    try {
      final api = ref.read(apiClientProvider);
      if (approve) {
        await api.post(ApiConfig.hrLeaveApprove(id));
      } else {
        await api.post(ApiConfig.hrLeaveReject(id), data: {'reason': reason});
      }
      _toast(approve ? 'Leave request approved' : 'Leave request rejected');
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
          title: const Text('Leave & Time Off'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Apply for Leave'),
              const Tab(text: 'My Entitlements & History'),
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
            ? const Center(child: KLoading(message: 'Loading leave data...'))
            : TabBarView(
                children: [_applyTab(), _myLeaveTab(), _approvalsTab()],
              ),
      ),
    );
  }

  Widget _applyTab() {
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        KCard(
          title: 'Apply for Time Off',
          subtitle: 'Submit a new leave request for supervisor approval.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _typeId,
                decoration: const InputDecoration(
                  labelText: 'Leave Category / Type *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final t in _types)
                    DropdownMenuItem(
                      value: t['id'].toString(),
                      child: Text(
                        '${t['name']}${t['paid'] == false ? ' (Unpaid LOP)' : ' (Paid Leave)'}',
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _typeId = v),
              ),
              KSpacing.vGapMd,
              KCompactRow(children: [
                _dateCard('From Date', _from, (d) => setState(() => _from = d)),
                _dateCard('To Date', _to, (d) => setState(() => _to = d)),
              ]),
              KSpacing.vGapMd,
              KTextField(
                controller: _reasonCtl,
                maxLines: 2,
                label: 'Reason for Leave (Optional)',
                hint: 'e.g. Family function, personal travel, medical appointment',
              ),
              KSpacing.vGapLg,
              KButton.primary(
                onPressed: _submitting ? null : _apply,
                isLoading: _submitting,
                icon: Icons.send_rounded,
                label: 'Submit Leave Application',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dateCard(String label, DateTime? value, ValueChanged<DateTime> onPick) {
    final cs = Theme.of(context).colorScheme;

    return KCard(
      onTap: () async {
        final now = DateTime.now();
        final d = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 2),
        );
        if (d != null) onPick(d);
      },
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded, size: 16, color: cs.primary),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  value == null ? 'Select Date' : DateFormatter.display(value),
                  style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Icon(Icons.edit_calendar_rounded, size: 16, color: cs.onSurfaceVariant),
        ],
      ),
    );
  }

  Widget _myLeaveTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: KSpacing.pagePadding,
        children: [
          Text('Leave Balances & Entitlements', style: KTypography.h3),
          KSpacing.vGapSm,
          if (_balances.isEmpty)
            const KEmptyState(
              icon: Icons.beach_access_outlined,
              title: 'No Leave Entitlements',
              subtitle: 'No leave balances assigned to your employee record.',
            )
          else
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                for (final b in _balances)
                  SizedBox(
                    width: 175,
                    child: KCard(
                      padding: const EdgeInsets.all(KSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${b['leaveType']}',
                            style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                          KSpacing.vGapSm,
                          Row(
                            children: [
                              Text('Available: ', style: KTypography.bodySmall),
                              Text(
                                '${b['available'] ?? 0} d',
                                style: KTypography.mono(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: KColors.success,
                                ),
                              ),
                            ],
                          ),
                          KSpacing.vGapXs,
                          Text(
                            'Used: ${b['used'] ?? 0} / ${b['entitled'] ?? 0} days',
                            style: KTypography.mono(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          KSpacing.vGapLg,
          Text('My Leave Application History', style: KTypography.h3),
          KSpacing.vGapSm,
          if (_myLeaves.isEmpty)
            const KEmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No Leave History',
              subtitle: 'You have not submitted any leave applications yet.',
            )
          else
            for (final l in _myLeaves) _leaveTile(l, showActions: false),
        ],
      ),
    );
  }

  Widget _approvalsTab() {
    if (_pending.isEmpty) {
      return const KEmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'All Caught Up!',
        subtitle: 'Zero pending leave requests waiting for your approval.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: _pending.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (_, i) => _leaveTile(_pending[i], showActions: true),
      ),
    );
  }

  Widget _leaveTile(Map<String, dynamic> l, {required bool showActions}) {
    final status = l['status']?.toString() ?? 'PENDING';
    final id = l['id'].toString();
    final reason = l['reason'] as String?;
    final employeeName = l['employeeName'] as String?;
    final cs = Theme.of(context).colorScheme;

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
                    if (employeeName != null && employeeName.isNotEmpty) ...[
                      Text(
                        employeeName,
                        style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '${l['leaveType'] ?? 'Leave'}',
                      style: KTypography.titleSmall.copyWith(
                        fontWeight: employeeName == null ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    KSpacing.hGapSm,
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${l['workingDays'] ?? '?'} day(s)',
                        style: KTypography.mono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  '${l['fromDate']} ➔ ${l['toDate']}',
                  style: KTypography.mono(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text(
                    reason,
                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (showActions) ...[
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
          ] else ...[
            KStatusChip(status: status),
          ],
        ],
      ),
    );
  }
}
