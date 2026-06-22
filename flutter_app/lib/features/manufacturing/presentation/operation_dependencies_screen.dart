import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/routing_repository.dart';

/// Manage predecessor / successor links on a routing operation
/// (tracker #16). Paste a routing-operation id, see what must finish
/// before it and what depends on it, add a new predecessor edge, or
/// remove an existing one.
///
/// The current data model holds a single routing-operation id at a
/// time. Future Gantt UI can call the same endpoints to render the
/// whole DAG visually.
class OperationDependenciesScreen extends ConsumerStatefulWidget {
  final String? initialRoutingOperationId;
  const OperationDependenciesScreen({super.key, this.initialRoutingOperationId});

  @override
  ConsumerState<OperationDependenciesScreen> createState() =>
      _OperationDependenciesScreenState();
}

class _OperationDependenciesScreenState
    extends ConsumerState<OperationDependenciesScreen> {
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

  Future<void> _addPredecessor() async {
    final opId = _routingOperationId;
    if (opId == null) return;
    final ctl = TextEditingController();
    final predId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add predecessor'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'Predecessor routing-operation id',
            helperText: 'Must belong to the same routing',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = ctl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (predId == null) return;
    try {
      await ref.read(routingRepositoryProvider).addDependency(
            successorRoutingOperationId: opId,
            predecessorRoutingOperationId: predId,
          );
      if (!mounted) return;
      ref.invalidate(_predecessorsProvider(opId));
      ref.invalidate(_successorsProvider(predId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dependency added')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e))),
      );
    }
  }

  Future<void> _remove(String dependencyId) async {
    final opId = _routingOperationId;
    if (opId == null) return;
    try {
      await ref.read(routingRepositoryProvider).removeDependency(dependencyId);
      if (!mounted) return;
      ref.invalidate(_predecessorsProvider(opId));
      ref.invalidate(_successorsProvider(opId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dependency removed')),
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
      appBar: AppBar(title: const Text('Operation Dependencies')),
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
                      helperText:
                          'The op whose predecessors / successors you want to manage',
                      prefixIcon: Icon(Icons.account_tree_outlined),
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
                        Icon(Icons.account_tree_outlined,
                            size: 64, color: Colors.grey),
                        SizedBox(height: KSpacing.md),
                        Text('Enter a routing-operation id to view its DAG neighbours'),
                      ],
                    ),
                  )
                : _DependencyView(
                    routingOperationId: _routingOperationId!,
                    onRemove: _remove,
                  ),
          ),
        ],
      ),
      floatingActionButton: _routingOperationId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _addPredecessor,
              icon: const Icon(Icons.add),
              label: const Text('Add predecessor'),
            ),
    );
  }
}

class _DependencyView extends ConsumerWidget {
  final String routingOperationId;
  final void Function(String dependencyId) onRemove;
  const _DependencyView(
      {required this.routingOperationId, required this.onRemove});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preds = ref.watch(_predecessorsProvider(routingOperationId));
    final succs = ref.watch(_successorsProvider(routingOperationId));
    return ListView(
      padding: KSpacing.pagePadding,
      children: [
        Text('Predecessors (must finish first)',
            style: KTypography.titleMedium),
        const SizedBox(height: KSpacing.sm),
        preds.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(ApiErrorParser.message(e)),
          data: (rows) => rows.isEmpty
              ? const Card(
                  child: ListTile(
                      title: Text('No predecessors — this op can start at any time')),
                )
              : Column(
                  children: rows.map((r) {
                    final Map<String, dynamic> m = r;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.arrow_back),
                        title: Text(
                            'Pred: ${m['predecessorRoutingOperationId']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red),
                          onPressed: () => onRemove(m['id'].toString()),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: KSpacing.md),
        Text('Successors (waiting for this op)', style: KTypography.titleMedium),
        const SizedBox(height: KSpacing.sm),
        succs.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(ApiErrorParser.message(e)),
          data: (rows) => rows.isEmpty
              ? const Card(
                  child: ListTile(
                      title: Text('No downstream operations depend on this one')),
                )
              : Column(
                  children: rows.map((r) {
                    final Map<String, dynamic> m = r;
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.arrow_forward),
                        title: Text('Succ: ${m['routingOperationId']}'),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }
}

final _predecessorsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, opId) {
  return ref.watch(routingRepositoryProvider).listPredecessors(opId);
});

final _successorsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, opId) {
  return ref.watch(routingRepositoryProvider).listSuccessors(opId);
});
