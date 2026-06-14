import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';

/// HR Shift management — Core HR module 3 UI: shift definitions list + create.
class ShiftManagementScreen extends ConsumerStatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  ConsumerState<ShiftManagementScreen> createState() =>
      _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends ConsumerState<ShiftManagementScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _shifts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).get(ApiConfig.hrShifts);
      if (!mounted) return;
      setState(() =>
          _shifts = (res.data['data'] as List?)?.cast<Map<String, dynamic>>() ?? []);
    } catch (e) {
      _toast('Failed to load shifts: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _hms(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _create() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final offs = TextEditingController(text: 'SAT,SUN');
    TimeOfDay start = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 18, minute: 0);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('New shift'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: code, decoration: const InputDecoration(labelText: 'Code')),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Start: ${start.format(ctx)}'),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: start);
                    if (t != null) setD(() => start = t);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('End: ${end.format(ctx)}'),
                  trailing: const Icon(Icons.schedule),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: end);
                    if (t != null) setD(() => end = t);
                  },
                ),
                TextField(
                  controller: offs,
                  decoration: const InputDecoration(
                    labelText: 'Weekly offs',
                    helperText: 'Comma-separated, e.g. SAT,SUN',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true || code.text.trim().isEmpty || name.text.trim().isEmpty) return;

    try {
      await ref.read(apiClientProvider).post(ApiConfig.hrShifts, data: {
        'code': code.text.trim(),
        'name': name.text.trim(),
        'startTime': _hms(start),
        'endTime': _hms(end),
        'weeklyOffs': offs.text.trim(),
        'active': true,
      });
      _toast('Shift created');
      await _load();
    } catch (e) {
      _toast('Create failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shifts'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New shift'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shifts.isEmpty
              ? const Center(child: Text('No shifts defined yet.'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final s in _shifts)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.access_time),
                          title: Text('${s['name']} (${s['code']})'),
                          subtitle: Text(
                              '${s['startTime']} – ${s['endTime']}  •  offs: ${s['weeklyOffs'] ?? '-'}'),
                          trailing: (s['active'] == true)
                              ? const Chip(label: Text('Active'))
                              : const Chip(label: Text('Inactive')),
                        ),
                      ),
                  ],
                ),
    );
  }
}
