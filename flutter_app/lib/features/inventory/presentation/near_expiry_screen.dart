import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/expiry_repository.dart';

/// Near-Expiry Alert Dashboard — shows batches approaching or past their
/// expiry date, with urgency-based color coding and summary cards.
class NearExpiryScreen extends ConsumerStatefulWidget {
  const NearExpiryScreen({super.key});

  @override
  ConsumerState<NearExpiryScreen> createState() => _NearExpiryScreenState();
}

class _NearExpiryScreenState extends ConsumerState<NearExpiryScreen> {
  String? _activeFilter; // null = all, or 'EXPIRED', 'CRITICAL', 'WARNING', 'OK'
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(expirySummaryProvider);
    final batchesAsync = ref.watch(nearExpiryBatchesProvider(90));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Near-Expiry Alerts'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expirySummaryProvider);
          ref.invalidate(nearExpiryBatchesProvider(90));
        },
        child: CustomScrollView(
          slivers: [
            // Summary cards
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
                    onFilterTap: (filter) {
                      setState(() {
                        _activeFilter =
                            _activeFilter == filter ? null : filter;
                      });
                    },
                  );
                },
              ),
            ),

            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: KSpacing.md, vertical: KSpacing.sm),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by item name or batch number...',
                    prefixIcon:
                        const Icon(Icons.search, size: 20, color: KColors.textHint),
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

            // Batch list
            batchesAsync.when(
              loading: () => const SliverFillRemaining(
                child: KLoading(),
              ),
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

                if (filtered.isEmpty) {
                  return const SliverFillRemaining(
                    child: KEmptyState(
                      icon: Icons.check_circle_outline,
                      title: 'No expiring batches',
                      subtitle:
                          'All batch stock is well within its shelf life',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KSpacing.md, vertical: KSpacing.sm),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) =>
                        _ExpiryBatchCard(batch: filtered[index]),
                  ),
                );
              },
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilters(
      List<Map<String, dynamic>> batches) {
    var result = batches;

    // Urgency filter
    if (_activeFilter != null) {
      result = result
          .where((b) =>
              (b['urgency']?.toString() ?? '') == _activeFilter)
          .toList();
    }

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((b) {
        final itemName =
            (b['itemName']?.toString() ?? '').toLowerCase();
        final batchNumber =
            (b['batchNumber']?.toString() ?? '').toLowerCase();
        return itemName.contains(query) ||
            batchNumber.contains(query);
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
            color: const Color(0xFFEA580C), // orange-600
            bgColor: const Color(0xFFFFF7ED), // orange-50
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
    final width = (MediaQuery.of(context).size.width - KSpacing.md * 2 - KSpacing.sm) / 2;

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
                  Text(
                    '$count',
                    style: KTypography.h2.copyWith(color: color),
                  ),
                  Text(
                    label,
                    style: KTypography.labelSmall.copyWith(color: color),
                  ),
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

  const _ExpiryBatchCard({required this.batch});

  @override
  Widget build(BuildContext context) {
    final itemName = batch['itemName']?.toString() ?? 'Unknown Item';
    final batchNumber = batch['batchNumber']?.toString() ?? '';
    final expiryDateStr = batch['expiryDate']?.toString() ?? '';
    final quantity = (batch['quantityOnHand'] as num?)?.toDouble() ?? 0;
    final daysUntilExpiry = (batch['daysUntilExpiry'] as num?)?.toInt() ?? 0;
    final urgency = batch['urgency']?.toString() ?? 'OK';

    final color = _urgencyColor(urgency);
    final bgColor = _urgencyBgColor(urgency);

    String expiryLabel;
    if (daysUntilExpiry < 0) {
      expiryLabel = 'Expired ${-daysUntilExpiry} day${-daysUntilExpiry == 1 ? '' : 's'} ago';
    } else if (daysUntilExpiry == 0) {
      expiryLabel = 'Expires today';
    } else {
      expiryLabel = 'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
    }

    String formattedDate = '';
    if (expiryDateStr.isNotEmpty) {
      try {
        final date = DateTime.parse(expiryDateStr);
        formattedDate = DateFormat('dd MMM yyyy').format(date);
      } catch (_) {
        formattedDate = expiryDateStr;
      }
    }

    return KCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: bgColor,
            child: Icon(
              _urgencyIcon(urgency),
              size: 20,
              color: color,
            ),
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
                    Text(
                      formattedDate,
                      style: KTypography.bodySmall.copyWith(color: color),
                    ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Color _urgencyColor(String urgency) {
    return switch (urgency) {
      'EXPIRED' => KColors.error,
      'CRITICAL' => const Color(0xFFEA580C),
      'WARNING' => KColors.warning,
      _ => KColors.success,
    };
  }

  static Color _urgencyBgColor(String urgency) {
    return switch (urgency) {
      'EXPIRED' => KColors.errorLight,
      'CRITICAL' => const Color(0xFFFFF7ED),
      'WARNING' => KColors.warningLight,
      _ => KColors.successLight,
    };
  }

  static IconData _urgencyIcon(String urgency) {
    return switch (urgency) {
      'EXPIRED' => Icons.error_outline,
      'CRITICAL' => Icons.warning_amber_rounded,
      'WARNING' => Icons.schedule,
      _ => Icons.event_available,
    };
  }

  static String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(1);
}
