import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/delivery_challan_providers.dart';
import '../data/delivery_challan_repository.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Dispatched', value: 'DISPATCHED'),
  KListTab(label: 'Delivered', value: 'DELIVERED'),
  KListTab(label: 'Cancelled', value: 'CANCELLED'),
];

class DeliveryChallanListScreen extends ConsumerStatefulWidget {
  const DeliveryChallanListScreen({super.key});

  @override
  ConsumerState<DeliveryChallanListScreen> createState() =>
      _DeliveryChallanListScreenState();
}

class _DeliveryChallanListScreenState
    extends ConsumerState<DeliveryChallanListScreen> {
  final Set<String> _selectedIds = {};
  List<Map<String, dynamic>> _currentChallans = const [];

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentChallans.length) return;
    final id = _currentChallans[index]['id']?.toString();
    if (id != null) context.push('/delivery-challans/$id');
  }

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id)
            ? _selectedIds.remove(id)
            : _selectedIds.add(id);
      });

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count challan${count == 1 ? '' : 's'}?'),
        content: const Text(
            'Only DRAFT challans can be deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.error.withValues(alpha: 0.12),
              foregroundColor: KColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(deliveryChallanRepositoryProvider);
    final ids = _selectedIds.toList();
    int success = 0;
    int fail = 0;
    for (final id in ids) {
      try {
        await repo.deleteChallan(id);
        success++;
      } catch (_) {
        fail++;
      }
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
    ref.invalidate(deliveryChallanListProvider);
    final msg = fail == 0
        ? 'Deleted $success successfully'
        : 'Deleted $success, $fail failed';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(deliveryChallanFilterProvider);
    final challansAsync = ref.watch(deliveryChallanListProvider);
    final inSelection = _selectedIds.isNotEmpty;

    return KKeyboardListWrapper(
      itemCount: () => _currentChallans.length,
      onNew: () => context.go('/delivery-challans/create'),
      onRefresh: () => ref.invalidate(deliveryChallanListProvider),
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Delivery Challans',
            searchHint: 'Search delivery challans\u2026',
            tabs: _statusTabs,
            selectedTab: filter.status,
            onTabChanged: (v) => ref
                .read(deliveryChallanFilterProvider.notifier)
                .state = filter.copyWith(status: v, page: 0),
            onSearchChanged: (q) => ref
                .read(deliveryChallanFilterProvider.notifier)
                .state =
                filter.copyWith(search: q.isEmpty ? null : q, page: 0),
            actions: [
              KSavedViewButton(
                entityType: 'delivery_challans',
                currentFilters: {
                  'status': filter.status,
                  'search': filter.search,
                },
                onViewSelected: (filters) {
                  ref.read(deliveryChallanFilterProvider.notifier).state =
                      filter.copyWith(
                    status: filters['status'],
                    search: filters['search'],
                    page: 0,
                  );
                },
              ),
            ],
            selectionCount: _selectedIds.length,
            onClearSelection: _clearSelection,
            selectionActions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Delete selected',
                color: KColors.error,
                visualDensity: VisualDensity.compact,
                onPressed: _bulkDelete,
              ),
            ],
          ),
          Expanded(
            child: challansAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load delivery challans',
                onRetry: () => ref.invalidate(deliveryChallanListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return KEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No delivery challans yet',
                    subtitle:
                        'Create your first delivery challan to get started',
                    actionLabel: 'Create Delivery Challan',
                    onAction: () => context.go('/delivery-challans/create'),
                  );
                }

                final challans = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (challans.isEmpty) {
                  return KEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'No delivery challans found',
                    subtitle: filter.status != null
                        ? 'No ${filter.status!.toLowerCase()} delivery challans'
                        : 'Create your first delivery challan',
                    actionLabel: 'Create Delivery Challan',
                    onAction: () => context.go('/delivery-challans/create'),
                  );
                }

                final challanMaps = challans
                    .whereType<Map>()
                    .map((challan) => challan.cast<String, dynamic>())
                    .toList();
                _currentChallans = challanMaps;

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: challanMaps,
                  onRefresh: () async =>
                      ref.invalidate(deliveryChallanListProvider),
                  mobileItemBuilder: (context, challan) {
                    final id = challan['id']?.toString() ?? '';
                    return _DeliveryChallanCard(
                      challan: challan,
                      selected: _selectedIds.contains(id),
                      inSelection: inSelection,
                      onToggleSelect: () => _toggleSelect(id),
                    );
                  },
                  tableBuilder: (context) => _DeliveryChallanTable(
                    challans: challanMaps,
                    selectedIds: _selectedIds,
                    inSelection: inSelection,
                    onToggleSelect: _toggleSelect,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: inSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go('/delivery-challans/create'),
              icon: const Icon(Icons.add),
              label: const Text('New Challan'),
              tooltip: 'New Challan (N)',
            ),
    ));
  }
}

class _DeliveryChallanTable extends StatelessWidget {
  final List<Map<String, dynamic>> challans;
  final Set<String> selectedIds;
  final bool inSelection;
  final ValueChanged<String> onToggleSelect;

  const _DeliveryChallanTable({
    required this.challans,
    required this.selectedIds,
    required this.inSelection,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 18,
      horizontalMargin: 12,
      columns: const [
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
        DataColumn(label: Text('Challan')),
        DataColumn(label: Text('Customer')),
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Sales Order')),
        DataColumn(label: Text('Vehicle')),
        DataColumn(label: Text('Status')),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: challans.map((challan) {
        final id = challan['id']?.toString() ?? '';
        final challanNumber = challan['challanNumber']?.toString() ?? '--';
        final customerName = challan['contactName']?.toString() ?? 'Unknown';
        final challanDate = challan['challanDate']?.toString();
        final salesOrderNumber =
            challan['salesOrderNumber']?.toString() ?? '--';
        final vehicleNumber = challan['vehicleNumber']?.toString() ?? '--';
        final status = challan['status']?.toString() ?? 'DRAFT';
        final selected = selectedIds.contains(id);

        return DataRow(
          color: kEntityRowColor(context, selected: selected),
          onSelectChanged: (_) {
            if (id.isEmpty) return;
            if (inSelection) {
              onToggleSelect(id);
            } else {
              context.push('/delivery-challans/$id');
            }
          },
          cells: [
            DataCell(KTableSelectionCell(
              selected: selected,
              onChanged: id.isEmpty ? null : (_) => onToggleSelect(id),
            )),
            DataCell(KTableTextCell(value: challanNumber, width: 155, style: KTypography.mono(fontSize: 13, fontWeight: FontWeight.w600))),
            DataCell(KTableTextCell(value: customerName, width: 190)),
            DataCell(KTableDateCell(value: challanDate)),
            DataCell(KTableTextCell(value: salesOrderNumber, width: 140, style: salesOrderNumber != '--' ? KTypography.mono(fontSize: 12) : null)),
            DataCell(KTableTextCell(value: vehicleNumber, width: 120, style: vehicleNumber != '--' ? KTypography.mono(fontSize: 12) : null)),
            DataCell(KTableStatusCell(status: status)),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open delivery challan',
              onPressed: id.isEmpty
                  ? null
                  : () => context.push('/delivery-challans/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _DeliveryChallanCard extends StatelessWidget {
  final Map<String, dynamic> challan;
  final bool selected;
  final bool inSelection;
  final VoidCallback onToggleSelect;

  const _DeliveryChallanCard({
    required this.challan,
    required this.selected,
    required this.inSelection,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = challan['status'] as String? ?? 'DRAFT';
    final customerName = challan['contactName'] as String? ?? 'Unknown';
    final challanNumber = challan['challanNumber'] as String? ?? '--';
    final salesOrderNumber =
        challan['salesOrderNumber'] as String? ?? '';
    final challanDate = challan['challanDate'] as String?;
    final vehicleNumber = challan['vehicleNumber'] as String?;

    return KCard(
      onTap: () {
        if (inSelection) {
          onToggleSelect();
          return;
        }
        final id = challan['id']?.toString();
        if (id != null) context.push('/delivery-challans/$id');
      },
      onLongPress: onToggleSelect,
      borderColor: selected ? cs.primary : null,
      backgroundColor: selected ? cs.primary.withValues(alpha: 0.06) : null,
      child: Row(
        children: [
          if (inSelection) ...[
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? cs.primary : cs.onSurfaceVariant,
              size: 22,
            ),
            KSpacing.hGapSm,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(challanNumber, style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700)),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  customerName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (salesOrderNumber.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text.rich(
                    TextSpan(
                      text: 'SO: ',
                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                      children: [
                        TextSpan(
                          text: salesOrderNumber,
                          style: KTypography.mono(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
                if (challanDate != null) ...[
                  KSpacing.vGapXs,
                  Text(
                    'Date: ${DateFormatter.display(DateTime.parse(challanDate))}',
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textSecondary,
                    ),
                  ),
                ],
                if (vehicleNumber != null &&
                    vehicleNumber.isNotEmpty) ...[
                  KSpacing.vGapXs,
                  Text.rich(
                    TextSpan(
                      text: 'Vehicle: ',
                      style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
                      children: [
                        TextSpan(
                          text: vehicleNumber,
                          style: KTypography.mono(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!inSelection)
            const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
