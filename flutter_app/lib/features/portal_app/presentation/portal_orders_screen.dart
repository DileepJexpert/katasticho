import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/portal_reorder_models.dart';
import '../data/portal_session.dart';

class PortalOrdersScreen extends ConsumerStatefulWidget {
  const PortalOrdersScreen({super.key});

  @override
  ConsumerState<PortalOrdersScreen> createState() => _PortalOrdersScreenState();
}

class _PortalOrdersScreenState extends ConsumerState<PortalOrdersScreen> {
  bool _loading = true;
  String? _error;
  List<PortalOrderSummary> _orders = [];
  final Set<String> _expandedOrderIds = {};

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final dio = ref.read(portalDioProvider);
      final res = await dio.get(ApiConfig.portalOrders);
      if (!mounted) return;

      final rawList = (res.data['data'] as List?) ?? [];
      final parsed = rawList
          .map((e) => PortalOrderSummary.fromJson((e as Map).cast<String, dynamic>()))
          .toList();

      setState(() {
        _orders = parsed;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _extractError(e);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load your orders.';
        _loading = false;
      });
    }
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Unable to fetch orders. Please check your connection.';
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedOrderIds.contains(id)) {
        _expandedOrderIds.remove(id);
      } else {
        _expandedOrderIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KColors.bgApp,
      appBar: AppBar(
        title: const Text('My Reorder History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchOrders,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: KEmptyState(
                    icon: Icons.error_outline,
                    title: 'Unable to load orders',
                    subtitle: _error!,
                    actionLabel: 'Try Again',
                    onAction: _fetchOrders,
                  ),
                )
              : _orders.isEmpty
                  ? const Center(
                      child: KEmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'No Orders Placed Yet',
                        subtitle: 'Browse the distributor catalog to punch your first quick reorder.',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(KSpacing.md),
                        itemCount: _orders.length,
                        itemBuilder: (ctx, idx) => _buildOrderCard(_orders[idx]),
                      ),
                    ),
    );
  }

  Widget _buildOrderCard(PortalOrderSummary order) {
    final isExpanded = _expandedOrderIds.contains(order.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(order.number, style: KTypography.mono(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(width: KSpacing.xs),
                        KStatusChip(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (order.date.isNotEmpty) 'Ordered: ${order.date}',
                        if (order.referenceNumber != null) 'Ref: ${order.referenceNumber}',
                      ].join('  •  '),
                      style: KTypography.caption.copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
                KMoney(
                  order.total,
                  style: KTypography.h3.copyWith(color: KColors.primary),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            _buildFulfillmentTimeline(order),
            const SizedBox(height: KSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${order.itemCount} ${order.itemCount == 1 ? "item" : "items"} in order',
                  style: KTypography.caption.copyWith(color: KColors.textSecondary),
                ),
                TextButton.icon(
                  onPressed: () => _toggleExpand(order.id),
                  icon: Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                  label: Text(
                    isExpanded ? 'Hide Details' : 'View Items',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            if (isExpanded && order.lines.isNotEmpty) ...[
              const Divider(height: 1),
              const SizedBox(height: KSpacing.sm),
              ...order.lines.map(_buildLineRow),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: KSpacing.xs),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(KSpacing.xs),
                  decoration: BoxDecoration(
                    color: KColors.bgApp,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Notes: ${order.notes!}',
                    style: KTypography.caption.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFulfillmentTimeline(PortalOrderSummary order) {
    final steps = [
      {'label': 'Confirmed', 'done': true},
      {'label': 'Picked', 'done': order.shippedStatus != 'NOT_SHIPPED' || order.status == 'PARTIALLY_SHIPPED' || order.status == 'CLOSED'},
      {'label': 'Dispatched', 'done': order.shippedStatus == 'SHIPPED' || order.status == 'CLOSED'},
      {'label': 'Invoiced', 'done': order.invoicedStatus == 'INVOICED' || order.status == 'CLOSED'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: KColors.bgApp,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: steps.map((s) {
          final isDone = s['done'] as bool;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 14,
                color: isDone ? KColors.primary : KColors.textHint,
              ),
              const SizedBox(width: 4),
              Text(
                s['label'] as String,
                style: KTypography.caption.copyWith(
                  color: isDone ? KColors.textPrimary : KColors.textSecondary,
                  fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 11,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLineRow(PortalOrderLineSummary line) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.description, style: KTypography.bodyMedium),
                Text(
                  '${line.quantity.toInt()} ${line.unit ?? 'Units'} @ ₹${line.rate.toStringAsFixed(2)}${line.discountPct > 0 ? " (-${line.discountPct.toInt()}%)" : ""}',
                  style: KTypography.caption.copyWith(color: KColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          KMoney(line.amount, style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
