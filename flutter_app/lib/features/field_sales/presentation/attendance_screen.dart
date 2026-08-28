import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/field_sales_repository.dart';

/// Manager view: team punch in/out for a date + pending leave approvals.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _attendance = [];
  List<Map<String, dynamic>> _leaves = [];
  bool _loading = true;

  String get _dateStr =>
      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      final results = await Future.wait([
        repo.teamAttendance(_dateStr),
        repo.pendingLeaves(),
      ]);
      if (mounted) {
        setState(() {
          _attendance = results[0];
          _leaves = results[1];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load attendance: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decideLeave(String id, bool approve) async {
    String? reason;
    if (!approve) {
      final ctl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Reject Leave Request', style: KTypography.titleLarge),
          content: TextField(
            controller: ctl,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              hintText: 'Enter reason...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            KButton.outlined(
              size: KButtonSize.small,
              label: 'Cancel',
              onPressed: () => Navigator.pop(ctx, false),
            ),
            KSpacing.hGapSm,
            KButton.danger(
              size: KButtonSize.small,
              label: 'Reject',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      );
      if (ok != true) return;
      reason = ctl.text.trim();
    }
    try {
      final repo = ref.read(fieldSalesRepositoryProvider);
      approve
          ? await repo.approveLeave(id)
          : await repo.rejectLeave(id, reason ?? '');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action failed: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    }
  }

  String _time(String? iso) {
    final t = iso != null ? DateTime.tryParse(iso)?.toLocal() : null;
    if (t == null) return '—';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance & Leave'),
          actions: [
            TextButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _date = picked);
                  _load();
                }
              },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                _dateStr,
                style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Attendance (${_attendance.length})'),
              Tab(text: 'Leave Requests (${_leaves.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: KLoading())
            : TabBarView(
                children: [
                  _attendance.isEmpty
                      ? const KEmptyState(
                          icon: Icons.person_off_outlined,
                          title: 'No punches on this date',
                          subtitle: 'Team members have not recorded any attendance logs yet.',
                        )
                      : ListView.separated(
                          padding: KSpacing.pagePadding,
                          itemCount: _attendance.length,
                          separatorBuilder: (_, __) => KSpacing.vGapSm,
                          itemBuilder: (context, index) {
                            final a = _attendance[index];
                            final mins = (a['workedMinutes'] as num?)?.toInt();
                            final isOnDuty = mins == null;

                            return KCard(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: cs.primaryContainer,
                                    child: Icon(Icons.person, color: cs.primary, size: 20),
                                  ),
                                  KSpacing.hGapMd,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a['userName']?.toString() ?? 'Salesperson',
                                          style: KTypography.titleMedium,
                                        ),
                                        KSpacing.vGapXxs,
                                        Row(
                                          children: [
                                            Text('In: ', style: KTypography.bodySmall),
                                            Text(
                                              _time(a['punchInAt']?.toString()),
                                              style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                            const Text('  •  Out: '),
                                            Text(
                                              _time(a['punchOutAt']?.toString()),
                                              style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isOnDuty)
                                    const KStatusChip(
                                      status: 'ACTIVE',
                                      label: 'On Duty',
                                    )
                                  else
                                    KStatusChip(
                                      status: 'COMPLETED',
                                      label: '${mins ~/ 60}h ${mins % 60}m',
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                  _leaves.isEmpty
                      ? const KEmptyState(
                          icon: Icons.beach_access_outlined,
                          title: 'No pending leave requests',
                          subtitle: 'All leave requests from the field team have been reviewed.',
                        )
                      : ListView.separated(
                          padding: KSpacing.pagePadding,
                          itemCount: _leaves.length,
                          separatorBuilder: (_, __) => KSpacing.vGapSm,
                          itemBuilder: (context, index) {
                            final l = _leaves[index];
                            final leaveType = l['leaveType']?.toString() ?? 'LEAVE';
                            final fromDate = l['fromDate']?.toString() ?? '';
                            final toDate = l['toDate']?.toString() ?? '';
                            final reason = l['reason']?.toString() ?? '';

                            return KCard(
                              titleWidget: Row(
                                children: [
                                  Text(
                                    '$fromDate → $toDate',
                                    style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  KSpacing.hGapSm,
                                  KStatusChip(status: leaveType),
                                ],
                              ),
                              action: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline, color: KColors.success),
                                    tooltip: 'Approve',
                                    onPressed: () => _decideLeave(l['id'].toString(), true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, color: KColors.error),
                                    tooltip: 'Reject',
                                    onPressed: () => _decideLeave(l['id'].toString(), false),
                                  ),
                                ],
                              ),
                              child: reason.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        reason,
                                        style: KTypography.bodyMedium.copyWith(color: cs.onSurfaceVariant),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }
}
