import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/widgets.dart';
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
          backgroundColor: KColors.primary,
          foregroundColor: Colors.white,
          tooltip: 'Run MRP (N)',
          onPressed: () => _runMrp(context, ref),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Run MRP'),
        ),
        body: runsAsync.when(
          loading: () => const Center(child: KLoading(message: 'Loading MRP runs...')),
          error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
          data: (runs) {
            if (runs.isEmpty) {
              return const KEmptyState(
                icon: Icons.precision_manufacturing_outlined,
                title: 'No MRP runs yet',
                subtitle: 'Tap "Run MRP" to analyze inventory demand and generate planned orders.',
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
        title: const Text('Run MRP Analysis'),
        content: Text(
          'This will analyze demand forecasts, BOM explosions, and current inventory balances to generate planned orders. Continue?',
          style: KTypography.bodyMedium,
        ),
        actions: [
          KButton.outlined(
            size: KButtonSize.small,
            label: 'Cancel',
            onPressed: () => Navigator.pop(context, false),
          ),
          KSpacing.hGapSm,
          KButton.primary(
            size: KButtonSize.small,
            icon: Icons.play_arrow,
            label: 'Run MRP',
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await ref.read(manufacturingRepositoryProvider).runMrp();
      ref.invalidate(_mrpRunsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('MRP run completed successfully'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorParser.message(e)),
            backgroundColor: KColors.error,
          ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          leading: const Icon(Icons.calculate_outlined, color: KColors.primary),
          title: Row(
            children: [
              Text(
                runNumber,
                style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              KSpacing.hGapSm,
              KStatusChip(status: status),
            ],
          ),
          subtitle: Text(
            '$plannedOrders planned orders • $runDate',
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
          children: [
            if (run['plannedOrders'] is List)
              ...(run['plannedOrders'] as List).map((order) {
                final o = order as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.assignment_outlined, size: 16),
                  title: Text(o['itemName'] as String? ?? 'Item', style: KTypography.labelMedium),
                  subtitle: Text('Qty: ${o['quantity']} • ${o['orderType'] ?? 'PURCHASE'}', style: KTypography.bodySmall),
                  trailing: KButton.outlined(
                    size: KButtonSize.small,
                    onPressed: () => _convertOrder(context, o['id'] as String? ?? ''),
                    label: 'Convert',
                  ),
                );
              }),
            if (run['plannedOrders'] == null)
              Padding(
                padding: const EdgeInsets.all(KSpacing.md),
                child: KButton.outlined(
                  size: KButtonSize.small,
                  onPressed: () => _viewPlannedOrders(context, run['id'] as String? ?? ''),
                  icon: Icons.list_alt_outlined,
                  label: 'View Planned Orders',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _convertOrder(BuildContext context, String orderId) async {
    try {
      await ref.read(manufacturingRepositoryProvider).convertMrpOrder(orderId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order converted to Purchase Order'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ApiErrorParser.message(e)),
            backgroundColor: KColors.error,
          ),
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
            backgroundColor: KColors.error,
          ),
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
            child: Text('Planned Orders', style: KTypography.h3),
          ),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              padding: KSpacing.pagePadding,
              itemCount: orders.length,
              itemBuilder: (_, i) {
                final o = orders[i] as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: KCard(
                    child: ListTile(
                      leading: const Icon(Icons.shopping_cart_outlined, color: KColors.primary),
                      title: Text(o['itemName'] as String? ?? 'Item', style: KTypography.labelMedium),
                      subtitle: Text('Qty: ${o['quantity']} • Due: ${o['dueDate'] ?? 'N/A'}', style: KTypography.bodySmall),
                      trailing: KStatusChip(
                        status: o['orderType'] as String? ?? 'PURCHASE',
                      ),
                    ),
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
