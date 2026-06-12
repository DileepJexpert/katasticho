import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
            SnackBar(content: Text('Failed to load attendance: $e')));
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
          title: const Text('Reject leave'),
          content: TextField(
              controller: ctl,
              decoration: const InputDecoration(labelText: 'Reason')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reject')),
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Action failed: $e')));
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
              icon: const Icon(Icons.calendar_today),
              label: Text(_dateStr),
            ),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
          bottom: TabBar(tabs: [
            Tab(text: 'Attendance (${_attendance.length})'),
            Tab(text: 'Leave Requests (${_leaves.length})'),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _attendance.isEmpty
                    ? const Center(child: Text('No punches on this date'))
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: _attendance.map((a) {
                          final mins = (a['workedMinutes'] as num?)?.toInt();
                          return Card(
                            child: ListTile(
                              leading:
                                  const CircleAvatar(child: Icon(Icons.person)),
                              title: Text(a['userName']?.toString() ?? ''),
                              subtitle: Text(
                                  'In ${_time(a['punchInAt']?.toString())}'
                                  ' • Out ${_time(a['punchOutAt']?.toString())}'),
                              trailing: Text(
                                mins != null
                                    ? '${mins ~/ 60}h ${mins % 60}m'
                                    : 'on duty',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                _leaves.isEmpty
                    ? const Center(child: Text('No pending leave requests'))
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: _leaves.map((l) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.beach_access_outlined),
                              title: Text(
                                  '${l['fromDate']} → ${l['toDate']} (${l['leaveType']})'),
                              subtitle: Text(l['reason']?.toString() ?? ''),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle_outline,
                                        color: Colors.green),
                                    onPressed: () => _decideLeave(
                                        l['id'].toString(), true),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined,
                                        color: Colors.red),
                                    onPressed: () => _decideLeave(
                                        l['id'].toString(), false),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ]),
      ),
    );
  }
}
