import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
import '../data/routing_repository.dart';

/// Manage fallback (alternate) work centers for a routing operation
/// (tracker #15). When the operation's primary machine is at capacity
/// or down, production can be routed to a priority-ordered alternate.
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
        title: const Text('Add Alternate Work Center'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: wsCtl,
              decoration: const InputDecoration(labelText: 'Workstation ID', border: OutlineInputBorder()),
              autofocus: true,
            ),
            KSpacing.vGapSm,
            TextField(
              controller: prioCtl,
              decoration: const InputDecoration(labelText: 'Priority (lower = preferred)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            KSpacing.vGapSm,
            TextField(
              controller: notesCtl,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
          ],
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
              if (wsCtl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, {
                  'ws': wsCtl.text.trim(),
                  'prio': prioCtl.text.trim(),
                  'notes': notesCtl.text.trim(),
                });
              }
            },
            label: 'Add Alternate',
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
        const SnackBar(content: Text('Alternate registered'), backgroundColor: KColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
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
        const SnackBar(content: Text('Alternate removed'), backgroundColor: KColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
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
        title: const Text('Find Available Work Center'),
        content: TextField(
          controller: ctl,
          decoration: const InputDecoration(labelText: 'Required Hours/Day', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
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
              final v = double.tryParse(ctl.text.trim());
              if (v != null) Navigator.pop(ctx, v);
            },
            label: 'Find',
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
          title: const Text('Available Work Center'),
          content: Text(
              '${ws['code']} — ${ws['name']}\nCapacity: ${ws['capacityHoursPerDay']}h/day',
              style: KTypography.bodyMedium),
          actions: [
            KButton.primary(
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx),
              label: 'OK',
            ),
          ],
        ),
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
                      labelText: 'Routing-Operation ID',
                      helperText: 'The operation whose fallback machines you want to manage',
                      prefixIcon: Icon(Icons.precision_manufacturing_outlined),
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
                      icon: Icons.swap_horiz,
                      title: 'Select Routing Operation',
                      subtitle: 'Enter a routing-operation ID above to manage its alternate and fallback workstations.',
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
              backgroundColor: KColors.primary,
              foregroundColor: Colors.white,
              onPressed: _addAlternate,
              icon: const Icon(Icons.add),
              label: const Text('Add Alternate'),
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
      loading: () => const Center(child: KLoading(message: 'Loading alternates...')),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (rows) {
        if (rows.isEmpty) {
          return const KEmptyState(
            icon: Icons.swap_horiz,
            title: 'No alternates configured',
            subtitle: 'This operation currently runs on its primary workstation only.',
          );
        }
        return ListView.builder(
          padding: KSpacing.pagePadding,
          itemCount: rows.length,
          itemBuilder: (ctx, i) {
            final a = rows[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KCard(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: KColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      '${a['priority']}',
                      style: KTypography.mono(fontSize: 12, fontWeight: FontWeight.w700, color: KColors.primary),
                    ),
                  ),
                  title: Text(
                    'Workstation: ${a['workstationId']}',
                    style: KTypography.mono(fontSize: 12),
                  ),
                  subtitle: a['notes'] != null && '${a['notes']}'.isNotEmpty
                      ? Text('${a['notes']}', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary))
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: KColors.error),
                    onPressed: () => onRemove(a['id'].toString()),
                  ),
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
