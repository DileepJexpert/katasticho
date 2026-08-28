import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';

/// Tracker #88: CAPA (Corrective & Preventive Action) inbox.
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
        backgroundColor: KColors.primary,
        foregroundColor: Colors.white,
        onPressed: _raiseCapa,
        icon: const Icon(Icons.add),
        label: const Text('Raise CAPA'),
        tooltip: 'Raise CAPA (N)',
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
      color: KColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          metric('Open', d['open'], KColors.warning),
          metric('In Progress', d['inProgress'], KColors.info),
          metric('Completed', d['completed'], KColors.primary),
          metric('Verified', d['verified'], KColors.success),
          metric('Overdue', d['overdue'], KColors.error),
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
          const SnackBar(content: Text('CAPA raised successfully'), backgroundColor: KColors.success));
      _loadDashboard();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error));
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
    if (_loading) return const Center(child: KLoading(message: 'Loading CAPAs...'));
    if (_error != null) return Center(child: Text(_error!));
    if (_items == null || _items!.isEmpty) {
      return const KEmptyState(
        icon: Icons.assignment_turned_in_outlined,
        title: 'No CAPAs found',
        subtitle: 'No corrective or preventive actions in this filter.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: KSpacing.pagePadding,
        itemCount: _items!.length,
        itemBuilder: (ctx, i) {
          final c = _items![i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CapaCard(capa: c, onAction: () {
              _load();
              widget.onChanged();
            }),
          );
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
    final priority = capa['priority']?.toString() ?? '';
    final due = capa['dueDate']?.toString();

    return KCard(
      child: ListTile(
        title: Row(
          children: [
            Text(
              capa['capaNumber']?.toString() ?? 'CAPA',
              style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            KSpacing.hGapSm,
            Expanded(
              child: Text(
                capa['title']?.toString() ?? '',
                style: KTypography.labelLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KSpacing.vGapXs,
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                KStatusChip(status: status),
                _chip(capa['capaType']?.toString() ?? '', KColors.primary),
                if (priority.isNotEmpty) _chip(priority, KColors.info),
                if (due != null && due.isNotEmpty) _chip('Due $due', KColors.textSecondary),
              ],
            ),
            if (capa['description'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  capa['description'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (_) {
            final items = <PopupMenuEntry<String>>[];
            if (status == 'OPEN') items.add(const PopupMenuItem(value: 'start', child: Text('Start')));
            if (status == 'OPEN' || status == 'IN_PROGRESS') items.add(const PopupMenuItem(value: 'complete', child: Text('Mark Complete')));
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
          SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error));
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
      'complete' => 'Completion Notes',
      'verify'   => 'Effectiveness Review Notes',
      'cancel'   => 'Cancellation Reason',
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
        KButton.outlined(
          size: KButtonSize.small,
          onPressed: () => Navigator.pop(context),
          label: 'Cancel',
        ),
        KSpacing.hGapSm,
        KButton.primary(
          size: KButtonSize.small,
          onPressed: () => Navigator.pop(context, _ctl.text.trim()),
          label: 'Submit',
        ),
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
                  labelText: 'Title *', border: OutlineInputBorder())),
              KSpacing.vGapSm,
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type',
                      border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'CORRECTIVE', child: Text('Corrective')),
                    DropdownMenuItem(value: 'PREVENTIVE', child: Text('Preventive')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'CORRECTIVE'),
                )),
                KSpacing.hGapSm,
                Expanded(child: DropdownButtonFormField<String>(
                  initialValue: _priority,
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
              KSpacing.vGapSm,
              TextField(controller: _descCtl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Problem Description',
                      border: OutlineInputBorder())),
              KSpacing.vGapSm,
              TextField(controller: _actionCtl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Proposed Action',
                      border: OutlineInputBorder())),
              KSpacing.vGapSm,
              TextField(controller: _ncrCtl,
                  decoration: const InputDecoration(labelText: 'NCR ID (optional)',
                      border: OutlineInputBorder())),
              KSpacing.vGapSm,
              TextField(controller: _assigneeCtl,
                  decoration: const InputDecoration(labelText: 'Assignee User ID (optional)',
                      border: OutlineInputBorder())),
              KSpacing.vGapSm,
              Row(children: [
                Expanded(child: Text(_dueDate == null
                    ? 'No due date'
                    : 'Due: ${_dueDate!.toIso8601String().substring(0, 10)}',
                    style: KTypography.bodySmall)),
                KButton.outlined(
                  size: KButtonSize.small,
                  icon: Icons.calendar_today,
                  label: 'Pick Date',
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
        KButton.outlined(
          size: KButtonSize.small,
          onPressed: () => Navigator.pop(context),
          label: 'Cancel',
        ),
        KSpacing.hGapSm,
        KButton.primary(
          size: KButtonSize.small,
          onPressed: _submit,
          label: 'Raise CAPA',
        ),
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
