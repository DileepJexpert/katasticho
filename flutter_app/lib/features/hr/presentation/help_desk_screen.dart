import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HR Help Desk — Core HR module 6 UI.
/// Tabs: My Tickets (raise + list), HR Inbox (open tickets, manage).
class HelpDeskScreen extends ConsumerStatefulWidget {
  const HelpDeskScreen({super.key});

  @override
  ConsumerState<HelpDeskScreen> createState() => _HelpDeskScreenState();
}

class _HelpDeskScreenState extends ConsumerState<HelpDeskScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _mine = [];
  List<Map<String, dynamic>> _open = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _list(Object? d) =>
      (d as List?)?.cast<Map<String, dynamic>>() ?? [];

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      final results = await Future.wait([
        api.get(ApiConfig.hrHelpdeskMine),
        api.get(ApiConfig.hrHelpdeskOpen),
      ]);
      if (!mounted) return;
      setState(() {
        _mine = _list(results[0].data['data']);
        _open = _list(results[1].data['data']);
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

  Future<void> _raise() async {
    final subject = TextEditingController();
    final desc = TextEditingController();
    String category = 'GENERAL';
    String priority = 'NORMAL';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Raise ticket'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'GENERAL', child: Text('General')),
                    DropdownMenuItem(value: 'PAYROLL', child: Text('Payroll')),
                    DropdownMenuItem(value: 'LEAVE', child: Text('Leave')),
                    DropdownMenuItem(value: 'DOCUMENT', child: Text('Document')),
                    DropdownMenuItem(value: 'GRIEVANCE', child: Text('Grievance')),
                  ],
                  onChanged: (v) => setD(() => category = v ?? 'GENERAL'),
                ),
                TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
                TextField(
                  controller: desc,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: const [
                    DropdownMenuItem(value: 'LOW', child: Text('Low')),
                    DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                    DropdownMenuItem(value: 'HIGH', child: Text('High')),
                  ],
                  onChanged: (v) => setD(() => priority = v ?? 'NORMAL'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Raise')),
          ],
        ),
      ),
    );
    if (ok != true || subject.text.trim().isEmpty) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrHelpdeskTickets, data: {
        'category': category,
        'subject': subject.text.trim(),
        'description': desc.text.trim(),
        'priority': priority,
      });
      _toast('Ticket raised');
      await _load();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _openTicket(Map<String, dynamic> t, {required bool hrView}) async {
    final id = t['id'].toString();
    List<Map<String, dynamic>> comments = [];
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.hrHelpdeskTicket(id));
      comments = _list((res.data['data'] as Map?)?['comments']);
    } catch (_) {}
    if (!mounted) return;

    final commentCtl = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${t['subject']}', style: Theme.of(ctx).textTheme.titleLarge),
            Text('${t['category']} • ${t['priority']} • ${t['status']}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            if ((t['description'] as String?)?.isNotEmpty == true) Text(t['description']),
            const Divider(),
            if (comments.isEmpty)
              const Text('No comments yet.')
            else
              ...comments.map((c) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.chat_bubble_outline, size: 18),
                    title: Text(c['body']?.toString() ?? ''),
                  )),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentCtl,
                    decoration: const InputDecoration(hintText: 'Add a comment'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () async {
                    if (commentCtl.text.trim().isEmpty) return;
                    try {
                      await ref.read(apiClientProvider).post(
                          ApiConfig.hrHelpdeskComments(id),
                          data: {'body': commentCtl.text.trim()});
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      _toast('Failed: $e');
                    }
                  },
                ),
              ],
            ),
            if (hrView) ...[
              const Divider(),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in const ['IN_PROGRESS', 'RESOLVED', 'CLOSED'])
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await ref.read(apiClientProvider).post(
                              ApiConfig.hrHelpdeskStatus(id), data: {'status': s});
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          _toast('Failed: $e');
                        }
                      },
                      child: Text(s.replaceAll('_', ' ')),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('HR Help Desk'),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
          bottom: const TabBar(tabs: [
            Tab(text: 'My Tickets'),
            Tab(text: 'HR Inbox'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _raise,
          icon: const Icon(Icons.add),
          label: const Text('Raise'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [
                _ticketList(_mine, hrView: false, empty: 'You have no tickets.'),
                _ticketList(_open, hrView: true, empty: 'No open tickets.'),
              ]),
      ),
    );
  }

  Widget _ticketList(List<Map<String, dynamic>> items, {required bool hrView, required String empty}) {
    if (items.isEmpty) return Center(child: Text(empty));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final t in items)
            Card(
              child: ListTile(
                title: Text(t['subject']?.toString() ?? ''),
                subtitle: Text('${t['category']} • ${t['priority']} • ${t['status']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openTicket(t, hrView: hrView),
              ),
            ),
        ],
      ),
    );
  }
}
