import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HR Analytics — Core HR module 8 UI: org-wide HR snapshot dashboard.
class HrAnalyticsScreen extends ConsumerStatefulWidget {
  const HrAnalyticsScreen({super.key});

  @override
  ConsumerState<HrAnalyticsScreen> createState() => _HrAnalyticsScreenState();
}

class _HrAnalyticsScreenState extends ConsumerState<HrAnalyticsScreen> {
  bool _loading = true;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res =
          await ref.read(apiClientProvider).get(ApiConfig.hrAnalyticsDashboard);
      if (!mounted) return;
      setState(() =>
          _data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byDept = (_data['byDepartment'] as Map?)?.cast<String, dynamic>() ?? {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Analytics'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _metric('Headcount', _data['headcount'], Icons.groups, Colors.blue),
                      _metric('On leave today', _data['onLeaveToday'],
                          Icons.beach_access, Colors.teal),
                      _metric('Pending leaves', _data['pendingLeaves'],
                          Icons.pending_actions, Colors.orange),
                      _metric('Pending timesheets', _data['pendingTimesheets'],
                          Icons.timer, Colors.indigo),
                      _metric('Pending regularizations',
                          _data['pendingRegularizations'], Icons.edit_calendar, Colors.brown),
                      _metric('Open tickets', _data['openTickets'],
                          Icons.support_agent, Colors.purple),
                      _metric('Docs expiring (30d)',
                          _data['documentsExpiringIn30Days'], Icons.event_busy, Colors.red),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Headcount by department',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (byDept.isEmpty)
                    const Text('No active employees.')
                  else
                    for (final e in byDept.entries)
                      Card(
                        child: ListTile(
                          dense: true,
                          title: Text(e.key),
                          trailing: Text('${e.value}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _metric(String label, Object? value, IconData icon, Color color) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text('${value ?? 0}',
                  style: Theme.of(context).textTheme.headlineSmall),
              Text(label, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
