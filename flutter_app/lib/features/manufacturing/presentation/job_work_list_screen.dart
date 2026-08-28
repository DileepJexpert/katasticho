import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/manufacturing_repository.dart';

class JobWorkListScreen extends ConsumerStatefulWidget {
  const JobWorkListScreen({super.key});

  @override
  ConsumerState<JobWorkListScreen> createState() => _JobWorkListScreenState();
}

class _JobWorkListScreenState extends ConsumerState<JobWorkListScreen> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(jobWorkOrdersProvider(_statusFilter));
    final alertsAsync = ref.watch(_gstAlertsProvider);

    return KKeyboardListWrapper(
      itemCount: () => ordersAsync.valueOrNull?.length ?? 0,
      onNew: () => context.go('/manufacturing/job-work/new'),
      onRefresh: () {
        ref.invalidate(jobWorkOrdersProvider(_statusFilter));
        ref.invalidate(_gstAlertsProvider);
      },
      onOpen: (index) {
        final orders = ordersAsync.valueOrNull;
        if (orders != null && index < orders.length) {
          final id = orders[index]['id']?.toString();
          if (id != null) context.go('/manufacturing/job-work/$id');
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            const KListPageHeader(
              title: 'Job Work Orders',
            ),

            // GST alert banner
            alertsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (alerts) {
                if (alerts.isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: KColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: KColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: KColors.error, size: 20),
                      KSpacing.hGapSm,
                      Expanded(
                        child: Text(
                          '${alerts.length} job work order${alerts.length == 1 ? '' : 's'} approaching or past GST ITC-04 deadline (1 year).',
                          style: KTypography.bodySmall.copyWith(
                            color: KColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Status filter chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                        label: 'All',
                        selected: _statusFilter == null,
                        onTap: () => _setFilter(null)),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Draft',
                        selected: _statusFilter == 'DRAFT',
                        onTap: () => _setFilter('DRAFT')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Sent',
                        selected: _statusFilter == 'SENT',
                        onTap: () => _setFilter('SENT')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Partially Received',
                        selected: _statusFilter == 'PARTIALLY_RECEIVED',
                        onTap: () => _setFilter('PARTIALLY_RECEIVED')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Completed',
                        selected: _statusFilter == 'COMPLETED',
                        onTap: () => _setFilter('COMPLETED')),
                    const SizedBox(width: 8),
                    _FilterChip(
                        label: 'Cancelled',
                        selected: _statusFilter == 'CANCELLED',
                        onTap: () => _setFilter('CANCELLED')),
                  ],
                ),
              ),
            ),

            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: KLoading(message: 'Loading job work orders...')),
                error: (e, _) => KErrorView(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(jobWorkOrdersProvider(_statusFilter)),
                ),
                data: (orders) {
                  if (orders.isEmpty) {
                    return const KEmptyState(
                      icon: Icons.handshake_outlined,
                      title: 'No job work orders',
                      subtitle: 'Create a job work order to send materials to a subcontractor.',
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(jobWorkOrdersProvider(_statusFilter));
                      ref.invalidate(_gstAlertsProvider);
                    },
                    child: ListView.builder(
                      padding: KSpacing.pagePadding,
                      itemCount: orders.length,
                      itemBuilder: (ctx, i) => _JobWorkCard(
                        order: orders[i],
                        onTap: () {
                          final id = orders[i]['id']?.toString();
                          if (id != null) context.go('/manufacturing/job-work/$id');
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: KColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => context.go('/manufacturing/job-work/new'),
          icon: const Icon(Icons.add),
          label: const Text('New Job Work Order'),
          tooltip: 'New Job Work Order (N)',
        ),
      ),
    );
  }

  void _setFilter(String? status) {
    setState(() => _statusFilter = status);
  }
}

// Provider scoped to list screen — fetches alerts automatically
final _gstAlertsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(manufacturingRepositoryProvider).getJobWorkGstAlerts();
});

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _JobWorkCard extends StatelessWidget {
  const _JobWorkCard({required this.order, required this.onTap});
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jwNumber = order['jobWorkNumber']?.toString() ?? '';
    final status = order['status']?.toString() ?? '';
    final vendorId = order['vendorId']?.toString() ?? '';
    final vendorDisplay = vendorId.length > 8 ? '${vendorId.substring(0, 8)}...' : vendorId;
    final totalCost = (order['totalCost'] as num?)?.toDouble();
    final plannedSendDate = order['plannedSendDate']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      jwNumber,
                      style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  KStatusChip(status: status),
                ],
              ),
              KSpacing.vGapSm,
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Vendor: $vendorDisplay', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                  if (totalCost != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total: ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                        KMoney(totalCost),
                      ],
                    ),
                  if (plannedSendDate != null)
                    Text('Send: $plannedSendDate', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
