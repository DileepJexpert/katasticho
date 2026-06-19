import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/routing_repository.dart';

/// Manage fallback (alternate) work centers for a routing operation
/// (tracker #15). When the operation's primary machine is at capacity
/// or down, production can be routed to a priority-ordered alternate.
///
/// Paste a routing-operation id, see its registered alternates, add a
/// new fallback workstation, remove an existing one. The "Find
/// available" action exercises the server-side picker that walks
/// primary → alternates by capacity.
class WorkstationAlternatesScreen extends ConsumerStatefulWidget {
  final String? initialRoutingOperationId;
  const WorkstationAlternatesScreen({super.key, this.initialRoutingOperationId});

  @override
  ConsumerState<WorkstationAlternatesScreen> createState() =>
      _WorkstationAlternatesScreenState();
}

class _WorkstationAlternatesScreenState
    extends ConsumerState<WorkstationAlternatesScreen> {
  final _opCtl = TextEditingController();
  String? _routingOperationId;

  @override
  void initState() {
    super.initState();
    if (widget.initialRoutingOperationId != null) {
      _opCtl.text = widget.initialRoutingOperationId!;
      _routingOperationId = widget.initialRoutingOperationId;
    }
  }

  @override
  void dispose() {
    _opCtl.dispose();
    super.dispose();
  }

  void _load() {
    final id = _opCtl.text.trim();
    if (id.isEmpty) return;
    setState(() => _routingOperationId = id);
  }

  Future<void> _addAlternate() async {
    final opId = _routingOperationId;
    if (opId == null) return;
    final wsCtl = TextEditingController();
    final prioCtl = TextEditingController(text: '1');
    final notesCtl = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add alternate work center'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wsCtl,
              decoration: const InputDecoration(labelText: 'Workstation id'),
              autofocus: true,
            ),
            TextField(
              controller: prioCtl,
              decoration: const InputDecoration(labelText: 'Priority (lower = preferred)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: notesCtl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (wsCtl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'ws': wsCtl.text.trim(),
                  'prio': prioCtl.text.trim(),
                  'notes': notesCtl.text.trim(),
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result == null) return;
    try {
      await ref.read(routingRepositoryProvider).addWorkstationAlternate(
            routingOperationId: opId,
            workstationId: result['ws']!,
            priority: int.tryParse(result['prio'] ?? ''),
            notes: result['notes'],
          );
      if (!mounted) return;
      ref.invalidate(_alternatesProvider(opId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alternate registered')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  Future<void> _remove(String id) async {
    final opId = _routingOperationId;
    if (opId == null) return;
    try {
      await ref.read(routingRepositoryProvider).removeWorkstationAlternate(id);
      if (!mounted) return;
      ref.invalidate(_alternatesProvider(opId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alternate removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  Future<void> _findAvailable() async {
    final opId = _routingOperationId;
    if (opId == null) return;
    final ctl = TextEditingController(text: '8');
    final hours = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Find available work center'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: 'Required hours/day'),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(ctl.text.trim());
              if (v != null) Navigator.pop(ctx, v);
            },
            child: const Text('Find'),
          ),
        ],
      ),
    );
    if (hours == null) return;
    try {
      final ws = await ref
          .read(routingRepositoryProvider)
          .pickAvailableWorkstation(opId, hours);
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Available work center'),
          content: Text(
              '${ws['code']} — ${ws['name']}\nCapacity: ${ws['capacityHoursPerDay']}h/day'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alternate Work Centers'),
        actions: [
          if (_routingOperationId != null)
            IconButton(
              tooltip: 'Find an available work center',
              icon: const Icon(Icons.search),
              onPressed: _findAvailable,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _opCtl,
                    decoration: const InputDecoration(
                      labelText: 'Routing-operation id',
                      helperText: 'The operation whose fallback machines you want to manage',
                      prefixIcon: Icon(Icons.precision_manufacturing_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: KSpacing.sm),
                FilledButton(onPressed: _load, child: const Text('Open')),
              ],
            ),
          ),
          Expanded(
            child: _routingOperationId == null
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz, size: 64, color: Colors.grey),
                        SizedBox(height: KSpacing.md),
                        Text('Enter a routing-operation id to manage its alternate machines'),
                      ],
                    ),
                  )
                : _AlternatesView(
                    routingOperationId: _routingOperationId!,
                    onRemove: _remove,
                  ),
          ),
        ],
      ),
      floatingActionButton: _routingOperationId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addAlternate,
              icon: const Icon(Icons.add),
              label: const Text('Add alternate'),
            ),
    );
  }
}

class _AlternatesView extends ConsumerWidget {
  final String routingOperationId;
  final void Function(String id) onRemove;
  const _AlternatesView(
      {required this.routingOperationId, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_alternatesProvider(routingOperationId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: Text('No alternates — this operation runs on its primary machine only'),
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final a = rows[i];
            return Card(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              child: ListTile(
                leading: CircleAvatar(child: Text('${a['priority']}')),
                title: Text('Workstation ${a['workstationId']}'),
                subtitle: a['notes'] != null && '${a['notes']}'.isNotEmpty
                    ? Text('${a['notes']}', style: KTypography.bodySmall)
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => onRemove(a['id'].toString()),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

final _alternatesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, opId) {
  return ref.watch(routingRepositoryProvider).listWorkstationAlternates(opId);
});
