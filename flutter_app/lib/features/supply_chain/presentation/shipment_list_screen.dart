import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/supply_chain_repository.dart';
import 'widgets/scm_breadcrumb.dart';

final _shipmentListProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, status) {
  return ref.watch(supplyChainRepositoryProvider).listShipments(status: status);
});

class ShipmentListScreen extends ConsumerStatefulWidget {
  const ShipmentListScreen({super.key});

  @override
  ConsumerState<ShipmentListScreen> createState() => _ShipmentListScreenState();
}

class _ShipmentListScreenState extends ConsumerState<ShipmentListScreen> {
  String? _statusFilter;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(_shipmentListProvider(_statusFilter));
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => (listAsync.valueOrNull)?.length ?? 0,
      onRefresh: () => ref.invalidate(_shipmentListProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Logistics & Shipments'),
          bottom: scmBreadcrumb(context, 'Shipments'),
        ),
        body: listAsync.when(
          loading: () => const KLoading(message: 'Loading shipments...'),
          error: (e, _) => Center(
            child: Padding(
              padding: KSpacing.pagePadding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: KColors.error),
                  KSpacing.vGapMd,
                  Text(ApiErrorParser.message(e), style: KTypography.bodyMedium, textAlign: TextAlign.center),
                  KSpacing.vGapMd,
                  KButton.outlined(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: () => ref.invalidate(_shipmentListProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (shipments) {
            final filtered = shipments.where((s) {
              if (_searchQuery.isEmpty) return true;
              final m = s as Map<String, dynamic>;
              final shpNo = (m['shipmentNumber'] ?? '').toString().toLowerCase();
              final carrier = (m['carrier'] ?? '').toString().toLowerCase();
              final veh = (m['vehicleNumber'] ?? '').toString().toLowerCase();
              final q = _searchQuery.toLowerCase();
              return shpNo.contains(q) || carrier.contains(q) || veh.contains(q);
            }).toList();

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_shipmentListProvider),
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Shipments & In-Transit Tracking',
                        style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Monitor dispatched and incoming goods shipments with carrier tracking.',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All Shipments',
                          selected: _statusFilter == null,
                          onSelected: () => setState(() => _statusFilter = null),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Draft',
                          selected: _statusFilter == 'DRAFT',
                          onSelected: () => setState(() => _statusFilter = 'DRAFT'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'In Transit',
                          selected: _statusFilter == 'IN_TRANSIT',
                          onSelected: () => setState(() => _statusFilter = 'IN_TRANSIT'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Delivered',
                          selected: _statusFilter == 'DELIVERED',
                          onSelected: () => setState(() => _statusFilter = 'DELIVERED'),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Cancelled',
                          selected: _statusFilter == 'CANCELLED',
                          onSelected: () => setState(() => _statusFilter = 'CANCELLED'),
                        ),
                      ],
                    ),
                  ),
                  KSpacing.vGapMd,
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Search by shipment #, carrier, vehicle...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  KSpacing.vGapMd,
                  if (filtered.isEmpty)
                    KEmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: 'No shipments found',
                      subtitle: _statusFilter != null
                          ? 'No shipments in $_statusFilter status.'
                          : 'Shipments will appear here once dispatched from delivery challans or orders.',
                    )
                  else
                    ...filtered.map((s) {
                      final map = s as Map<String, dynamic>;
                      return _ShipmentCard(shipment: map, ref: ref);
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: KTypography.labelSmall.copyWith(
        color: selected ? cs.onPrimaryContainer : cs.onSurface,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      selectedColor: cs.primaryContainer,
      showCheckmark: false,
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final Map<String, dynamic> shipment;
  final WidgetRef ref;
  const _ShipmentCard({required this.shipment, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = shipment['status'] as String? ?? 'DRAFT';
    final carrier = shipment['carrier'] as String? ?? '';
    final vehicleNumber = shipment['vehicleNumber'] as String? ?? '';
    final shipmentNumber = shipment['shipmentNumber'] as String? ?? 'SHP-???';
    final trackingNo = shipment['trackingNumber'] as String?;

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
            ),
            child: Icon(Icons.local_shipping_outlined, color: cs.primary, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      shipmentNumber,
                      style: KTypography.mono(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapSm,
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (carrier.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.business_outlined, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(carrier, style: KTypography.bodySmall),
                        ],
                      ),
                    if (vehicleNumber.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(vehicleNumber, style: KTypography.mono(fontSize: 12)),
                        ],
                      ),
                    if (trackingNo != null && trackingNo.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag_rounded, size: 14, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('AWB: $trackingNo', style: KTypography.mono(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
            onSelected: (action) => _handleAction(context, action),
            itemBuilder: (_) => [
              if (status == 'DRAFT')
                const PopupMenuItem(
                  value: 'dispatch',
                  child: Row(
                    children: [
                      Icon(Icons.send_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Dispatch Shipment'),
                    ],
                  ),
                ),
              if (status == 'IN_TRANSIT')
                const PopupMenuItem(
                  value: 'deliver',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Mark Delivered'),
                    ],
                  ),
                ),
              if (status != 'DELIVERED' && status != 'CANCELLED')
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Cancel Shipment'),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final repo = ref.read(supplyChainRepositoryProvider);
    final id = shipment['id'] as String;
    try {
      switch (action) {
        case 'dispatch':
          await repo.dispatchShipment(id);
        case 'deliver':
          await repo.deliverShipment(id);
        case 'cancel':
          await repo.cancelShipment(id);
      }
      ref.invalidate(_shipmentListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shipment status updated to $action')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
        );
      }
    }
  }
}
