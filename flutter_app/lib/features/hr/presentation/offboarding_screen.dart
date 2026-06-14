import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HR Offboarding — Core HR module 9 UI.
/// List of exits + initiate dialog + clearance checklist / F&F / complete.
class OffboardingScreen extends ConsumerStatefulWidget {
  const OffboardingScreen({super.key});

  @override
  ConsumerState<OffboardingScreen> createState() => _OffboardingScreenState();
}

class _OffboardingScreenState extends ConsumerState<OffboardingScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _users = [];

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
        api.get(ApiConfig.hrOffboarding),
        api.get(ApiConfig.orgUsers),
      ]);
      if (!mounted) return;
      setState(() {
        _items = _list(results[0].data['data']);
        _users = _list(results[1].data['data']);
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

  String _ymd(DateTime d) => d.toIso8601String().split('T').first;

  Future<void> _initiate() async {
    String? userId;
    DateTime? resignation;
    DateTime? lastDay;
    final reason = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Initiate offboarding'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: userId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Employee'),
                  items: [
                    for (final u in _users)
                      DropdownMenuItem(
                        value: u['id'].toString(),
                        child: Text(u['fullName']?.toString() ?? u['id'].toString()),
                      ),
                  ],
                  onChanged: (v) => setD(() => userId = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(resignation == null
                      ? 'Resignation date'
                      : 'Resignation: ${_ymd(resignation!)}'),
                  trailing: const Icon(Icons.event),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx, initialDate: DateTime.now(),
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 1));
                    if (d != null) setD(() => resignation = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(lastDay == null
                      ? 'Last working day'
                      : 'Last day: ${_ymd(lastDay!)}'),
                  trailing: const Icon(Icons.event_available),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx, initialDate: DateTime.now(),
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 1));
                    if (d != null) setD(() => lastDay = d);
                  },
                ),
                TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Initiate')),
          ],
        ),
      ),
    );
    if (ok != true || userId == null) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrOffboarding, data: {
        'employeeUserId': userId,
        'resignationDate': resignation == null ? null : _ymd(resignation!),
        'lastWorkingDay': lastDay == null ? null : _ymd(lastDay!),
        'reason': reason.text.trim(),
      });
      _toast('Offboarding initiated');
      await _load();
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  Future<void> _openDetail(String id) async {
    Map<String, dynamic> ob = {};
    List<Map<String, dynamic>> tasks = [];
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.hrOffboardingById(id));
      final data = (res.data['data'] as Map?)?.cast<String, dynamic>() ?? {};
      ob = (data['offboarding'] as Map?)?.cast<String, dynamic>() ?? {};
      tasks = _list(data['tasks']);
    } catch (e) {
      _toast('Failed: $e');
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Offboarding — ${ob['status']}',
                    style: Theme.of(ctx).textTheme.titleLarge),
                if (ob['lastWorkingDay'] != null)
                  Text('Last working day: ${ob['lastWorkingDay']}'),
                const Divider(),
                const Text('Clearance checklist',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                for (final t in tasks)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: t['completed'] == true,
                    title: Text('${t['label']}'),
                    subtitle: Text('${t['category']}'),
                    onChanged: (t['completed'] == true)
                        ? null
                        : (_) async {
                            try {
                              await ref.read(apiClientProvider).post(
                                  ApiConfig.hrOffboardingTaskComplete(t['id'].toString()));
                              setS(() => t['completed'] = true);
                            } catch (e) {
                              _toast('Failed: $e');
                            }
                          },
                  ),
                const Divider(),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Settle F&F'),
                      onPressed: () => _settleFnf(ctx, id),
                    ),
                    FilledButton.icon(
                      icon: const Icon(Icons.task_alt),
                      label: const Text('Complete'),
                      onPressed: () async {
                        try {
                          await ref.read(apiClientProvider)
                              .post(ApiConfig.hrOffboardingComplete(id));
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          _toast('Cannot complete: ${e.toString()}');
                        }
                      },
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await ref.read(apiClientProvider)
                              .post(ApiConfig.hrOffboardingCancel(id));
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          _toast('Failed: $e');
                        }
                      },
                      child: const Text('Cancel exit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await _load();
  }

  Future<void> _settleFnf(BuildContext sheetCtx, String id) async {
    final amt = TextEditingController();
    final ok = await showDialog<bool>(
      context: sheetCtx,
      builder: (ctx) => AlertDialog(
        title: const Text('Settle full & final'),
        content: TextField(
          controller: amt,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Settle')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrOffboardingFnf(id),
          data: {'amount': double.tryParse(amt.text.trim()) ?? 0});
      _toast('F&F settled');
    } catch (e) {
      _toast('Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offboarding'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _initiate,
        icon: const Icon(Icons.logout),
        label: const Text('Initiate'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No offboardings.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final o in _items)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.logout),
                            title: Text('${o['status']}'
                                '${o['lastWorkingDay'] != null ? '  •  LWD ${o['lastWorkingDay']}' : ''}'),
                            subtitle: Text(o['reason']?.toString() ?? ''),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openDetail(o['id'].toString()),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
