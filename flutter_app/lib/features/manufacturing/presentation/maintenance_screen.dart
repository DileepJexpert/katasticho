import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// Manufacturing — Maintenance management.
///
/// Tabs:
///  - Schedules: preventive maintenance plans per workstation; "Generate due"
///    creates DRAFT work orders for every schedule whose nextDueDate ≤ today.
///  - Work Orders: lifecycle list (DRAFT → IN_PROGRESS → COMPLETED) with
///    start / complete / cancel actions.
///  - Downtime: aggregated minutes + cost per workstation for a date range.
class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  bool _loadingSchedules = true;
  bool _loadingWorkOrders = true;
  List<Map<String, dynamic>> _schedules = const [];
  List<Map<String, dynamic>> _workOrders = const [];
  List<Map<String, dynamic>> _workstations = const [];

  DateTime _reportFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _reportTo = DateTime.now();
  bool _loadingReport = false;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadSchedules(), _loadWorkOrders(), _loadWorkstations()]);
  }

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? const [];

  Future<void> _loadSchedules() async {
    setState(() => _loadingSchedules = true);
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.mfgMaintSchedules);
      if (!mounted) return;
      setState(() => _schedules = _list(res.data['data']));
    } catch (e) {
      _toast('Failed to load schedules: $e');
    } finally {
      if (mounted) setState(() => _loadingSchedules = false);
    }
  }

  Future<void> _loadWorkOrders() async {
    setState(() => _loadingWorkOrders = true);
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.mfgMaintWorkOrders);
      if (!mounted) return;
      setState(() => _workOrders = _list(res.data['data']));
    } catch (e) {
      _toast('Failed to load work orders: $e');
    } finally {
      if (mounted) setState(() => _loadingWorkOrders = false);
    }
  }

  Future<void> _loadWorkstations() async {
    try {
      final res =
          await ref.read(apiClientProvider).get(ApiConfig.manufacturingWorkstations);
      if (!mounted) return;
      setState(() => _workstations = _list(res.data['data']));
    } catch (_) {
      // Non-fatal — picker just won't populate.
    }
  }

  Future<void> _loadReport() async {
    setState(() => _loadingReport = true);
    try {
      final res = await ref.read(apiClientProvider).get(
        ApiConfig.mfgMaintDowntimeReport,
        queryParameters: {
          'from': _fmt(_reportFrom),
          'to': _fmt(_reportTo),
        },
      );
      if (!mounted) return;
      setState(() => _report = (res.data['data'] as Map).cast<String, dynamic>());
    } catch (e) {
      _toast('Failed to load report: $e');
    } finally {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String? _wsName(Object? id) {
    if (id == null) return null;
    final hit = _workstations.firstWhere(
      (w) => w['id'] == id,
      orElse: () => const {},
    );
    return hit['name'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maintenance'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Schedules'),
            Tab(text: 'Work Orders'),
            Tab(text: 'Downtime'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _schedulesTab(),
          _workOrdersTab(),
          _downtimeTab(),
        ],
      ),
    );
  }

  // ─── Schedules tab ───

  Widget _schedulesTab() {
    if (_loadingSchedules) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_schedules.length} preventive maintenance schedule(s)',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _generateDue,
                icon: const Icon(Icons.bolt),
                label: const Text('Generate due'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _editSchedule(null),
                icon: const Icon(Icons.add),
                label: const Text('New'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _schedules.isEmpty
              ? const Center(child: Text('No schedules yet.'))
              : RefreshIndicator(
                  onRefresh: _loadSchedules,
                  child: ListView.separated(
                    itemCount: _schedules.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _schedules[i];
                      final due = s['nextDueDate']?.toString() ?? '';
                      final ws = _wsName(s['workstationId']) ?? '(workstation)';
                      return ListTile(
                        title: Text('${s['title']} · ${s['code'] ?? ''}'),
                        subtitle: Text(
                          '$ws · every ${s['frequencyDays']}d · next due $due'
                          '${s['active'] == false ? ' · INACTIVE' : ''}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') _editSchedule(s);
                            if (v == 'delete') _deleteSchedule(s);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                                value: 'delete', child: Text('Remove')),
                          ],
                        ),
                        onTap: () => _editSchedule(s),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _generateDue() async {
    try {
      final res = await ref.read(apiClientProvider).post(ApiConfig.mfgMaintGenerateDue);
      final created = (res.data['data'] as List?) ?? const [];
      _toast(created.isEmpty
          ? 'Nothing was due — no work orders generated'
          : '${created.length} maintenance work order(s) created');
      await _loadAll();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _editSchedule(Map<String, dynamic>? existing) async {
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ScheduleDialog(
        initial: existing,
        workstations: _workstations,
      ),
    );
    if (saved == null) return;
    final api = ref.read(apiClientProvider);
    try {
      if (existing == null) {
        await api.post(ApiConfig.mfgMaintSchedules, data: saved);
        _toast('Schedule created');
      } else {
        await api.put(ApiConfig.mfgMaintScheduleById(existing['id'] as String),
            data: saved);
        _toast('Schedule updated');
      }
      await _loadSchedules();
    } on DioException catch (e) {
      _toast('Failed: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _deleteSchedule(Map<String, dynamic> s) async {
    final ok = await _confirm('Remove schedule "${s['title']}"?');
    if (!ok) return;
    try {
      await ref
          .read(apiClientProvider)
          .delete(ApiConfig.mfgMaintScheduleById(s['id'] as String));
      _toast('Removed');
      await _loadSchedules();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  // ─── Work orders tab ───

  Widget _workOrdersTab() {
    if (_loadingWorkOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text('${_workOrders.length} work order(s)',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              FilledButton.icon(
                onPressed: () => _newWorkOrder(),
                icon: const Icon(Icons.add),
                label: const Text('Report issue'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _workOrders.isEmpty
              ? const Center(child: Text('No work orders yet.'))
              : RefreshIndicator(
                  onRefresh: _loadWorkOrders,
                  child: ListView.separated(
                    itemCount: _workOrders.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final w = _workOrders[i];
                      final ws = _wsName(w['workstationId']) ?? '(workstation)';
                      final downtime = w['downtimeMinutes'];
                      return ListTile(
                        leading: _statusChip(w['status']),
                        title: Text('${w['mwoNumber']} · ${w['title']}'),
                        subtitle: Text(
                          '$ws · ${w['maintenanceType']} · ${w['priority']}'
                          '${downtime != null ? ' · ${downtime}m downtime' : ''}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => _woAction(w, v),
                          itemBuilder: (_) {
                            final status = w['status'] as String?;
                            return [
                              if (status == 'DRAFT')
                                const PopupMenuItem(
                                    value: 'start', child: Text('Start')),
                              if (status == 'IN_PROGRESS')
                                const PopupMenuItem(
                                    value: 'complete', child: Text('Complete')),
                              if (status == 'DRAFT' ||
                                  status == 'IN_PROGRESS')
                                const PopupMenuItem(
                                    value: 'cancel', child: Text('Cancel')),
                            ];
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _statusChip(Object? status) {
    final color = switch (status) {
      'DRAFT' => Colors.blueGrey,
      'IN_PROGRESS' => Colors.orange,
      'COMPLETED' => Colors.green,
      'CANCELLED' => Colors.grey,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status?.toString() ?? '',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Future<void> _woAction(Map<String, dynamic> wo, String action) async {
    final api = ref.read(apiClientProvider);
    final id = wo['id'] as String;
    try {
      if (action == 'start') {
        await api.post(ApiConfig.mfgMaintWorkOrderStart(id));
        _toast('Started');
      } else if (action == 'complete') {
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (_) => const _CompleteDialog(),
        );
        if (result == null) return;
        await api.post(ApiConfig.mfgMaintWorkOrderComplete(id), data: result);
        _toast('Completed');
      } else if (action == 'cancel') {
        final reason = await _prompt('Cancel — reason (optional)');
        await api.post(ApiConfig.mfgMaintWorkOrderCancel(id),
            data: {'reason': reason});
        _toast('Cancelled');
      }
      await _loadWorkOrders();
    } on DioException catch (e) {
      _toast('Failed: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _newWorkOrder() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _WorkOrderDialog(workstations: _workstations),
    );
    if (result == null) return;
    try {
      await ref
          .read(apiClientProvider)
          .post(ApiConfig.mfgMaintWorkOrders, data: result);
      _toast('Work order created');
      await _loadWorkOrders();
    } on DioException catch (e) {
      _toast('Failed: ${e.response?.data['message'] ?? e.message}');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  // ─── Downtime tab ───

  Widget _downtimeTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Text('From ${_fmt(_reportFrom)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Text('To ${_fmt(_reportTo)}'),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loadingReport ? null : _loadReport,
                icon: const Icon(Icons.bar_chart),
                label: const Text('Run'),
              ),
            ],
          ),
        ),
        if (_loadingReport)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else if (_report != null)
          Expanded(child: _downtimeBody(_report!))
        else
          const Expanded(
            child: Center(child: Text('Pick a range and tap Run.')),
          ),
      ],
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final initial = isFrom ? _reportFrom : _reportTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _reportFrom = picked;
      } else {
        _reportTo = picked;
      }
    });
  }

  Widget _downtimeBody(Map<String, dynamic> r) {
    final items = ((r['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
    final totalMin = (r['totalMinutes'] as num?)?.toInt() ?? 0;
    final totalCount = (r['totalCount'] as num?)?.toInt() ?? 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _kpi('Total downtime', '$totalMin min'),
                _kpi('Work orders', '$totalCount'),
                _kpi('Workstations', '${items.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...items.map((row) {
          final types = (row['types'] as Map?) ?? const {};
          return Card(
            child: ListTile(
              title: Text(
                '${row['workstationName'] ?? '(unknown)'} '
                '${row['workstationCode'] != null && (row['workstationCode'] as String).isNotEmpty ? '· ${row['workstationCode']}' : ''}',
              ),
              subtitle: Text(
                '${row['totalMinutes']}m downtime · ${row['count']} WO · '
                'cost ${row['totalCost']}\n'
                'types: ${types.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
              ),
              isThreeLine: true,
            ),
          );
        }),
      ],
    );
  }

  Widget _kpi(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: Theme.of(context).textTheme.headlineSmall),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  // ─── Helpers ───

  Future<bool> _confirm(String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('OK')),
        ],
      ),
    );
    return ok == true;
  }

  Future<String> _prompt(String label) async {
    final ctrl = TextEditingController();
    final val = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        content: TextField(
            controller: ctrl,
            decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text),
              child: const Text('OK')),
        ],
      ),
    );
    return val ?? '';
  }
}

// ───────────────────────── Dialogs ─────────────────────────

class _ScheduleDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final List<Map<String, dynamic>> workstations;
  const _ScheduleDialog({required this.initial, required this.workstations});

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _freq;
  late final TextEditingController _est;
  String? _workstationId;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const {};
    _code = TextEditingController(text: i['code']?.toString() ?? '');
    _title = TextEditingController(text: i['title']?.toString() ?? '');
    _desc = TextEditingController(text: i['description']?.toString() ?? '');
    _freq = TextEditingController(text: i['frequencyDays']?.toString() ?? '30');
    _est = TextEditingController(text: i['estimatedDurationMin']?.toString() ?? '');
    _workstationId = i['workstationId'] as String?;
    _active = (i['active'] as bool?) ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'New schedule' : 'Edit schedule'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _workstationId,
                decoration: const InputDecoration(labelText: 'Workstation *'),
                items: widget.workstations
                    .map((w) => DropdownMenuItem(
                          value: w['id'] as String,
                          child: Text('${w['name']} (${w['code']})'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _workstationId = v),
              ),
              TextField(
                controller: _code,
                decoration: const InputDecoration(labelText: 'Code *'),
              ),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              TextField(
                controller: _freq,
                decoration: const InputDecoration(labelText: 'Frequency (days) *'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _est,
                decoration: const InputDecoration(
                    labelText: 'Estimated duration (minutes)'),
                keyboardType: TextInputType.number,
              ),
              SwitchListTile(
                title: const Text('Active'),
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _workstationId == null ||
                  _title.text.trim().isEmpty ||
                  _code.text.trim().isEmpty ||
                  int.tryParse(_freq.text.trim()) == null
              ? null
              : () => Navigator.pop(context, {
                    'workstationId': _workstationId,
                    'code': _code.text.trim(),
                    'title': _title.text.trim(),
                    'description': _desc.text.trim().isEmpty
                        ? null
                        : _desc.text.trim(),
                    'frequencyDays': int.parse(_freq.text.trim()),
                    'estimatedDurationMin': int.tryParse(_est.text.trim()),
                    'active': _active,
                  }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _WorkOrderDialog extends StatefulWidget {
  final List<Map<String, dynamic>> workstations;
  const _WorkOrderDialog({required this.workstations});

  @override
  State<_WorkOrderDialog> createState() => _WorkOrderDialogState();
}

class _WorkOrderDialogState extends State<_WorkOrderDialog> {
  String? _workstationId;
  String _type = 'BREAKDOWN';
  String _priority = 'NORMAL';
  final _title = TextEditingController();
  final _desc = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report maintenance issue'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _workstationId,
                decoration: const InputDecoration(labelText: 'Workstation *'),
                items: widget.workstations
                    .map((w) => DropdownMenuItem(
                          value: w['id'] as String,
                          child: Text('${w['name']} (${w['code']})'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _workstationId = v),
              ),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                      value: 'BREAKDOWN', child: Text('Breakdown')),
                  DropdownMenuItem(
                      value: 'PREVENTIVE', child: Text('Preventive')),
                  DropdownMenuItem(
                      value: 'INSPECTION', child: Text('Inspection')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'BREAKDOWN'),
              ),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: const [
                  DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                  DropdownMenuItem(value: 'HIGH', child: Text('High')),
                  DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                  DropdownMenuItem(value: 'LOW', child: Text('Low')),
                ],
                onChanged: (v) => setState(() => _priority = v ?? 'NORMAL'),
              ),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed:
              _workstationId == null || _title.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, {
                        'workstationId': _workstationId,
                        'maintenanceType': _type,
                        'priority': _priority,
                        'title': _title.text.trim(),
                        'description': _desc.text.trim().isEmpty
                            ? null
                            : _desc.text.trim(),
                      }),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _CompleteDialog extends StatefulWidget {
  const _CompleteDialog();

  @override
  State<_CompleteDialog> createState() => _CompleteDialogState();
}

class _CompleteDialogState extends State<_CompleteDialog> {
  final _notes = TextEditingController();
  final _cost = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Complete maintenance'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _notes,
              decoration: const InputDecoration(labelText: 'Completion notes'),
              maxLines: 3,
            ),
            TextField(
              controller: _cost,
              decoration: const InputDecoration(labelText: 'Cost (optional)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            'cost': double.tryParse(_cost.text.trim()),
          }),
          child: const Text('Complete'),
        ),
      ],
    );
  }
}
