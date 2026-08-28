import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/routing_repository.dart';

/// Manage predecessor / successor links on a routing operation
/// (tracker #16). Paste a routing-operation id, see what must finish
/// before it and what depends on it, add a new predecessor edge, or
/// remove an existing one.
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
        title: const Text('Add Predecessor'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(
            labelText: 'Predecessor Routing-Operation ID',
            helperText: 'Must belong to the same routing',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            onPressed: () => Navigator.pop(ctx),
            label: 'Cancel',
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            onPressed: () {
              final v = ctl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            label: 'Add',
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
        const SnackBar(content: Text('Dependency added'), backgroundColor: KColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
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
        const SnackBar(content: Text('Dependency removed'), backgroundColor: KColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
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
                      labelText: 'Routing-Operation ID',
                      helperText:
                          'The op whose predecessors / successors you want to manage',
                      prefixIcon: Icon(Icons.account_tree_outlined),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                KSpacing.hGapSm,
                KButton.primary(onPressed: _load, label: 'Open'),
              ],
            ),
          ),
          Expanded(
            child: _routingOperationId == null
                ? const Center(
                    child: KEmptyState(
                      icon: Icons.account_tree_outlined,
                      title: 'Select Routing Operation',
                      subtitle: 'Enter a routing-operation ID above to view and manage its DAG dependencies.',
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
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: _addPredecessor,
              icon: const Icon(Icons.add),
              label: const Text('Add Predecessor'),
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
        KSpacing.vGapSm,
        preds.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(ApiErrorParser.message(e)),
          data: (rows) => rows.isEmpty
              ? const KCard(
                  child: Padding(
                    padding: EdgeInsets.all(KSpacing.md),
                    child: Text('No predecessors — this op can start at any time'),
                  ),
                )
              : Column(
                  children: rows.map((r) {
                    final Map<String, dynamic> m = r;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: KCard(
                        child: ListTile(
                          leading: const Icon(Icons.arrow_back, color: KColors.primary),
                          title: Text(
                            'Pred: ${m['predecessorRoutingOperationId']}',
                            style: KTypography.mono(fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: KColors.error),
                            onPressed: () => onRemove(m['id'].toString()),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        KSpacing.vGapLg,
        Text('Successors (waiting for this op)', style: KTypography.titleMedium),
        KSpacing.vGapSm,
        succs.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text(ApiErrorParser.message(e)),
          data: (rows) => rows.isEmpty
              ? const KCard(
                  child: Padding(
                    padding: EdgeInsets.all(KSpacing.md),
                    child: Text('No downstream operations depend on this one'),
                  ),
                )
              : Column(
                  children: rows.map((r) {
                    final Map<String, dynamic> m = r;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: KCard(
                        child: ListTile(
                          leading: const Icon(Icons.arrow_forward, color: KColors.info),
                          title: Text(
                            'Succ: ${m['routingOperationId']}',
                            style: KTypography.mono(fontSize: 12),
                          ),
                        ),
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
