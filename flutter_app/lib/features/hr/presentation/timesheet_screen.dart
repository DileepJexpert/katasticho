import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HR Timesheets — Core HR module 4 UI.
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
      _toast('Failed to load: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _logTime() async {
    final h = double.tryParse(_hours.text.trim());
    if (h == null || h <= 0) {
      _toast('Enter valid hours');
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
      _toast('Time logged');
      await _load();
    } catch (e) {
      _toast('Log failed: $e');
    }
  }

  Future<void> _submitWeek() async {
    try {
      final res = await ref.read(apiClientProvider).post(
        ApiConfig.hrTimesheetSubmit,
        queryParameters: {'from': _ymd(_weekFrom), 'to': _ymd(_weekTo)},
      );
      final n = (res.data['data'] as Map?)?['submitted'] ?? 0;
      _toast('$n entries submitted');
      await _load();
    } catch (e) {
      _toast('Submit failed: $e');
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
      await _load();
    } catch (e) {
      _toast('Action failed: $e');
    }
  }

  double get _weekHours => _mine.fold<double>(
      0, (sum, e) => sum + (double.tryParse('${e['hours']}') ?? 0));

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Timesheets'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          bottom: const TabBar(tabs: [
            Tab(text: 'My Timesheet'),
            Tab(text: 'Approvals'),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_myTab(), _approvalsTab()]),
      ),
    );
  }

  Widget _myTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Log time', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Date: ${_ymd(_date)}'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime(_date.year - 1),
              lastDate: DateTime.now().add(const Duration(days: 1)),
            );
            if (d != null) setState(() => _date = d);
          },
        ),
        TextField(controller: _project, decoration: const InputDecoration(labelText: 'Project')),
        TextField(controller: _task, decoration: const InputDecoration(labelText: 'Task')),
        TextField(
          controller: _hours,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Hours'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Billable'),
          value: _billable,
          onChanged: (v) => setState(() => _billable = v),
        ),
        FilledButton.icon(
          onPressed: _logTime,
          icon: const Icon(Icons.add),
          label: const Text('Log time'),
        ),
        const Divider(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('This week (${_weekHours.toStringAsFixed(1)} h)',
                style: Theme.of(context).textTheme.titleMedium),
            TextButton.icon(
              onPressed: _submitWeek,
              icon: const Icon(Icons.send),
              label: const Text('Submit week'),
            ),
          ],
        ),
        if (_mine.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No entries this week.'),
          )
        else
          for (final e in _mine)
            Card(
              child: ListTile(
                dense: true,
                title: Text('${e['project'] ?? '(no project)'} — ${e['hours']}h'
                    '${e['billable'] == true ? '  •  billable' : ''}'),
                subtitle: Text('${e['workDate']}  •  ${e['task'] ?? ''}  •  ${e['status']}'),
              ),
            ),
      ],
    );
  }

  Widget _approvalsTab() {
    if (_pending.isEmpty) {
      return const Center(child: Text('No timesheets awaiting approval.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final e in _pending)
          Card(
            child: ListTile(
              title: Text('${e['project'] ?? '(no project)'} — ${e['hours']}h'),
              subtitle: Text('${e['workDate']}  •  ${e['task'] ?? ''}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _decide(e['id'].toString(), true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _decide(e['id'].toString(), false),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
