import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/courier_repository.dart';

/// List of courier parcels with their current status. The headline number is
/// "pending RTO" — that's the bucket that needs manual action (credit note +
/// stock restock) because the AI never auto-reverses books.
class CourierShipmentListScreen extends ConsumerStatefulWidget {
  const CourierShipmentListScreen({super.key});

  @override
  ConsumerState<CourierShipmentListScreen> createState() =>
      _CourierShipmentListScreenState();
}

class _CourierShipmentListScreenState
    extends ConsumerState<CourierShipmentListScreen> {
  List<dynamic>? _shipments;
  int _pendingRto = 0;
  String? _statusFilter;
  bool _loading = true;
  bool _syncing = false;

  Future<void> _syncAll() async {
    setState(() => _syncing = true);
    try {
      final r = await ref.read(courierRepositoryProvider).syncAll();
      if (!mounted) return;
      final updated = r['updated'] as int? ?? 0;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(updated > 0
            ? '$updated shipment(s) updated from courier tracking'
            : 'Tracking checked — nothing new'),
      ));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Sync failed: ${e.toString().replaceAll('Exception: ', '')}')));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(courierRepositoryProvider);
      final shipments = await repo.listShipments(status: _statusFilter);
      // Pending RTO is best-effort — never block the main list on it.
      List<dynamic> rto = const [];
      try {
        rto = await repo.listPendingRto();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _shipments = shipments;
        _pendingRto = rto.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Load failed: ${e.toString().replaceAll('Exception: ', '')}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Courier Shipments'),
        actions: [
          IconButton(
            tooltip: 'Sync tracking from couriers',
            onPressed: _syncing ? null : _syncAll,
            icon: _syncing
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_sync),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: KLoading())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  if (_pendingRto > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: KColors.error.withValues(alpha: 0.08),
                        borderRadius: KSpacing.borderRadiusMd,
                        border: Border.all(
                            color: KColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_return, color: KColors.error),
                          KSpacing.hGapSm,
                          Expanded(
                            child: Text(
                              '$_pendingRto parcel(s) returned to you — issue a credit note and restock the items.',
                              style: KTypography.labelLarge
                                   .copyWith(color: KColors.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                  _filterRow(),
                  KSpacing.vGapSm,
                  ...(_shipments ?? const []).map(_shipmentTile),
                  if ((_shipments ?? const []).isEmpty)
                    KCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No shipments yet. Create one from a delivery challan or invoice.',
                          textAlign: TextAlign.center,
                          style: KTypography.bodyMedium
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _filterRow() {
    final options = <String?>[
      null, 'DRAFT', 'BOOKED', 'IN_TRANSIT', 'OUT_FOR_DELIVERY',
      'DELIVERED', 'RTO_INITIATED', 'RTO_DELIVERED', 'CANCELLED',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final selected = _statusFilter == o;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              selected: selected,
              label: Text(o ?? 'All'),
              onSelected: (_) {
                setState(() => _statusFilter = o);
                _load();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _shipmentTile(dynamic s) {
    final status = s['status'] as String? ?? '';
    final (color, icon) = _statusVisuals(status);
    final awb = s['awbNumber'] as String?;
    final cod = s['cod'] == true;
    final codAmt = (s['codAmount'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: KCard(
        child: Row(
          children: [
            Icon(icon, color: color),
            KSpacing.hGapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(s['courierShipmentNumber']?.toString() ?? '—',
                          style: KTypography.labelLarge),
                      KSpacing.hGapSm,
                      Text('· ${s['courierPartner']}',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary)),
                    ],
                  ),
                  if (awb != null && awb.isNotEmpty)
                    Text('AWB: $awb',
                        style: KTypography.mono(
                            fontSize: 11, color: KColors.textSecondary)),
                  KSpacing.vGapXxs,
                  Row(
                    children: [
                      KStatusChip(status: status),
                      if (cod) ...[
                        KSpacing.hGapSm,
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: KColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'COD ',
                                style: KTypography.bodySmall
                                    .copyWith(color: KColors.warning, fontWeight: FontWeight.w600),
                              ),
                              KMoney(
                                codAmt,
                                size: KMoneySize.small,
                                style: KTypography.bodySmall
                                    .copyWith(color: KColors.warning, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, IconData) _statusVisuals(String status) => switch (status) {
        'DELIVERED' => (KColors.success, Icons.check_circle),
        'RTO_DELIVERED' => (KColors.error, Icons.assignment_return),
        'RTO_INITIATED' => (KColors.error, Icons.undo),
        'IN_TRANSIT' || 'OUT_FOR_DELIVERY' => (KColors.warning, Icons.local_shipping),
        'BOOKED' || 'PICKED_UP' => (KColors.textSecondary, Icons.inventory_2),
        'CANCELLED' => (KColors.textSecondary, Icons.cancel),
        _ => (KColors.textSecondary, Icons.local_post_office),
      };
}
