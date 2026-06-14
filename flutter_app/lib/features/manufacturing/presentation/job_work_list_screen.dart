import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${alerts.length} job work order${alerts.length == 1 ? '' : 's'} approaching or past GST ITC-04 deadline (1 year).',
                        style: TextStyle(
                          color: Colors.red.shade800,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
              loading: () => const Center(child: CircularProgressIndicator()),
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
                    padding: const EdgeInsets.all(16),
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
    final theme = Theme.of(context);
    final jwNumber = order['jobWorkNumber']?.toString() ?? '';
    final status = order['status']?.toString() ?? '';
    final vendorId = order['vendorId']?.toString() ?? '';
    final vendorDisplay = vendorId.length > 8 ? '${vendorId.substring(0, 8)}...' : vendorId;
    final totalCost = order['totalCost'];
    final plannedSendDate = order['plannedSendDate']?.toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      jwNumber,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  KStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                children: [
                  Text('Vendor: $vendorDisplay', style: theme.textTheme.bodySmall),
                  if (totalCost != null)
                    Text('Total: ₹$totalCost', style: theme.textTheme.bodySmall),
                  if (plannedSendDate != null)
                    Text('Send: $plannedSendDate', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
