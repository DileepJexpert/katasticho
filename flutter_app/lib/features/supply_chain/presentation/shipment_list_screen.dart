import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/supply_chain_repository.dart';

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

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(_shipmentListProvider(_statusFilter));

    return KKeyboardListWrapper(
      itemCount: () => (listAsync.valueOrNull as List?)?.length ?? 0,
      onRefresh: () => ref.invalidate(_shipmentListProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shipments'),
          actions: [
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list_outlined),
              onSelected: (v) => setState(() => _statusFilter = v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('All')),
                const PopupMenuItem(value: 'DRAFT', child: Text('Draft')),
                const PopupMenuItem(value: 'IN_TRANSIT', child: Text('In Transit')),
                const PopupMenuItem(value: 'DELIVERED', child: Text('Delivered')),
                const PopupMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
              ],
            ),
          ],
        ),
        body: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
          data: (shipments) {
            if (shipments.isEmpty) {
              return const Center(child: Text('No shipments found'));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_shipmentListProvider),
              child: ListView.builder(
                padding: KSpacing.pagePadding,
                itemCount: shipments.length,
                itemBuilder: (context, index) {
                  final s = shipments[index] as Map<String, dynamic>;
                  return _ShipmentCard(shipment: s, ref: ref);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShipmentCard extends StatelessWidget {
  final Map<String, dynamic> shipment;
  final WidgetRef ref;
  const _ShipmentCard({required this.shipment, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = shipment['status'] as String? ?? 'DRAFT';
    final carrier = shipment['carrier'] as String? ?? '';
    final vehicleNumber = shipment['vehicleNumber'] as String? ?? '';
    final shipmentNumber = shipment['shipmentNumber'] as String? ?? 'SHP-???';

    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: Row(
          children: [
            Expanded(
              child: Text(shipmentNumber, style: KTypography.titleSmall),
            ),
            KStatusChip(status: status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (carrier.isNotEmpty) Text('Carrier: $carrier'),
            if (vehicleNumber.isNotEmpty) Text('Vehicle: $vehicleNumber'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (_) => [
            if (status == 'DRAFT')
              const PopupMenuItem(value: 'dispatch', child: Text('Dispatch')),
            if (status == 'IN_TRANSIT')
              const PopupMenuItem(value: 'deliver', child: Text('Mark Delivered')),
            if (status != 'DELIVERED' && status != 'CANCELLED')
              const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
          ],
        ),
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
