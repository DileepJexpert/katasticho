import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/expiry_repository.dart';

class NearExpiryScreen extends ConsumerStatefulWidget {
  const NearExpiryScreen({super.key});

  @override
  ConsumerState<NearExpiryScreen> createState() => _NearExpiryScreenState();
}

class _NearExpiryScreenState extends ConsumerState<NearExpiryScreen> {
  String? _activeFilter;
  String _searchQuery = '';
  int _daysThreshold = 90;
  final _searchController = TextEditingController();
  final Set<String> _selected = {}; // keys: batchId or "itemId:batchNumber"
  bool _isReturning = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _batchKey(Map<String, dynamic> b) =>
      b['batchId']?.toString() ?? '${b['itemId']}:${b['batchNumber']}';

  Future<void> _confirmReturn(List<Map<String, dynamic>> batches) async {
    final reasonCtl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Return to Supplier'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Return ${batches.length} batch${batches.length == 1 ? '' : 'es'} to supplier?\n'
              'This will deduct them from inventory.',
              style: KTypography.bodyMedium,
            ),
            KSpacing.vGapMd,
            TextField(
              controller: reasonCtl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Expired, near-expiry return',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: KColors.error),
            child: const Text('Return Stock'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isReturning = true);
    try {
      await ref.read(expiryRepositoryProvider).returnExpired(
            batches: batches,
            reason: reasonCtl.text.trim().isEmpty
                ? 'Expiry return'
                : reasonCtl.text.trim(),
          );
      if (!mounted) return;
      setState(() => _selected.clear());
      ref.invalidate(expirySummaryProvider);
      ref.invalidate(nearExpiryBatchesProvider(_daysThreshold));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${batches.length} batch${batches.length == 1 ? '' : 'es'} returned to supplier'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      String msg = 'Failed to process return';
      if (e is DioException) {
        final body = e.response?.data;
        if (body is Map) msg = body['message'] as String? ?? msg;
      }
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Return Failed'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isReturning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(expirySummaryProvider);
    final batchesAsync = ref.watch(nearExpiryBatchesProvider(_daysThreshold));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Near-Expiry Alerts'),
        actions: [
          if (_selected.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _selected.clear()),
              icon: const Icon(Icons.deselect, size: 18),
              label: Text('Clear (${_selected.length})'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expirySummaryProvider);
          ref.invalidate(nearExpiryBatchesProvider(_daysThreshold));
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: summaryAsync.when(
                loading: () => const Padding(
                  padding: KSpacing.pagePadding,
                  child: KLoading(),
                ),
                error: (err, _) => Padding(
                  padding: KSpacing.pagePadding,
                  child: KErrorView(
                    message: 'Failed to load summary: $err',
                    onRetry: () => ref.invalidate(expirySummaryProvider),
                  ),
                ),
                data: (raw) {
                  final data = raw['data'] ?? raw;
                  return _SummaryCards(
                    expired: (data['expired'] as num?)?.toInt() ?? 0,
                    within7Days: (data['within7Days'] as num?)?.toInt() ?? 0,
                    within30Days: (data['within30Days'] as num?)?.toInt() ?? 0,
                    within90Days: (data['within90Days'] as num?)?.toInt() ?? 0,
                    activeFilter: _activeFilter,
                    onFilterTap: (filter) => setState(
                        () => _activeFilter =
                            _activeFilter == filter ? null : filter),
                  );
                },
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    KSpacing.md, 0, KSpacing.md, KSpacing.sm),
                child: _ThresholdSelector(
                  value: _daysThreshold,
                  onChanged: (days) {
                    if (days == _daysThreshold) return;
                    setState(() {
                      _daysThreshold = days;
                      _selected.clear();
                    });
                  },
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.md, vertical: KSpacing.sm),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by item name or batch number...',
                    prefixIcon: const Icon(Icons.search,
                        size: 20, color: KColors.textHint),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: KSpacing.borderRadiusMd,
                      borderSide: const BorderSide(color: KColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: KSpacing.borderRadiusMd,
                      borderSide: const BorderSide(color: KColors.divider),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
            ),

            batchesAsync.when(
              loading: () =>
                  const SliverFillRemaining(child: KLoading()),
              error: (err, _) => SliverFillRemaining(
                child: KErrorView(
                  message: 'Failed to load expiry batches: $err',
                  onRetry: () =>
                      ref.invalidate(nearExpiryBatchesProvider(90)),
                ),
              ),
              data: (raw) {
                final data = raw['data'] ?? raw;
                final batches = (data is List
                        ? data
                        : (data is Map
                            ? (data['content'] as List?) ?? []
                            : []))
                    .cast<Map<String, dynamic>>();

                final filtered = _applyFilters(batches);

                final visibleQty = filtered.fold<double>(
                  0,
                  (sum, batch) =>
                      sum + ((batch['quantityOnHand'] as num?)?.toDouble() ?? 0),
                );
                final selectedCount = filtered
                    .where((batch) => _selected.contains(_batchKey(batch)))
                    .length;

                final grouped = <String, List<Map<String, dynamic>>>{
                  'EXPIRED': [],
                  'CRITICAL': [],
                  'WARNING': [],
                  'OK': [],
                };
                for (final batch in filtered) {
                  final urgency = batch['urgency']?.toString() ?? 'OK';
                  grouped.putIfAbsent(urgency, () => []).add(batch);
                }

                if (filtered.isEmpty) {
                  return SliverFillRemaining(
                    child: KEmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'No batches in $_daysThreshold days',
                      subtitle:
                          'Try a larger window or clear your filters to see more stock at risk.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md, vertical: KSpacing.sm),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ExpiryOverviewCard(
                        totalBatches: filtered.length,
                        totalQuantity: visibleQty,
                        selectedCount: selectedCount,
                        daysThreshold: _daysThreshold,
                        activeFilter: _activeFilter,
                        searchQuery: _searchQuery,
                      ),
                      KSpacing.vGapSm,
                      for (final entry in grouped.entries)
                        if (entry.value.isNotEmpty) ...[
                          _ExpirySectionHeader(
                            urgency: entry.key,
                            count: entry.value.length,
                          ),
                          KSpacing.vGapXs,
                          for (final batch in entry.value) ...[
                            _ExpiryBatchCard(
                              batch: batch,
                              isSelected: _selected.contains(_batchKey(batch)),
                              onToggle: () => setState(() {
                                final key = _batchKey(batch);
                                if (_selected.contains(key)) {
                                  _selected.remove(key);
                                } else {
                                  _selected.add(key);
                                }
                              }),
                              onOpenItem: () {
                                final itemId = batch['itemId']?.toString();
                                if (itemId == null || itemId.isEmpty) return;
                                context.push(Routes.itemDetail.replaceFirst(':id', itemId));
                              },
                              onReturnNow: _isReturning
                                  ? null
                                  : () => _confirmReturn([batch]),
                            ),
                            KSpacing.vGapSm,
                          ],
                        ],
                    ]),
                  ),
                );
              },
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
      floatingActionButton: _selected.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _isReturning
                  ? null
                  : () {
                      final batchesAsync2 =
                          ref.read(nearExpiryBatchesProvider(90));
                      final raw = batchesAsync2.valueOrNull;
                      if (raw == null) return;
                      final data = raw['data'] ?? raw;
                      final allBatches = (data is List
                              ? data
                              : (data is Map
                                  ? (data['content'] as List?) ?? []
                                  : []))
                          .cast<Map<String, dynamic>>();
                      final selected = allBatches
                          .where((b) => _selected.contains(_batchKey(b)))
                          .toList();
                      _confirmReturn(selected);
                    },
              icon: _isReturning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.assignment_return_outlined),
              label: Text('Return to Supplier (${_selected.length})'),
              backgroundColor: KColors.error,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> batches) {
    var result = batches;
    if (_activeFilter != null) {
      result = result
          .where((b) => (b['urgency']?.toString() ?? '') == _activeFilter)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((b) {
        return (b['itemName']?.toString() ?? '').toLowerCase().contains(q) ||
            (b['batchNumber']?.toString() ?? '').toLowerCase().contains(q);
      }).toList();
    }
    return result;
  }
}

// ── Summary Cards ──

class _SummaryCards extends StatelessWidget {
  final int expired;
  final int within7Days;
  final int within30Days;
  final int within90Days;
  final String? activeFilter;
  final ValueChanged<String> onFilterTap;

  const _SummaryCards({
    required this.expired,
    required this.within7Days,
    required this.within30Days,
    required this.within90Days,
    required this.activeFilter,
    required this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Wrap(
        spacing: KSpacing.sm,
        runSpacing: KSpacing.sm,
        children: [
          _SummaryCard(
            label: 'Expired',
            count: expired,
            color: KColors.error,
            bgColor: KColors.errorLight,
            icon: Icons.error_outline,
            isActive: activeFilter == 'EXPIRED',
            onTap: () => onFilterTap('EXPIRED'),
          ),
          _SummaryCard(
            label: '< 7 Days',
            count: within7Days,
            color: const Color(0xFFEA580C),
            bgColor: const Color(0xFFFFF7ED),
            icon: Icons.warning_amber_rounded,
            isActive: activeFilter == 'CRITICAL',
            onTap: () => onFilterTap('CRITICAL'),
          ),
          _SummaryCard(
            label: '< 30 Days',
            count: within30Days,
            color: KColors.warning,
            bgColor: KColors.warningLight,
            icon: Icons.schedule,
            isActive: activeFilter == 'WARNING',
            onTap: () => onFilterTap('WARNING'),
          ),
          _SummaryCard(
            label: '< 90 Days',
            count: within90Days,
            color: KColors.success,
            bgColor: KColors.successLight,
            icon: Icons.event_available,
            isActive: activeFilter == 'OK',
            onTap: () => onFilterTap('OK'),
          ),
        ],
      ),
    );
  }
}

class _ThresholdSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ThresholdSelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const windows = [30, 60, 90, 180];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review window', style: KTypography.labelMedium),
        KSpacing.vGapXs,
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: windows
              .map(
                (days) => ChoiceChip(
                  label: Text('$days days'),
                  selected: value == days,
                  onSelected: (_) => onChanged(days),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ExpiryOverviewCard extends StatelessWidget {
  final int totalBatches;
  final double totalQuantity;
  final int selectedCount;
  final int daysThreshold;
  final String? activeFilter;
  final String searchQuery;

  const _ExpiryOverviewCard({
    required this.totalBatches,
    required this.totalQuantity,
    required this.selectedCount,
    required this.daysThreshold,
    required this.activeFilter,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    final filters = <String>[
      'Window: $daysThreshold days',
      if (activeFilter != null) 'Urgency: ${_labelForUrgency(activeFilter!)}',
      if (searchQuery.trim().isNotEmpty) 'Search: "${searchQuery.trim()}"',
    ];
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Batches needing attention',
                        style: KTypography.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      '$totalBatches batch${totalBatches == 1 ? '' : 'es'} - ${_fmtQtyCompact(totalQuantity)} units at risk',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (selectedCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: KColors.primarySoft.withValues(alpha: 0.16),
                    borderRadius: KSpacing.borderRadiusSm,
                  ),
                  child: Text(
                    '$selectedCount selected',
                    style: KTypography.labelSmall
                        .copyWith(color: KColors.primary),
                  ),
                ),
            ],
          ),
          KSpacing.vGapSm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filters
                .map(
                  (filter) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: KColors.draftBg,
                      borderRadius: KSpacing.borderRadiusSm,
                    ),
                    child: Text(filter, style: KTypography.labelSmall),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

String _labelForUrgency(String urgency) => switch (urgency) {
      'EXPIRED' => 'Expired',
      'CRITICAL' => 'Critical (7d)',
      'WARNING' => 'Warning (30d)',
      _ => 'Monitor',
    };

String _fmtQtyCompact(double q) =>
    q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);

class _ExpirySectionHeader extends StatelessWidget {
  final String urgency;
  final int count;

  const _ExpirySectionHeader({
    required this.urgency,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final color = _ExpiryBatchCard._urgencyColor(urgency);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          KSpacing.hGapSm,
          Text(
            _labelForUrgency(urgency),
            style: KTypography.labelLarge.copyWith(color: color),
          ),
          KSpacing.hGapXs,
          Text(
            '($count)',
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width =
        (MediaQuery.of(context).size.width - KSpacing.md * 2 - KSpacing.sm) /
            2;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: KSpacing.borderRadiusMd,
          border: Border.all(
            color: isActive ? color : Colors.transparent,
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive ? KSpacing.shadowSm : null,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, size: 18, color: color),
            ),
            KSpacing.hGapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$count', style: KTypography.h2.copyWith(color: color)),
                  Text(label,
                      style:
                          KTypography.labelSmall.copyWith(color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Batch Item Card ──

class _ExpiryBatchCard extends StatelessWidget {
  final Map<String, dynamic> batch;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback onOpenItem;
  final VoidCallback? onReturnNow;

  const _ExpiryBatchCard({
    required this.batch,
    required this.isSelected,
    required this.onToggle,
    required this.onOpenItem,
    this.onReturnNow,
  });

  @override
  Widget build(BuildContext context) {
    final itemName = batch['itemName']?.toString() ?? 'Unknown Item';
    final batchNumber = batch['batchNumber']?.toString() ?? '';
    final expiryDateStr = batch['expiryDate']?.toString() ?? '';
    final quantity = (batch['quantityOnHand'] as num?)?.toDouble() ?? 0;
    final daysUntilExpiry =
        (batch['daysUntilExpiry'] as num?)?.toInt() ?? 0;
    final urgency = batch['urgency']?.toString() ?? 'OK';

    final color = _urgencyColor(urgency);
    final bgColor = _urgencyBgColor(urgency);

    String expiryLabel;
    if (daysUntilExpiry < 0) {
      expiryLabel =
          'Expired ${-daysUntilExpiry} day${-daysUntilExpiry == 1 ? '' : 's'} ago';
    } else if (daysUntilExpiry == 0) {
      expiryLabel = 'Expires today';
    } else {
      expiryLabel =
          'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
    }

    String formattedDate = '';
    if (expiryDateStr.isNotEmpty) {
      try {
        formattedDate =
            DateFormat('dd MMM yyyy').format(DateTime.parse(expiryDateStr));
      } catch (_) {
        formattedDate = expiryDateStr;
      }
    }

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected
              ? KColors.primarySoft.withValues(alpha: 0.15)
              : Colors.white,
          borderRadius: KSpacing.borderRadiusMd,
          border: Border.all(
            color: isSelected ? KColors.primary : KColors.divider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => onToggle(),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              activeColor: KColors.primary,
            ),
            KSpacing.hGapXs,
            CircleAvatar(
              radius: 18,
              backgroundColor: bgColor,
              child: Icon(_urgencyIcon(urgency), size: 18, color: color),
            ),
            KSpacing.hGapSm,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(itemName, style: KTypography.labelLarge),
                  KSpacing.vGapXxs,
                  Row(
                    children: [
                      Text(
                        'Batch: $batchNumber',
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                      const Spacer(),
                      Text(
                        'Qty: ${_fmtQty(quantity)}',
                        style: KTypography.labelSmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Icon(Icons.event, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(formattedDate,
                          style:
                              KTypography.bodySmall.copyWith(color: color)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: KSpacing.borderRadiusSm,
                        ),
                        child: Text(
                          expiryLabel,
                          style: KTypography.labelSmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapSm,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: onOpenItem,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Item'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onReturnNow,
                        icon: const Icon(Icons.assignment_return_outlined,
                            size: 16),
                        label: const Text('Return'),
                      ),
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

  static Color _urgencyColor(String urgency) => switch (urgency) {
        'EXPIRED' => KColors.error,
        'CRITICAL' => const Color(0xFFEA580C),
        'WARNING' => KColors.warning,
        _ => KColors.success,
      };

  static Color _urgencyBgColor(String urgency) => switch (urgency) {
        'EXPIRED' => KColors.errorLight,
        'CRITICAL' => const Color(0xFFFFF7ED),
        'WARNING' => KColors.warningLight,
        _ => KColors.successLight,
      };

  static IconData _urgencyIcon(String urgency) => switch (urgency) {
        'EXPIRED' => Icons.error_outline,
        'CRITICAL' => Icons.warning_amber_rounded,
        'WARNING' => Icons.schedule,
        _ => Icons.event_available,
      };

  static String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
}
