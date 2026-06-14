import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HR Attendance management — Core HR module 2 UI.
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
      _toast('Failed to load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
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
          title: const Text('Request regularization'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Date: ${_ymd(date)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(date.year - 1),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setD(() => date = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Punch in: ${inT?.format(ctx) ?? '—'}'),
                  trailing: const Icon(Icons.login),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: ctx, initialTime: const TimeOfDay(hour: 9, minute: 0));
                    if (t != null) setD(() => inT = t);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Punch out: ${outT?.format(ctx) ?? '—'}'),
                  trailing: const Icon(Icons.logout),
                  onTap: () async {
                    final t = await showTimePicker(
                        context: ctx, initialTime: const TimeOfDay(hour: 18, minute: 0));
                    if (t != null) setD(() => outT = t);
                  },
                ),
                TextField(
                  controller: reason,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
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
      _toast('Regularization requested');
      await _load();
    } catch (e) {
      _toast('Failed: $e');
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
      await _load();
    } catch (e) {
      _toast('Action failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          bottom: const TabBar(tabs: [
            Tab(text: 'Summary'),
            Tab(text: 'Regularize'),
            Tab(text: 'Approvals'),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_summaryTab(), _regularizeTab(), _approvalsTab()]),
      ),
    );
  }

  Widget _summaryTab() {
    final m = _summary;
    Widget kv(String k, Object? v) => ListTile(
          dense: true,
          title: Text(k),
          trailing: Text('${v ?? '—'}', style: const TextStyle(fontWeight: FontWeight.bold)),
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          title: Text('Month: ${_month.year}-${_month.month.toString().padLeft(2, '0')}'),
          trailing: const Icon(Icons.calendar_month),
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
        ),
        const Divider(),
        kv('Working days', m['workingDays']),
        kv('Present', m['presentDays']),
        kv('Leave days', m['leaveDays']),
        kv('Holidays', m['holidays']),
        kv('Weekends', m['weekends']),
        kv('Absent', m['absentDays']),
        kv('Total hours', m['totalHours']),
        kv('Payable days', m['payableDays']),
      ],
    );
  }

  Widget _regularizeTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _requestRegularization,
        icon: const Icon(Icons.edit_calendar),
        label: const Text('Regularize'),
      ),
      body: _myRegs.isEmpty
          ? const Center(child: Text('No regularization requests.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final r in _myRegs)
                  Card(
                    child: ListTile(
                      title: Text('${r['workDate']}  •  ${r['status']}'),
                      subtitle: Text(r['reason']?.toString() ?? ''),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _approvalsTab() {
    if (_pending.isEmpty) {
      return const Center(child: Text('No pending regularizations.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final r in _pending)
          Card(
            child: ListTile(
              title: Text('${r['workDate']}'),
              subtitle: Text(r['reason']?.toString() ?? ''),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _decide(r['id'].toString(), true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _decide(r['id'].toString(), false),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
