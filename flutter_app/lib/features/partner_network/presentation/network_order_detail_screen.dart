import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/widgets.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(partnerNetworkRepositoryProvider);
      final order = await repo.getOrder(widget.orderId);
      final events = await repo.getOrderEvents(widget.orderId);
      if (mounted) setState(() { _order = order; _events = events; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) return Scaffold(body: KErrorView(message: _error!, onRetry: _load));
    if (_order == null) return const Scaffold(body: KErrorView(message: 'Order not found'));

    final order = _order!;
    final status = order['status']?.toString() ?? '';
    final lines = (order['lines'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(order['orderNumber']?.toString() ?? 'Order'),
        actions: [
          if (status == 'PLACED')
            PopupMenuButton<String>(
              onSelected: (action) => _handleAction(action),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'confirm', child: Text('Confirm')),
                const PopupMenuItem(value: 'reject', child: Text('Reject')),
                const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
              ],
            ),
          if (status.contains('CONFIRMED'))
            IconButton(
              icon: const Icon(Icons.local_shipping),
              tooltip: 'Mark Dispatched',
              onPressed: () => _handleAction('dispatch'),
            ),
          if (status == 'DISPATCHED')
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Mark Delivered',
              onPressed: () => _handleAction('deliver'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Status header
            KCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('Status', style: theme.textTheme.labelMedium)),
                        KStatusChip(label: status),
                      ],
                    ),
                    const Divider(height: 20),
                    _InfoRow('Buyer', order['buyerOrgName']?.toString() ?? 'Unknown'),
                    _InfoRow('Seller', order['sellerOrgName']?.toString() ?? 'Unknown'),
                    if (order['totalAmount'] != null)
                      _InfoRow('Total', '₹${order['totalAmount']}'),
                    if (order['requestedDeliveryDate'] != null)
                      _InfoRow('Delivery Date', order['requestedDeliveryDate'].toString()),
                    if (order['buyerNotes'] != null)
                      _InfoRow('Buyer Notes', order['buyerNotes'].toString()),
                    if (order['sellerNotes'] != null)
                      _InfoRow('Seller Notes', order['sellerNotes'].toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lines
            Text('Order Lines', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...lines.map((line) => KCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(
                          line['displayName']?.toString() ?? 'Item',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                        )),
                        KStatusChip(label: line['status']?.toString() ?? ''),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 16,
                      children: [
                        Text('Ordered: ${line['orderedQty']}', style: theme.textTheme.bodySmall),
                        if (line['confirmedQty'] != null)
                          Text('Confirmed: ${line['confirmedQty']}', style: theme.textTheme.bodySmall),
                        Text('@ ₹${line['unitPrice']}', style: theme.textTheme.bodySmall),
                        if (line['lineTotal'] != null)
                          Text('Total: ₹${line['lineTotal']}',
                              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            )),

            // Events timeline
            if (_events.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Activity', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...(_events.map((event) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.circle, size: 8, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (event['eventType']?.toString() ?? '').replaceAll('_', ' '),
                            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            event['createdAt']?.toString().substring(0, 19) ?? '',
                            style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(String action) async {
    final repo = ref.read(partnerNetworkRepositoryProvider);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order ${action}ed'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey))),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
