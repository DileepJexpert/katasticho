import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../data/stock_transit_repository.dart';

class StockTransferTransitScreen extends ConsumerStatefulWidget {
  const StockTransferTransitScreen({super.key});

  @override
  ConsumerState<StockTransferTransitScreen> createState() => _StockTransferTransitScreenState();
}

class _StockTransferTransitScreenState extends ConsumerState<StockTransferTransitScreen> {
  String _selectedStatus = 'ALL';
  List<TransferOrderDispatchDto> _dispatches = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDispatches();
  }

  Future<void> _loadDispatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(stockTransitRepositoryProvider);
      final list = await repo.listDispatches(status: _selectedStatus);
      if (mounted) setState(() => _dispatches = list);
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to load transit shipments: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showPingDialog(TransferOrderDispatchDto dispatch) async {
    final locationController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final notesController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record GPS Checkpoint - ${dispatch.vehicleNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KTextField(
              controller: locationController,
              label: 'Checkpoint Location Name',
            ),
            KSpacing.vGapMd,
            Row(
              children: [
                Expanded(
                  child: KTextField(
                    controller: latController,
                    label: 'Latitude',
                  ),
                ),
                KSpacing.hGapMd,
                Expanded(
                  child: KTextField(
                    controller: lngController,
                    label: 'Longitude',
                  ),
                ),
              ],
            ),
            KSpacing.vGapMd,
            KTextField(
              controller: notesController,
              label: 'Transit Notes / Milestone',
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          KButton.primary(
            label: 'Submit Ping',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (ok == true && locationController.text.trim().isNotEmpty) {
      final latitude = double.tryParse(latController.text);
      final longitude = double.tryParse(lngController.text);
      if (latitude == null || longitude == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter valid latitude and longitude.'), backgroundColor: KColors.error),
          );
        }
        return;
      }
      try {
        final repo = ref.read(stockTransitRepositoryProvider);
        await repo.recordPing(
          dispatch.id,
          latitude,
          longitude,
          locationController.text.trim(),
          notes: notesController.text.trim(),
        );
        _loadDispatches();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('GPS Telemetry ping recorded!'), backgroundColor: KColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ping failed: $e'), backgroundColor: KColors.error),
          );
        }
      }
    }
  }

  Future<void> _receiveAtDestination(String dispatchId) async {
    try {
      final repo = ref.read(stockTransitRepositoryProvider);
      await repo.receiveAtDestination(dispatchId);
      _loadDispatches();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Destination receipt posted and stock updated.'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Destination receipt failed: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<void> _markDelivered(String dispatchId) async {
    try {
      final repo = ref.read(stockTransitRepositoryProvider);
      await repo.markDelivered(dispatchId);
      _loadDispatches();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shipment marked as DELIVERED!'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delivery update failed: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inter-Branch Stock In-Transit Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDispatches,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED', 'RECEIVED'].map((s) {
                  final isSel = _selectedStatus == s;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s.replaceAll('_', ' ')),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() => _selectedStatus = s);
                        _loadDispatches();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Main Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: KColors.error)),
                            KSpacing.vGapMd,
                            KButton.secondary(label: 'Retry', onPressed: _loadDispatches),
                          ],
                        ),
                      )
                    : _dispatches.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.local_shipping_outlined, size: 64, color: KColors.textHint),
                                KSpacing.vGapMd,
                                Text('No in-transit dispatches found', style: KTypography.h3),
                                KSpacing.vGapXs,
                                Text('Dispatched transfer orders between branches will appear here.',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: KSpacing.pagePadding,
                            itemCount: _dispatches.length,
                            separatorBuilder: (_, __) => KSpacing.vGapLg,
                            itemBuilder: (context, index) {
                              final d = _dispatches[index];
                              return _buildDispatchCard(d);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildDispatchCard(TransferOrderDispatchDto d) {
    final isActive = d.status == 'DISPATCHED' || d.status == 'IN_TRANSIT';
    final isDelivered = d.status == 'DELIVERED';

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Vehicle No + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: KColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: KColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping, size: 18, color: KColors.primary),
                        KSpacing.hGapXs,
                        Text(d.vehicleNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                  KSpacing.hGapMd,
                  Text('Driver: ${d.driverName}', style: KTypography.labelMedium),
                  if (d.driverPhone != null) ...[
                    KSpacing.hGapSm,
                    Text('(${d.driverPhone})', style: KTypography.bodySmall.copyWith(color: KColors.textHint)),
                  ],
                ],
              ),
              KStatusChip(status: d.status),
            ],
          ),
          KSpacing.vGapMd,

          // Latest recorded checkpoint; the location is provided by the dispatcher.
          Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Route Icon Map Simulation
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF38BDF8), width: 2),
                  ),
                  child: const Icon(Icons.navigation, color: Color(0xFF38BDF8), size: 28),
                ),
                KSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pin_drop, size: 16, color: Color(0xFF4ADE80)),
                          KSpacing.hGapXs,
                          Expanded(
                            child: Text(
                              d.lastLocationName ?? 'No checkpoint recorded yet',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      KSpacing.vGapXs,
                      if (d.latitude != null && d.longitude != null)
                        Text(
                          'Coords: ${d.latitude!.toStringAsFixed(4)}° N, ${d.longitude!.toStringAsFixed(4)}° E',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'monospace', fontSize: 11),
                        ),
                      KSpacing.vGapXs,
                      Text(
                        'Dispatched: ${d.dispatchedAt.split('T').first} · Events: ${d.events.length} checkpoints recorded',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isActive) ...[
                KButton.secondary(
                  label: 'Record GPS Ping',
                  icon: Icons.add_location_alt_outlined,
                  size: KButtonSize.small,
                  onPressed: () => _showPingDialog(d),
                ),
                KSpacing.hGapSm,
                KButton.primary(
                  label: 'Mark Delivered',
                  icon: Icons.check_circle_outline,
                  size: KButtonSize.small,
                  onPressed: () => _markDelivered(d.id),
                ),
              ] else if (isDelivered) ...[
                KButton.primary(
                  label: 'Receive at Destination',
                  icon: Icons.inventory_2_outlined,
                  size: KButtonSize.small,
                  onPressed: () => _receiveAtDestination(d.id),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
