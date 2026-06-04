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

class StockCountDetailScreen extends ConsumerStatefulWidget {
  const StockCountDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<StockCountDetailScreen> createState() =>
      _StockCountDetailScreenState();
}

class _StockCountDetailScreenState
    extends ConsumerState<StockCountDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _count;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchCount();
  }

  Future<void> _fetchCount() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiConfig.stockCountById(widget.id));
      final data = response.data['data'] ?? response.data;
      _count = data is Map<String, dynamic> ? data : null;
    } on DioException catch (e) {
      final body = e.response?.data;
      _error = (body is Map ? body['message'] as String? : null) ??
          'Failed to load stock count';
    } catch (e) {
      _error = 'Failed to load stock count';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _postCount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Stock Count?'),
        content: const Text(
          'Posting will record variance adjustments to the inventory ledger. '
          'This action cannot be undone. The stock count will move to POSTED status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Post Count'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.postStockCount(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock count posted successfully')),
        );
        _fetchCount();
      }
    } on DioException catch (e) {
      if (mounted) {
        final body = e.response?.data;
        final msg = (body is Map ? body['message'] as String? : null) ??
            'Failed to post stock count';
        _showErrorDialog('Post Failed', msg);
      }
    } catch (_) {
      if (mounted) {
        _showErrorDialog('Post Failed', 'An unexpected error occurred');
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _cancelCount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Stock Count?'),
        content: const Text(
          'This will mark the stock count as cancelled. '
          'No inventory adjustments will be made. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Count'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _actionInProgress = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post(ApiConfig.cancelStockCount(widget.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock count cancelled')),
        );
        _fetchCount();
      }
    } on DioException catch (e) {
      if (mounted) {
        final body = e.response?.data;
        final msg = (body is Map ? body['message'] as String? : null) ??
            'Failed to cancel stock count';
        _showErrorDialog('Cancel Failed', msg);
      }
    } catch (_) {
      if (mounted) {
        _showErrorDialog('Cancel Failed', 'An unexpected error occurred');
      }
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _count?['status']?.toString() ?? '';
    final isDraft = status == 'DRAFT';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Count'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.stockCounts),
        ),
        actions: [
          if (_count != null && isDraft)
            PopupMenuButton<String>(
              onSelected: (action) {
                if (action == 'cancel') _cancelCount();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel Count',
                      style: TextStyle(color: KColors.error)),
                ),
              ],
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar:
          (_count != null && isDraft) ? _buildBottomBar() : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const KLoading(message: 'Loading stock count...');
    }

    if (_error != null) {
      return KErrorView(
        message: _error!,
        onRetry: _fetchCount,
      );
    }

    if (_count == null) {
      return const KErrorView(message: 'Stock count not found');
    }

    final count = _count!;
    final countNumber = count['countNumber']?.toString() ?? '--';
    final warehouseName =
        count['warehouseName']?.toString() ?? 'Default Warehouse';
    final status = count['status']?.toString() ?? 'DRAFT';
    final dateRaw = count['countDate']?.toString();
    final notes = count['notes']?.toString();
    final postedAtRaw = count['postedAt']?.toString();
    final createdAtRaw = count['createdAt']?.toString();
    final lineCount = (count['lineCount'] as num?)?.toInt() ?? 0;
    final varianceCount = (count['varianceCount'] as num?)?.toInt() ?? 0;
    final lines =
        (count['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return RefreshIndicator(
      onRefresh: _fetchCount,
      child: ListView(
        padding: KSpacing.pagePadding,
        children: [
          // Document header
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: KSpacing.borderRadiusLg,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: KDocumentHeader(
              title: countNumber,
              subtitle: warehouseName,
              status: KStatusChip(status: status),
              icon: Icons.fact_check_outlined,
              metrics: [
                KDocumentHeaderMetric(
                  label: 'Lines',
                  value: lineCount.toString(),
                  icon: Icons.format_list_numbered,
                ),
                KDocumentHeaderMetric(
                  label: 'Variances',
                  value: varianceCount.toString(),
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Info panel
          KCard(
            title: 'Count Information',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (dateRaw != null)
                  KDetailRow(
                    label: 'Count Date',
                    value:
                        DateFormatter.display(DateTime.parse(dateRaw)),
                  ),
                KDetailRow(label: 'Warehouse', value: warehouseName),
                KDetailRow(label: 'Status', value: status),
                if (postedAtRaw != null)
                  KDetailRow(
                    label: 'Posted At',
                    value: DateFormatter.dateTime(
                        DateTime.parse(postedAtRaw)),
                  ),
                if (createdAtRaw != null)
                  KDetailRow(
                    label: 'Created',
                    value: DateFormatter.dateTime(
                        DateTime.parse(createdAtRaw)),
                  ),
                if (notes != null && notes.isNotEmpty) ...[
                  KSpacing.vGapMd,
                  _NotesBlock(notes: notes),
                ],
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Lines
          _buildLinesSection(lines),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLinesSection(List<Map<String, dynamic>> lines) {
    if (lines.isEmpty) {
      return KCard(
        title: 'Count Lines',
        child: KEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No count lines',
          subtitle: 'This stock count has no line items.',
        ),
      );
    }

    return KCard(
      title: 'Count Lines (${lines.length})',
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: KColors.draftBg,
              borderRadius: KSpacing.borderRadiusSm,
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Item',
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textSecondary)),
                ),
                Expanded(
                  child: Text('System',
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textSecondary),
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  child: Text('Counted',
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textSecondary),
                      textAlign: TextAlign.right),
                ),
                Expanded(
                  child: Text('Variance',
                      style: KTypography.labelSmall
                          .copyWith(color: KColors.textSecondary),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
          ),
          KSpacing.vGapXs,
          ...lines.map((line) => _CountLineRow(line: line)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: KColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _actionInProgress ? null : _cancelCount,
                style: OutlinedButton.styleFrom(
                  foregroundColor: KColors.error,
                  side: const BorderSide(color: KColors.error),
                ),
                child: const Text('Cancel'),
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              flex: 2,
              child: KButton(
                label: 'Post Count',
                icon: Icons.check_circle_outline,
                isLoading: _actionInProgress,
                onPressed: _actionInProgress ? null : _postCount,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountLineRow extends StatelessWidget {
  final Map<String, dynamic> line;

  const _CountLineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final itemName =
        line['itemName']?.toString() ?? 'Unknown Item';
    final sku = line['sku']?.toString() ?? '';
    final expected =
        (line['expectedQuantity'] as num?)?.toDouble() ?? 0;
    final counted =
        (line['countedQuantity'] as num?)?.toDouble() ?? 0;
    final variance = (line['variance'] as num?)?.toDouble() ??
        (counted - expected);
    final lineNotes = line['notes']?.toString();

    final varianceColor = variance > 0
        ? KColors.success
        : variance < 0
            ? KColors.error
            : KColors.textSecondary;

    final varianceBg = variance > 0
        ? KColors.successLight
        : variance < 0
            ? KColors.errorLight
            : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: KColors.divider.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: KTypography.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sku.isNotEmpty)
                      Text(
                        sku,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  _fmtQty(expected),
                  style: KTypography.amountSmall
                      .copyWith(color: KColors.textSecondary),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Text(
                  _fmtQty(counted),
                  style: KTypography.amountSmall,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: varianceBg,
                      borderRadius: KSpacing.borderRadiusSm,
                    ),
                    child: Text(
                      '${variance >= 0 ? '+' : ''}${_fmtQty(variance)}',
                      style: KTypography.amountSmall.copyWith(
                        color: varianceColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (lineNotes != null && lineNotes.isNotEmpty) ...[
            KSpacing.vGapXs,
            Row(
              children: [
                Icon(Icons.notes, size: 12, color: KColors.textHint),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lineNotes,
                    style: KTypography.bodySmall
                        .copyWith(color: KColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtQty(double q) =>
      q == q.truncateToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);
}

class _NotesBlock extends StatelessWidget {
  final String notes;

  const _NotesBlock({required this.notes});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notes', style: KTypography.labelMedium),
          KSpacing.vGapXs,
          Text(notes, style: KTypography.bodyMedium),
        ],
      ),
    );
  }
}
