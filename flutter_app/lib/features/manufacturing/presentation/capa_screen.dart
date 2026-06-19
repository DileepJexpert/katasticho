import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';

/// Tracker #88: CAPA (Corrective & Preventive Action) inbox.
///
/// Three tabs: All / Open & In-Progress / My CAPAs / Overdue. Floating
/// action button raises a new CAPA. Tap a row to drive its lifecycle
/// (Start → Complete → Verify).
class CapaScreen extends ConsumerStatefulWidget {
  const CapaScreen({super.key});

  @override
  ConsumerState<CapaScreen> createState() => _CapaScreenState();
}

class _CapaScreenState extends ConsumerState<CapaScreen>
    with TickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _dashboard;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _loadDashboard();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    try {
      final res = await ref.read(apiClientProvider).get(
          ApiConfig.manufacturingCapaDashboard);
      if (mounted) {
        setState(() => _dashboard =
            (res.data['data'] as Map?)?.cast<String, dynamic>());
      }
    } catch (_) { /* dashboard is best-effort */ }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAPA'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Open'),
            Tab(text: 'My CAPAs'),
            Tab(text: 'Overdue'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _raiseCapa,
        icon: const Icon(Icons.add),
        label: const Text('Raise CAPA'),
      ),
      body: Column(
        children: [
          if (_dashboard != null) _buildDashboardStrip(_dashboard!),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _CapaList(filter: _ListFilter.all, onChanged: _loadDashboard),
                _CapaList(filter: _ListFilter.open, onChanged: _loadDashboard),
                _CapaList(filter: _ListFilter.mine, onChanged: _loadDashboard),
                _CapaList(filter: _ListFilter.overdue, onChanged: _loadDashboard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardStrip(Map<String, dynamic> d) {
    Widget metric(String label, Object? value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${value ?? 0}',
                  style: KTypography.titleLarge.copyWith(color: color)),
              Text(label, style: KTypography.labelSmall),
            ],
          ),
        );
    return Container(
      color: Colors.blueGrey.shade50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          metric('Open', d['open'], Colors.orange),
          metric('In Progress', d['inProgress'], Colors.blue),
          metric('Completed', d['completed'], Colors.indigo),
          metric('Verified', d['verified'], Colors.green),
          metric('Overdue', d['overdue'], Colors.red),
        ],
      ),
    );
  }

  Future<void> _raiseCapa() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _RaiseCapaDialog(),
    );
    if (result == null) return;
    try {
      await ref.read(apiClientProvider).post(
          ApiConfig.manufacturingCapa, data: result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CAPA raised')));
      _loadDashboard();
      setState(() {}); // Trigger list reload
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e))));
    }
  }
}

enum _ListFilter { all, open, mine, overdue }

class _CapaList extends ConsumerStatefulWidget {
  final _ListFilter filter;
  final VoidCallback onChanged;
  const _CapaList({required this.filter, required this.onChanged});

  @override
  ConsumerState<_CapaList> createState() => _CapaListState();
}

class _CapaListState extends ConsumerState<_CapaList> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      String url;
      switch (widget.filter) {
        case _ListFilter.all:
          url = '${ApiConfig.manufacturingCapa}?size=50';
          break;
        case _ListFilter.open:
          url = '${ApiConfig.manufacturingCapa}?status=OPEN&size=50';
          break;
        case _ListFilter.mine:
          url = ApiConfig.manufacturingCapaMine;
          break;
        case _ListFilter.overdue:
          url = ApiConfig.manufacturingCapaOverdue;
          break;
      }
      final res = await ref.read(apiClientProvider).get(url);
      final raw = res.data['data'];
      final list = widget.filter == _ListFilter.all
              || widget.filter == _ListFilter.open
          ? (raw['content'] as List?)?.cast<dynamic>() ?? const []
          : (raw as List?)?.cast<dynamic>() ?? const [];
      setState(() {
        _items = list.map<Map<String, dynamic>>(
            (r) => (r as Map).cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = ApiErrorParser.message(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_items == null || _items!.isEmpty) {
      return const Center(child: Text('No CAPAs in this view'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(KSpacing.md),
        itemCount: _items!.length,
        itemBuilder: (ctx, i) {
          final c = _items![i];
          return _CapaCard(capa: c, onAction: () {
            _load();
            widget.onChanged();
          });
        },
      ),
    );
  }
}

class _CapaCard extends ConsumerWidget {
  final Map<String, dynamic> capa;
  final VoidCallback onAction;
  const _CapaCard({required this.capa, required this.onAction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = capa['status']?.toString() ?? '';
    final statusColor = switch (status) {
      'OPEN' => Colors.orange,
      'IN_PROGRESS' => Colors.blue,
      'COMPLETED' => Colors.indigo,
      'VERIFIED' => Colors.green,
      'CANCELLED' => Colors.grey,
      _ => Colors.black,
    };
    final priority = capa['priority']?.toString() ?? '';
    final due = capa['dueDate']?.toString();

    return Card(
      child: ListTile(
        title: Text('${capa['capaNumber']} — ${capa['title']}',
            style: KTypography.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                _chip(status, statusColor),
                _chip(capa['capaType']?.toString() ?? '', Colors.deepPurple),
                if (priority.isNotEmpty) _chip(priority, Colors.teal),
                if (due != null && due.isNotEmpty) _chip('Due $due', Colors.grey),
              ],
            ),
            if (capa['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(capa['description'].toString(),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (_) {
            final items = <PopupMenuEntry<String>>[];
            if (status == 'OPEN') items.add(const PopupMenuItem(value: 'start', child: Text('Start')));
            if (status == 'OPEN' || status == 'IN_PROGRESS') items.add(const PopupMenuItem(value: 'complete', child: Text('Mark complete')));
            if (status == 'COMPLETED') items.add(const PopupMenuItem(value: 'verify', child: Text('Verify')));
            if (status != 'VERIFIED' && status != 'CANCELLED') items.add(const PopupMenuItem(value: 'cancel', child: Text('Cancel')));
            return items;
          },
          onSelected: (action) => _runAction(context, ref, action),
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w600)),
      );

  Future<void> _runAction(BuildContext context, WidgetRef ref, String action) async {
    String? notes;
    if (action == 'complete' || action == 'verify' || action == 'cancel') {
      notes = await showDialog<String>(
        context: context,
        builder: (_) => _NotesDialog(action: action),
      );
      if (notes == null) return;
    }
    final body = switch (action) {
      'complete' => {'completionNotes': notes},
      'verify'   => {'effectivenessNotes': notes},
      'cancel'   => {'reason': notes},
      _ => <String, dynamic>{},
    };
    try {
      await ref.read(apiClientProvider).post(
          ApiConfig.manufacturingCapaAction(capa['id'].toString(), action),
          data: body);
      onAction();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e))));
    }
  }
}

class _NotesDialog extends StatefulWidget {
  final String action;
  const _NotesDialog({required this.action});

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  final _ctl = TextEditingController();

  @override
  void dispose() { _ctl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.action) {
      'complete' => 'Completion notes',
      'verify'   => 'Effectiveness review notes',
      'cancel'   => 'Cancellation reason',
      _ => 'Notes',
    };
    return AlertDialog(
      title: Text(label),
      content: TextField(
        controller: _ctl,
        maxLines: 4,
        autofocus: true,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, _ctl.text.trim()),
            child: const Text('Submit')),
      ],
    );
  }
}

class _RaiseCapaDialog extends StatefulWidget {
  const _RaiseCapaDialog();

  @override
  State<_RaiseCapaDialog> createState() => _RaiseCapaDialogState();
}

class _RaiseCapaDialogState extends State<_RaiseCapaDialog> {
  final _titleCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _actionCtl = TextEditingController();
  final _ncrCtl = TextEditingController();
  final _assigneeCtl = TextEditingController();
  String _type = 'CORRECTIVE';
  String _priority = 'NORMAL';
  DateTime? _dueDate;

  @override
  void dispose() {
    _titleCtl.dispose();
    _descCtl.dispose();
    _actionCtl.dispose();
    _ncrCtl.dispose();
    _assigneeCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Raise CAPA'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleCtl, decoration: const InputDecoration(
                  labelText: 'Title*', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Type',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'CORRECTIVE', child: Text('Corrective')),
                    DropdownMenuItem(value: 'PREVENTIVE', child: Text('Preventive')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'CORRECTIVE'),
                )),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'URGENT', child: Text('Urgent')),
                    DropdownMenuItem(value: 'HIGH', child: Text('High')),
                    DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                    DropdownMenuItem(value: 'LOW', child: Text('Low')),
                  ],
                  onChanged: (v) => setState(() => _priority = v ?? 'NORMAL'),
                )),
              ]),
              const SizedBox(height: 8),
              TextField(controller: _descCtl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Problem description',
                      border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _actionCtl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Proposed action',
                      border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _ncrCtl,
                  decoration: const InputDecoration(labelText: 'NCR id (optional)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 8),
              TextField(controller: _assigneeCtl,
                  decoration: const InputDecoration(labelText: 'Assignee user id (optional)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(_dueDate == null
                    ? 'No due date'
                    : 'Due: ${_dueDate!.toIso8601String().substring(0, 10)}')),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Pick'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                    );
                    if (d != null) setState(() => _dueDate = d);
                  },
                ),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Raise')),
      ],
    );
  }

  void _submit() {
    if (_titleCtl.text.trim().isEmpty) return;
    Navigator.pop(context, {
      'capaType': _type,
      'priority': _priority,
      'title': _titleCtl.text.trim(),
      'description': _descCtl.text.trim(),
      'proposedAction': _actionCtl.text.trim(),
      if (_ncrCtl.text.trim().isNotEmpty) 'ncrId': _ncrCtl.text.trim(),
      if (_assigneeCtl.text.trim().isNotEmpty) 'assignedTo': _assigneeCtl.text.trim(),
      if (_dueDate != null) 'dueDate':
          _dueDate!.toIso8601String().substring(0, 10),
    });
  }
}
