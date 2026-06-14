import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HR Leave Management (Time off) — Core HR module 1 UI.
/// Tabs: Apply, My Leave (balances + requests), Approvals (admin).
class LeaveManagementScreen extends ConsumerStatefulWidget {
  const LeaveManagementScreen({super.key});

  @override
  ConsumerState<LeaveManagementScreen> createState() =>
      _LeaveManagementScreenState();
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
      _toast('Failed to load leave data: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  String _fmt(DateTime? d) =>
      d == null ? '' : d.toIso8601String().split('T').first;

  Future<void> _apply() async {
    if (_typeId == null || _from == null || _to == null) {
      _toast('Pick a leave type and date range');
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
      _toast('Leave applied');
      await _load();
    } catch (e) {
      _toast('Apply failed: ${_err(e)}');
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
          title: const Text('Reject leave'),
          content: TextField(
            controller: ctl,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
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
      final api = ref.read(apiClientProvider);
      if (approve) {
        await api.post(ApiConfig.hrLeaveApprove(id));
      } else {
        await api.post(ApiConfig.hrLeaveReject(id), data: {'reason': reason});
      }
      await _load();
    } catch (e) {
      _toast('Action failed: ${_err(e)}');
    }
  }

  String _err(Object e) => e.toString();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leave Management'),
          actions: [
            IconButton(
                onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Apply'),
              Tab(text: 'My Leave'),
              Tab(text: 'Approvals'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [_applyTab(), _myLeaveTab(), _approvalsTab()],
              ),
      ),
    );
  }

  Widget _applyTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _typeId,
          decoration: const InputDecoration(
            labelText: 'Leave type',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final t in _types)
              DropdownMenuItem(
                value: t['id'].toString(),
                child: Text(
                    '${t['name']}${t['paid'] == false ? ' (unpaid)' : ''}'),
              ),
          ],
          onChanged: (v) => setState(() => _typeId = v),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _dateField('From', _from, (d) => setState(() => _from = d))),
            const SizedBox(width: 12),
            Expanded(child: _dateField('To', _to, (d) => setState(() => _to = d))),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reasonCtl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting ? null : _apply,
          icon: _submitting
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.send),
          label: const Text('Apply for leave'),
        ),
      ],
    );
  }

  Widget _dateField(String label, DateTime? value, ValueChanged<DateTime> onPick) {
    return InkWell(
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
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(value == null ? 'Select' : _fmt(value)),
      ),
    );
  }

  Widget _myLeaveTab() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Balances', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_balances.isEmpty)
            const Text('No paid leave types configured.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final b in _balances)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${b['leaveType']}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Available: ${b['available']}'),
                          Text('Used: ${b['used']} / ${b['entitled']}',
                              style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Text('My requests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_myLeaves.isEmpty)
            const Text('No leave requests yet.')
          else
            for (final l in _myLeaves) _leaveTile(l, showActions: false),
        ],
      ),
    );
  }

  Widget _approvalsTab() {
    if (_pending.isEmpty) {
      return const Center(child: Text('No pending leave requests.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [for (final l in _pending) _leaveTile(l, showActions: true)],
      ),
    );
  }

  Widget _leaveTile(Map<String, dynamic> l, {required bool showActions}) {
    final status = l['status']?.toString() ?? '';
    return Card(
      child: ListTile(
        title: Text('${l['leaveType']} • ${l['workingDays'] ?? '?'} day(s)'),
        subtitle: Text(
            '${l['fromDate']} → ${l['toDate']}'
            '${(l['reason'] as String?)?.isNotEmpty == true ? '\n${l['reason']}' : ''}'),
        isThreeLine: (l['reason'] as String?)?.isNotEmpty == true,
        trailing: showActions
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Approve',
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => _decide(l['id'].toString(), true),
                  ),
                  IconButton(
                    tooltip: 'Reject',
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => _decide(l['id'].toString(), false),
                  ),
                ],
              )
            : Chip(label: Text(status)),
      ),
    );
  }
}
