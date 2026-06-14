import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'In Transit', value: 'IN_TRANSIT'),
  KListTab(label: 'Received', value: 'RECEIVED'),
  KListTab(label: 'Cancelled', value: 'CANCELLED'),
];

class TransferOrderListScreen extends ConsumerStatefulWidget {
  const TransferOrderListScreen({super.key});

  @override
  ConsumerState<TransferOrderListScreen> createState() =>
      _TransferOrderListScreenState();
}

class _TransferOrderListScreenState
    extends ConsumerState<TransferOrderListScreen> {
  String? _status;
  String _search = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];

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
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.transferOrders);
      final data = response.data['data'] ?? response.data;
      final content = data is Map ? (data['content'] as List?) ?? [] : data;
      _orders = (content as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } on DioException catch (e) {
      final body = e.response?.data;
      _error = (body is Map ? body['message'] as String? : null) ??
          'Failed to load transfer orders';
    } catch (e) {
      _error = 'Failed to load transfer orders';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredOrders {
    return _orders.where((order) {
      final status = order['status']?.toString();
      if (_status != null && status != _status) return false;
      if (_search.isEmpty) return true;
      final haystack = [
        order['transferNumber'],
        order['fromWarehouseName'],
        order['toWarehouseName'],
        order['notes'],
        order['status'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(_search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardListWrapper(
      itemCount: () => _filteredOrders.length,
      onNew: () async {
        await context.push(Routes.transferOrderCreate);
        _fetchOrders();
      },
      onRefresh: () => _fetchOrders(),
      onOpen: (index) {
        final filtered = _filteredOrders;
        if (index >= 0 && index < filtered.length) {
          final id = filtered[index]['id']?.toString();
          if (id != null) context.push('/inventory/transfer-orders/$id');
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            KListPageHeader(
              title: 'Transfer Orders',
              searchHint: 'Search transfer number, warehouse...',
              tabs: _statusTabs,
              selectedTab: _status,
              onTabChanged: (value) => setState(() => _status = value),
              onSearchChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await context.push(Routes.transferOrderCreate);
            _fetchOrders();
          },
          icon: const Icon(Icons.add),
          label: const Text('New Transfer'),
          tooltip: 'New Transfer (N)',
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const KShimmerList();

    if (_error != null) {
      return KErrorView(
        message: _error!,
        onRetry: _fetchOrders,
      );
    }

    if (_orders.isEmpty) {
      return KEmptyState(
        icon: Icons.swap_horiz_outlined,
        title: 'No transfer orders yet',
        subtitle:
            'Create a transfer order to move stock between warehouses.',
        actionLabel: 'New Transfer',
        onAction: () async {
          await context.push(Routes.transferOrderCreate);
          _fetchOrders();
        },
      );
    }

    final filtered = _filteredOrders;

    if (filtered.isEmpty) {
      return KEmptyState(
        icon: Icons.swap_horiz_outlined,
        title: 'No matching transfer orders',
        subtitle: 'Try another status or search term.',
        actionLabel: 'Clear Filters',
        onAction: () => setState(() {
          _status = null;
          _search = '';
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (context, index) {
          final order = filtered[index];
          return _TransferOrderCard(
            order: order,
            onTap: () async {
              final id = order['id']?.toString();
              if (id != null) {
                await context.push('/inventory/transfer-orders/$id');
                _fetchOrders();
              }
            },
          );
        },
      ),
    );
  }
}

class _TransferOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;

  const _TransferOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final transferNumber = order['transferNumber']?.toString() ?? '--';
    final fromWarehouse =
        order['fromWarehouseName']?.toString() ?? 'Unknown';
    final toWarehouse =
        order['toWarehouseName']?.toString() ?? 'Unknown';
    final status = order['status']?.toString() ?? 'DRAFT';
    final dateRaw = order['transferDate']?.toString();
    final lineCount = (order['lineCount'] as num?)?.toInt() ?? 0;

    return KCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: KColors.primaryLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.swap_horiz_outlined,
                color: KColors.primary, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(transferNumber,
                          style: KTypography.labelLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$fromWarehouse  →  $toWarehouse',
                        style: KTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    if (dateRaw != null) ...[
                      Icon(Icons.calendar_today,
                          size: 12, color: KColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateFormatter.display(DateTime.parse(dateRaw)),
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.list_alt,
                        size: 12, color: KColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      '$lineCount item${lineCount == 1 ? '' : 's'}',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}
