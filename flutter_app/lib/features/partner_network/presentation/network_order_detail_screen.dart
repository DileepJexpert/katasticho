import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/partner_network_repository.dart';

class NetworkOrderDetailScreen extends ConsumerStatefulWidget {
  const NetworkOrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<NetworkOrderDetailScreen> createState() => _NetworkOrderDetailScreenState();
}

class _NetworkOrderDetailScreenState extends ConsumerState<NetworkOrderDetailScreen> {
  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(partnerNetworkRepositoryProvider);
      final order = await repo.getOrder(widget.orderId);
      final events = await repo.getOrderEvents(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _events = events;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = ApiErrorParser.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: KLoading(message: 'Loading network order details...'),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: Padding(
          padding: KSpacing.pagePadding,
          child: KErrorView(message: _error!, onRetry: _load),
        ),
      );
    }
    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Padding(
          padding: KSpacing.pagePadding,
          child: KErrorView(message: 'Network order record not found'),
        ),
      );
    }

    final order = _order!;
    final status = (order['status'] ?? 'PLACED').toString().toUpperCase();
    final orderNumber = order['orderNumber']?.toString() ?? 'Network Order';
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final lines = (order['lines'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          orderNumber,
          style: KTypography.mono(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (status == 'PLACED') ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: KButton.primary(
                label: 'Confirm Order',
                icon: Icons.check_rounded,
                size: KButtonSize.small,
                isLoading: _actionLoading,
                onPressed: () => _handleAction('confirm'),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) => _handleAction(action),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Reject Order'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.close_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Cancel Order'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (status.contains('CONFIRMED'))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: KButton.primary(
                label: 'Mark Dispatched',
                icon: Icons.local_shipping_outlined,
                size: KButtonSize.small,
                isLoading: _actionLoading,
                onPressed: () => _handleAction('dispatch'),
              ),
            ),
          if (status == 'DISPATCHED')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: KButton.primary(
                label: 'Mark Delivered',
                icon: Icons.check_circle_outline_rounded,
                size: KButtonSize.small,
                isLoading: _actionLoading,
                onPressed: () => _handleAction('deliver'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: KSpacing.pagePadding,
          children: [
            // Order Summary Card
            KCard(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              orderNumber,
                              style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Electronic B2B Network Order',
                              style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      KStatusChip(
                        status: status,
                        label: status.replaceAll('_', ' '),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _DetailItem('Buyer Org', order['buyerOrgName']?.toString() ?? 'Unknown Buyer'),
                      _DetailItem('Seller Org', order['sellerOrgName']?.toString() ?? 'Unknown Seller'),
                      _DetailWidget(
                        'Total Order Value',
                        KMoney(totalAmount, style: KTypography.titleMedium.copyWith(color: KColors.primary, fontWeight: FontWeight.w700)),
                      ),
                      if (order['requestedDeliveryDate'] != null)
                        _DetailItem('Delivery Date', order['requestedDeliveryDate'].toString()),
                    ],
                  ),
                  if (order['buyerNotes'] != null && order['buyerNotes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes_rounded, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Buyer Notes: ${order['buyerNotes']}',
                              style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (order['sellerNotes'] != null && order['sellerNotes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.edit_note_rounded, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Seller Notes: ${order['sellerNotes']}',
                              style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            KSpacing.vGapLg,

            // Line Items
            Text(
              'Order Line Items (${lines.length})',
              style: KTypography.h3,
            ),
            KSpacing.vGapSm,
            ...lines.map((line) {
              final lineStatus = line['status']?.toString() ?? '';
              final unitPrice = (line['unitPrice'] as num?)?.toDouble() ?? 0.0;
              final lineTotal = (line['lineTotal'] as num?)?.toDouble() ?? 0.0;
              final orderedQty = line['orderedQty'] ?? 0;
              final confirmedQty = line['confirmedQty'];

              return KCard(
                margin: const EdgeInsets.only(bottom: KSpacing.sm),
                padding: const EdgeInsets.all(KSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  line['displayName']?.toString() ?? 'Item',
                                  style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (lineStatus.isNotEmpty)
                                KStatusChip(status: lineStatus),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Ordered: $orderedQty units',
                                style: KTypography.bodySmall,
                              ),
                              if (confirmedQty != null)
                                Text(
                                  'Confirmed: $confirmedQty units',
                                  style: KTypography.bodySmall.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: KColors.success,
                                  ),
                                ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Rate: ', style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                                  KMoney(unitPrice, style: KTypography.bodySmall),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Line Total: ', style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                                  KMoney(lineTotal, style: KTypography.titleSmall),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Activity Timeline
            if (_events.isNotEmpty) ...[
              KSpacing.vGapLg,
              Text(
                'EDI Transmission & Status Timeline',
                style: KTypography.h3,
              ),
              KSpacing.vGapSm,
              KCard(
                padding: const EdgeInsets.all(KSpacing.md),
                child: Column(
                  children: _events.map((event) {
                    final eventType = (event['eventType']?.toString() ?? '').replaceAll('_', ' ');
                    final createdAt = event['createdAt']?.toString() ?? '';
                    final cleanTime = createdAt.length > 19 ? createdAt.substring(0, 19) : createdAt;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: KColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  eventType,
                                  style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  cleanTime,
                                  style: KTypography.mono(fontSize: 11, color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String action) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(partnerNetworkRepositoryProvider);
    setState(() => _actionLoading = true);
    try {
      switch (action) {
        case 'confirm':
          final lines = (_order?['lines'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];
          await repo.confirmOrder(widget.orderId, {
            'lines': lines.map((l) => {
              'lineId': l['id'],
              'confirmedQty': l['orderedQty'],
            }).toList(),
          });
        case 'reject':
          await repo.rejectOrder(widget.orderId, reason: 'Rejected by seller');
        case 'cancel':
          await repo.cancelOrder(widget.orderId);
        case 'dispatch':
          await repo.markDispatched(widget.orderId);
        case 'deliver':
          await repo.markDelivered(widget.orderId);
      }
      ref.invalidate(incomingOrdersProvider);
      ref.invalidate(outgoingOrdersProvider);
      await _load();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Order ${action}ed successfully'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Action failed: ${ApiErrorParser.message(e)}'),
          backgroundColor: KColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DetailWidget extends StatelessWidget {
  final String label;
  final Widget widget;
  const _DetailWidget(this.label, this.widget);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KTypography.labelSmall.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        widget,
      ],
    );
  }
}
