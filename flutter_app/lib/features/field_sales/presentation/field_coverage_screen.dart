import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../data/field_sales_repository.dart';

/// Manager coverage analytics: team roll-up, tour-plan deviation, and
/// customer visit-frequency compliance. Works for all verticals.
class FieldCoverageScreen extends ConsumerStatefulWidget {
  const FieldCoverageScreen({super.key});

  @override
  ConsumerState<FieldCoverageScreen> createState() =>
      _FieldCoverageScreenState();
}

class _FieldCoverageScreenState extends ConsumerState<FieldCoverageScreen> {
  List<Map<String, dynamic>> _users = [];
  String? _selectedUserId;
  late DateTime _month;

  List<Map<String, dynamic>> _team = [];
  Map<String, dynamic>? _deviation;
  Map<String, dynamic>? _frequency;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
    _loadAll();
  }

  String get _monthStr =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}-01';

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(apiClientProvider).dio;
      final repo = ref.read(fieldSalesRepositoryProvider);

      if (_users.isEmpty) {
        final usersResp =
            await dio.get<Map<String, dynamic>>(ApiConfig.orgUsers);
        final usersData = (usersResp.data?['data'] as List?) ?? [];
        _users = usersData
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }

      final monthEnd = DateTime(_month.year, _month.month + 1, 0);
      final from = _monthStr;
      final to =
          '${monthEnd.year}-${monthEnd.month.toString().padLeft(2, '0')}-${monthEnd.day.toString().padLeft(2, '0')}';

      final futures = <Future>[
        repo.teamDashboard(from, to),
        repo.frequencyCompliance(_monthStr, salespersonId: _selectedUserId),
        if (_selectedUserId != null)
          repo.deviationReport(_monthStr, _selectedUserId!),
      ];
      final results = await Future.wait(futures);

      if (mounted) {
        setState(() {
          _team = results[0] as List<Map<String, dynamic>>;
          _frequency = results[1] as Map<String, dynamic>;
          _deviation = _selectedUserId != null
              ? results[2] as Map<String, dynamic>
              : null;
        });
      }
    } on DioException catch (e) {
      _toast('Failed to load coverage: ${e.message}');
    } catch (e) {
      _toast('Failed to load coverage: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Pick any day in the month',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month, 1));
      _loadAll();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Field Coverage'),
          actions: [
            TextButton.icon(
              onPressed: _pickMonth,
              icon: const Icon(Icons.calendar_month),
              label: Text('${_month.month}/${_month.year}'),
            ),
            IconButton(
                icon: const Icon(Icons.refresh), onPressed: _loadAll),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Team'),
            Tab(text: 'Deviation'),
            Tab(text: 'Frequency'),
          ]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _teamTab(),
                _deviationTab(),
                _frequencyTab(),
              ]),
      ),
    );
  }

  Widget _teamTab() {
    if (_team.isEmpty) {
      return const Center(child: Text('No route activity this month'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: _team.map((r) {
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(r['salespersonName']?.toString().trim().isEmpty ?? true
                ? 'Salesperson'
                : r['salespersonName'].toString()),
            subtitle: Text(
                'Days ${r['routeDays']} • Visits ${r['visitsCompleted']}/${r['visitsPlanned']}'
                ' (${r['completionPct']}%)'
                ' • ${r['distanceKm']} km • DCRs ${r['dcrsSubmitted']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('₹${r['ordersValue']}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Coll ₹${r['collections']}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            onTap: () {
              setState(() => _selectedUserId = r['salespersonId'].toString());
              _loadAll();
              DefaultTabController.of(context).animateTo(1);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _deviationTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedUserId,
            decoration: const InputDecoration(labelText: 'Salesperson'),
            items: _users
                .map((u) => DropdownMenuItem(
                      value: u['id']?.toString(),
                      child: Text('${u['fullName'] ?? u['email'] ?? ''}'),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _selectedUserId = v);
              _loadAll();
            },
          ),
        ),
        if (_deviation == null)
          const Expanded(
              child: Center(child: Text('Pick a salesperson to compare '
                  'their tour plan against actual work')))
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Chip(label: Text('Plan: ${_deviation!['planStatus'] ?? '—'}')),
                const SizedBox(width: 8),
                Chip(
                    label: Text('As planned: ${_deviation!['daysAsPlanned']}'),
                    backgroundColor: Colors.green.shade50),
                const SizedBox(width: 8),
                Chip(
                    label: Text('Deviated: ${_deviation!['daysDeviated']}'),
                    backgroundColor: Colors.red.shade50),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: ((_deviation!['days'] as List?) ?? [])
                  .whereType<Map>()
                  .map((d) {
                final status = d['status']?.toString() ?? '';
                final color = switch (status) {
                  'AS_PLANNED' => Colors.green,
                  'MISSED' => Colors.red,
                  'UNPLANNED_WORK' => Colors.orange,
                  'WORKED_ON_NON_FIELD_DAY' => Colors.orange,
                  _ => Colors.grey,
                };
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.circle, size: 12, color: color),
                  title: Text('${d['date']} — '
                      '${d['plannedActivity'] ?? 'no plan'}'
                      '${(d['plannedArea'] ?? '').toString().isNotEmpty ? ' @ ${d['plannedArea']}' : ''}'),
                  subtitle: Text(
                      d['worked'] == true ? 'Worked, ${d['visitsCompleted']} visits' : 'Did not work'),
                  trailing: Text(status,
                      style: TextStyle(color: color, fontSize: 11)),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _frequencyTab() {
    final f = _frequency;
    if (f == null) return const Center(child: CircularProgressIndicator());
    final contacts =
        ((f['contacts'] as List?) ?? []).whereType<Map>().toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Chip(label: Text('Targets: ${f['totalTargets']}')),
              const SizedBox(width: 8),
              Chip(
                  label: Text(
                      'Compliant: ${f['compliant']} (${f['compliancePct']}%)'),
                  backgroundColor: Colors.green.shade50),
            ],
          ),
        ),
        Expanded(
          child: contacts.isEmpty
              ? const Center(
                  child: Text('No customers have a required visits/month '
                      'set on the contact master'))
              : ListView(
                  children: contacts.map((c) {
                    final ok = c['compliant'] == true;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                          ok ? Icons.check_circle : Icons.error_outline,
                          color: ok ? Colors.green : Colors.red),
                      title: Text(c['contactName']?.toString() ?? ''),
                      subtitle: Text([
                        c['category'],
                        c['mrClass'] != null ? 'Class ${c['mrClass']}' : null,
                      ].where((x) => x != null).join(' • ')),
                      trailing: Text(
                          '${c['actualVisits']} / ${c['requiredVisits']} visits',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: ok ? Colors.green : Colors.red)),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}
