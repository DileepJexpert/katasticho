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
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Posted', value: 'POSTED'),
  KListTab(label: 'Cancelled', value: 'CANCELLED'),
];

class StockCountListScreen extends ConsumerStatefulWidget {
  const StockCountListScreen({super.key});

  @override
  ConsumerState<StockCountListScreen> createState() =>
      _StockCountListScreenState();
}

class _StockCountListScreenState extends ConsumerState<StockCountListScreen> {
  String? _status;
  String _search = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _counts = [];

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.stockCounts);
      final data = response.data['data'] ?? response.data;
      final content = data is Map ? (data['content'] as List?) ?? [] : data;
      _counts = (content as List)
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    } on DioException catch (e) {
      final body = e.response?.data;
      _error = (body is Map ? body['message'] as String? : null) ??
          'Failed to load stock counts';
    } catch (e) {
      _error = 'Failed to load stock counts';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _filteredCounts {
    return _counts.where((count) {
      final status = count['status']?.toString();
      if (_status != null && status != _status) return false;
      if (_search.isEmpty) return true;
      final haystack = [
        count['countNumber'],
        count['warehouseName'],
        count['notes'],
        count['status'],
      ].whereType<Object>().join(' ').toLowerCase();
      return haystack.contains(_search);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return KKeyboardListWrapper(
      itemCount: () => _filteredCounts.length,
      onNew: () async {
        await context.push(Routes.stockCountCreate);
        _fetchCounts();
      },
      onRefresh: () => _fetchCounts(),
      onOpen: (index) {
        final filtered = _filteredCounts;
        if (index >= 0 && index < filtered.length) {
          final id = filtered[index]['id']?.toString();
          if (id != null) context.push('/inventory/stock-counts/$id');
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            KListPageHeader(
              title: 'Stock Counts',
              searchHint: 'Search count number, warehouse...',
              tabs: _statusTabs,
              selectedTab: _status,
              onTabChanged: (value) => setState(() => _status = value),
              onSearchChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
            ),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            await context.push(Routes.stockCountCreate);
            _fetchCounts();
          },
          icon: const Icon(Icons.add),
          label: const Text('New Count'),
          tooltip: 'New Count (N)',
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const KShimmerList();

    if (_error != null) {
      return KErrorView(
        message: _error!,
        onRetry: _fetchCounts,
      );
    }

    if (_counts.isEmpty) {
      return KEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No stock counts yet',
        subtitle:
            'Perform a physical stock count to verify on-hand quantities against system records.',
        actionLabel: 'New Count',
        onAction: () async {
          await context.push(Routes.stockCountCreate);
          _fetchCounts();
        },
      );
    }

    final filtered = _filteredCounts;

    if (filtered.isEmpty) {
      return KEmptyState(
        icon: Icons.fact_check_outlined,
        title: 'No matching counts',
        subtitle: 'Try another status or search term.',
        actionLabel: 'Clear Filters',
        onAction: () => setState(() {
          _status = null;
          _search = '';
        }),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCounts,
      child: ListView.separated(
        padding: KSpacing.pagePadding,
        itemCount: filtered.length,
        separatorBuilder: (_, __) => KSpacing.vGapSm,
        itemBuilder: (context, index) {
          final count = filtered[index];
          return _StockCountCard(
            count: count,
            onTap: () async {
              final id = count['id']?.toString();
              if (id != null) {
                await context.push('/inventory/stock-counts/$id');
                _fetchCounts();
              }
            },
          );
        },
      ),
    );
  }
}

class _StockCountCard extends StatelessWidget {
  final Map<String, dynamic> count;
  final VoidCallback onTap;

  const _StockCountCard({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final countNumber = count['countNumber']?.toString() ?? '--';
    final warehouseName =
        count['warehouseName']?.toString() ?? 'Default Warehouse';
    final status = count['status']?.toString() ?? 'DRAFT';
    final dateRaw = count['countDate']?.toString();
    final lineCount = (count['lineCount'] as num?)?.toInt() ?? 0;
    final varianceCount = (count['varianceCount'] as num?)?.toInt() ?? 0;

    return KCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(countNumber, style: KTypography.labelLarge),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  warehouseName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
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
                    if (varianceCount > 0) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.warning_amber_rounded,
                          size: 12, color: KColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        '$varianceCount variance${varianceCount == 1 ? '' : 's'}',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.warning),
                      ),
                    ],
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
