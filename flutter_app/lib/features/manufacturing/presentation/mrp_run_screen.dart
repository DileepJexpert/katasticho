import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/manufacturing_repository.dart';

final _mrpRunsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(manufacturingRepositoryProvider).listMrpRuns();
});

class MrpRunScreen extends ConsumerWidget {
  const MrpRunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(_mrpRunsProvider);

    return KKeyboardListWrapper(
      itemCount: () => (runsAsync.valueOrNull)?.length ?? 0,
      onRefresh: () => ref.invalidate(_mrpRunsProvider),
      child: Scaffold(
        appBar: AppBar(title: const Text('MRP Runs')),
        floatingActionButton: FloatingActionButton.extended(
          tooltip: 'Run MRP (N)',
          onPressed: () => _runMrp(context, ref),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Run MRP'),
        ),
        body: runsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
          data: (runs) {
            if (runs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.precision_manufacturing_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: KSpacing.md),
                    const Text('No MRP runs yet'),
                    const SizedBox(height: KSpacing.sm),
                    const Text('Tap "Run MRP" to generate planned orders',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_mrpRunsProvider),
              child: ListView.builder(
                padding: KSpacing.pagePadding,
                itemCount: runs.length,
                itemBuilder: (context, index) {
                  final run = runs[index] as Map<String, dynamic>;
                  return _MrpRunCard(run: run, ref: ref);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runMrp(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Run MRP'),
        content: const Text(
            'This will analyze demand forecasts and open purchase orders to generate planned orders. Continue?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Run MRP')),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await ref.read(manufacturingRepositoryProvider).runMrp();
      ref.invalidate(_mrpRunsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MRP run completed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ApiErrorParser.message(e)),
              backgroundColor: KColors.error),
        );
      }
    }
  }
}

class _MrpRunCard extends StatelessWidget {
  final Map<String, dynamic> run;
  final WidgetRef ref;
  const _MrpRunCard({required this.run, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = run['status'] as String? ?? 'COMPLETED';
    final runNumber = run['runNumber'] as String? ?? 'MRP-???';
    final plannedOrders = run['plannedOrderCount'] as int? ?? 0;
    final runDate = run['createdAt'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ExpansionTile(
        leading: const Icon(Icons.calculate_outlined),
        title: Row(
          children: [
            Text(runNumber, style: KTypography.titleSmall),
            const SizedBox(width: KSpacing.sm),
            KStatusChip(status: status),
          ],
        ),
        subtitle: Text('$plannedOrders planned orders • $runDate'),
        children: [
          if (run['plannedOrders'] is List)
            ...(run['plannedOrders'] as List).map((order) {
              final o = order as Map<String, dynamic>;
              return ListTile(
                dense: true,
                leading: const Icon(Icons.assignment_outlined, size: 16),
                title: Text(o['itemName'] as String? ?? 'Item'),
                subtitle: Text('Qty: ${o['quantity']} • ${o['orderType'] ?? 'PURCHASE'}'),
                trailing: TextButton(
                  onPressed: () => _convertOrder(context, o['id'] as String? ?? ''),
                  child: const Text('Convert'),
                ),
              );
            }),
          if (run['plannedOrders'] == null)
            Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: TextButton.icon(
                onPressed: () => _viewPlannedOrders(context, run['id'] as String? ?? ''),
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('View Planned Orders'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _convertOrder(BuildContext context, String orderId) async {
    try {
      await ref.read(manufacturingRepositoryProvider).convertMrpOrder(orderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order converted to Purchase Order')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ApiErrorParser.message(e)),
              backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<void> _viewPlannedOrders(BuildContext context, String runId) async {
    try {
      final orders =
          await ref.read(manufacturingRepositoryProvider).getMrpRunOrders(runId);
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (_) => _PlannedOrdersSheet(orders: orders),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ApiErrorParser.message(e)),
              backgroundColor: KColors.error),
        );
      }
    }
  }
}

class _PlannedOrdersSheet extends StatelessWidget {
  final List<dynamic> orders;
  const _PlannedOrdersSheet({required this.orders});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(KSpacing.md),
            child: Text('Planned Orders', style: KTypography.titleMedium),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i] as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.shopping_cart_outlined),
                  title: Text(o['itemName'] as String? ?? 'Item'),
                  subtitle:
                      Text('Qty: ${o['quantity']} • Due: ${o['dueDate'] ?? 'N/A'}'),
                  trailing: Chip(
                    label: Text(o['orderType'] as String? ?? 'PURCHASE'),
                    backgroundColor: KColors.info.withValues(alpha: 0.12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
