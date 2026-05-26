import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/report_repository.dart';

class OperationalReportScreen extends ConsumerStatefulWidget {
  final String reportKey;
  final String fallbackTitle;
  final bool dateRange;

  const OperationalReportScreen({
    super.key,
    required this.reportKey,
    required this.fallbackTitle,
    this.dateRange = true,
  });

  @override
  ConsumerState<OperationalReportScreen> createState() =>
      _OperationalReportScreenState();
}

class _OperationalReportScreenState
    extends ConsumerState<OperationalReportScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  late Future<Map<String, dynamic>> _future;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _stockTypeFilter = 'ALL';
  bool _onlyBatchRows = false;
  List<Map<String, dynamic>> _exportColumns = const [];
  List<Map<String, dynamic>> _exportRows = const [];

  bool get _isStockMovement => widget.reportKey == 'stock-movement';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() {
        return ref.read(reportRepositoryProvider).getOperationalReport(
          key: widget.reportKey,
          startDate: widget.dateRange ? DateFormatter.api(_startDate) : null,
          endDate: widget.dateRange ? DateFormatter.api(_endDate) : null,
        );
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyStockFilters(List<Map<String, dynamic>> rows) {
    var result = rows;
    if (_stockTypeFilter != 'ALL') {
      result = result
          .where((row) => (row['type']?.toString() ?? '') == _stockTypeFilter)
          .toList();
    }
    if (_onlyBatchRows) {
      result = result
          .where((row) => (row['batch']?.toString() ?? '').trim().isNotEmpty)
          .toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      result = result.where((row) {
        return [
          row['sku'],
          row['item'],
          row['warehouse'],
          row['batch'],
          row['reference'],
          row['expiry'],
        ].any((value) => (value?.toString() ?? '').toLowerCase().contains(q));
      }).toList();
    }
    return result;
  }

  Future<void> _exportCsv() async {
    if (_exportColumns.isEmpty || _exportRows.isEmpty) return;
    final csv = _toCsv(_exportColumns, _exportRows);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Copied ${_exportRows.length} row${_exportRows.length == 1 ? '' : 's'} as CSV'),
      ),
    );
  }

  String _toCsv(List<Map<String, dynamic>> columns, List<Map<String, dynamic>> rows) {
    final header = columns
        .map((c) => _escapeCsv(c['label']?.toString() ?? c['key']?.toString() ?? ''))
        .join(',');
    final lines = rows.map((row) {
      return columns
          .map((c) => _escapeCsv(_formatValue(row[c['key']], c['type']?.toString())))
          .join(',');
    });
    return ([header, ...lines]).join('\n');
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/reports');
            }
          },
        ),
        title: Text(widget.fallbackTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Copy filtered CSV',
            onPressed: _exportRows.isEmpty ? null : _exportCsv,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const KLoading();
          }
          if (snapshot.hasError) {
            return KErrorView(
              message: 'Failed to load ${widget.fallbackTitle}',
              onRetry: _refresh,
            );
          }

          final payload = snapshot.data?['data'] as Map<String, dynamic>? ?? {};
          final columns = ((payload['columns'] as List?) ?? const [])
              .map((c) => (c as Map).cast<String, dynamic>())
              .toList();
          final rawRows = ((payload['rows'] as List?) ?? const [])
              .map((r) => (r as Map).cast<String, dynamic>())
              .toList();
          final visibleRows = _isStockMovement
              ? _applyStockFilters(rawRows)
              : rawRows;
          _exportColumns = columns;
          _exportRows = visibleRows;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: KSpacing.pagePadding,
              children: [
                _Header(
                  title: payload['title']?.toString() ?? widget.fallbackTitle,
                  description: payload['description']?.toString() ?? '',
                  startDate: _startDate,
                  endDate: _endDate,
                  showDateRange: widget.dateRange,
                  onStartChanged: (value) {
                    setState(() => _startDate = value);
                    _refresh();
                  },
                  onEndChanged: (value) {
                    setState(() => _endDate = value);
                    _refresh();
                  },
                ),
                KSpacing.vGapLg,
                _Metrics(metrics: (payload['metrics'] as List?) ?? const []),
                KSpacing.vGapLg,
                if (_isStockMovement)
                  _StockMovementToolbar(
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    stockTypeFilter: _stockTypeFilter,
                    onlyBatchRows: _onlyBatchRows,
                    totalRows: rawRows.length,
                    visibleRows: visibleRows.length,
                    onSearchChanged: (value) =>
                        setState(() => _searchQuery = value),
                    onTypeChanged: (value) =>
                        setState(() => _stockTypeFilter = value),
                    onToggleBatchOnly: (value) =>
                        setState(() => _onlyBatchRows = value),
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                        _stockTypeFilter = 'ALL';
                        _onlyBatchRows = false;
                      });
                    },
                  ),
                if (_isStockMovement) KSpacing.vGapLg,
                _ReportTable(
                  title: 'Detailed Rows',
                  columns: columns,
                  rows: visibleRows,
                  dense: _isStockMovement,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final bool showDateRange;
  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;

  const _Header({
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.showDateRange,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= KSpacing.tabletBreakpoint;
          final titleBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _reportAccent(title).withValues(alpha: 0.12),
                      borderRadius: KSpacing.borderRadiusMd,
                    ),
                    child: Icon(
                      _reportIcon(title),
                      color: _reportAccent(title),
                      size: 18,
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(child: Text(title, style: KTypography.h2)),
                ],
              ),
              if (description.isNotEmpty) ...[
                KSpacing.vGapXs,
                Text(
                  description,
                  style: KTypography.bodyMedium.copyWith(
                    color: KColors.textSecondary,
                  ),
                ),
              ],
            ],
          );

          if (!showDateRange) return titleBlock;

          final controls = Row(
            children: [
              Expanded(
                child: KDatePicker(
                  label: 'From',
                  value: startDate,
                  onChanged: onStartChanged,
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: KDatePicker(
                  label: 'To',
                  value: endDate,
                  firstDate: startDate,
                  onChanged: onEndChanged,
                ),
              ),
            ],
          );

          if (!wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [titleBlock, KSpacing.vGapMd, controls],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleBlock),
              SizedBox(width: 420, child: controls),
            ],
          );
        },
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  final List metrics;

  const _Metrics({required this.metrics});

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final metricItems = metrics.map<Widget>((raw) {
          final metric = (raw as Map).cast<String, dynamic>();
          return _MetricStripItem(
            label: metric['label']?.toString() ?? '',
            value: _formatValue(
              metric['value'],
              metric['format']?.toString(),
            ),
          );
        }).toList();

        final child = width >= 820
            ? Row(
                children: [
                  for (var i = 0; i < metricItems.length; i++) ...[
                    if (i > 0) KSpacing.hGapSm,
                    Expanded(child: metricItems[i]),
                  ],
                ],
              )
            : Wrap(
                spacing: KSpacing.sm,
                runSpacing: KSpacing.sm,
                children: metricItems
                    .map(
                      (item) => SizedBox(
                        width: _tileWidth(width),
                        child: item,
                      ),
                    )
                    .toList(),
              );

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.28),
            borderRadius: KSpacing.borderRadiusLg,
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
          child: child,
        );
      },
    );
  }

  double _tileWidth(double width) {
    final columns = width >= KSpacing.tabletBreakpoint ? 3 : 2;
    return (width - 16 - ((columns - 1) * KSpacing.sm)) / columns;
  }
}

class _MetricStripItem extends StatelessWidget {
  final String label;
  final String value;

  const _MetricStripItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final color = _metricColor(label);
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: KSpacing.borderRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(_metricIcon(label), size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: KTypography.labelSmall.copyWith(
                    color: KColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: KTypography.amountSmall.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ReportTable extends StatefulWidget {
  final String title;
  final List columns;
  final List rows;
  final bool dense;

  const _ReportTable({
    required this.title,
    required this.columns,
    required this.rows,
    this.dense = false,
  });

  @override
  State<_ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends State<_ReportTable> {
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const KEmptyState(
        icon: Icons.table_rows_outlined,
        title: 'No rows for this period',
      );
    }

    final defs =
        widget.columns.map((c) => (c as Map).cast<String, dynamic>()).toList();
    final rowMaps =
        widget.rows.map((r) => (r as Map).cast<String, dynamic>()).toList();

    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return KCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KSpacing.radiusLg),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined,
                        size: 17, color: cs.primary),
                    KSpacing.hGapSm,
                    Expanded(
                      child: Text(widget.title, style: KTypography.labelLarge),
                    ),
                    Text(
                      '${rowMaps.length} row${rowMaps.length == 1 ? '' : 's'}',
                      style: KTypography.bodySmall.copyWith(
                        color: KColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(KSpacing.radiusLg),
                ),
                child: Scrollbar(
                  controller: _horizontalController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalController,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, bottom: 12),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowHeight: 42,
                          dataRowMinHeight: widget.dense ? 42 : 48,
                          dataRowMaxHeight: widget.dense ? 56 : 64,
                          columnSpacing: widget.dense ? 8 : 10,
                          horizontalMargin: 8,
                          headingRowColor: WidgetStatePropertyAll(
                            cs.surfaceContainerHighest.withValues(alpha: 0.55),
                          ),
                          headingTextStyle: KTypography.labelMedium.copyWith(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                          columns: defs
                              .map((c) => DataColumn(
                                    label: Text(
                                      c['label']?.toString() ??
                                          c['key'].toString(),
                                    ),
                                    numeric: c['type'] == 'currency' ||
                                        c['type'] == 'number',
                                  ))
                              .toList(),
                          rows: rowMaps.map((row) {
                            return DataRow(
                              color: kEntityRowColor(context),
                              cells: defs.map((c) {
                                final key = c['key']?.toString() ?? '';
                                final type = c['type']?.toString() ?? 'text';
                                return DataCell(_Cell(
                                  value: row[key],
                                  type: type,
                                  columnKey: key,
                                  dense: widget.dense,
                                ));
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  final Object? value;
  final String type;
  final String columnKey;
  final bool dense;

  const _Cell({
    required this.value,
    required this.type,
    required this.columnKey,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'status' && value != null) {
      return SizedBox(
        width: _widthFor(columnKey, type),
        child: _ReportStatusBadge(status: value.toString()),
      );
    }
    final text = _formatValue(value, type);
    final alignRight = type == 'currency' || type == 'number';
    return SizedBox(
      width: _widthFor(columnKey, type),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.end : TextAlign.start,
        maxLines: dense ? 1 : 2,
        overflow: TextOverflow.ellipsis,
        style: type == 'currency'
            ? KTypography.amountSmall
            : (dense ? KTypography.bodySmall : KTypography.bodyMedium),
      ),
    );
  }

  double _widthFor(String key, String type) {
    if (key == 'date') return 76;
    if (key == 'number') return 106;
    if (key == 'vendorBill') return 92;
    if (key == 'sku') return 90;
    if (key == 'batch') return 92;
    if (key == 'expiry') return 86;
    if (key == 'status' || key == 'type' || key == 'mode' || key == 'source') {
      return 88;
    }
    if (key == 'reference' || key == 'description') return 118;
    if (key == 'item' || key == 'customer' || key == 'vendor') return 132;
    if (key == 'warehouse') return 116;
    if (type == 'currency') return 84;
    if (type == 'number') return 68;
    return 118;
  }
}

class _ReportStatusBadge extends StatelessWidget {
  final String status;

  const _ReportStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = KColors.statusColor(status);
    final bgColor = KColors.statusBgColor(status);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 88),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(KSpacing.radiusRound),
        ),
        child: Text(
          _shortLabel(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: KTypography.labelSmall.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  String _shortLabel(String value) {
    return switch (value.toUpperCase()) {
      'PARTIALLY_PAID' => 'PARTIAL',
      'PARTIALLY_APPLIED' => 'PARTIAL',
      'BANK_TRANSFER' => 'BANK',
      _ => value.replaceAll('_', ' ').toUpperCase(),
    };
  }
}

String _formatValue(Object? value, String? type) {
  if (value == null) return '--';
  if (type == 'currency') {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    return CurrencyFormatter.formatIndian(number ?? 0);
  }
  if (type == 'number') {
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null) return value.toString();
    return number.toStringAsFixed(number.truncateToDouble() == number ? 0 : 2);
  }
  if (type == 'date') {
    final parsed = DateTime.tryParse(value.toString());
    return parsed == null ? value.toString() : DateFormatter.short(parsed);
  }
  return value.toString();
}

IconData _reportIcon(String title) {
  final t = title.toLowerCase();
  if (t.contains('sales')) return Icons.trending_up_rounded;
  if (t.contains('purchase')) return Icons.shopping_bag_outlined;
  if (t.contains('stock')) return Icons.inventory_2_outlined;
  if (t.contains('gst') || t.contains('tax')) return Icons.receipt_long_rounded;
  if (t.contains('cash')) return Icons.account_balance_wallet_outlined;
  return Icons.analytics_outlined;
}

Color _reportAccent(String title) {
  final t = title.toLowerCase();
  if (t.contains('sales')) return KColors.success;
  if (t.contains('purchase')) return KColors.warning;
  if (t.contains('stock')) return KColors.secondary;
  if (t.contains('gst') || t.contains('tax')) return KColors.primary;
  if (t.contains('cash')) return KColors.accent;
  return KColors.primary;
}

IconData _metricIcon(String label) {
  final l = label.toLowerCase();
  if (l.contains('invoice') || l.contains('bill') || l.contains('count')) {
    return Icons.tag_rounded;
  }
  if (l.contains('tax') || l.contains('gst') || l.contains('tds')) {
    return Icons.receipt_long_rounded;
  }
  if (l.contains('outstanding') || l.contains('balance')) {
    return Icons.warning_amber_rounded;
  }
  if (l.contains('total')) return Icons.summarize_outlined;
  if (l.contains('stock') || l.contains('qty')) {
    return Icons.inventory_2_outlined;
  }
  return Icons.stacked_line_chart_rounded;
}

Color _metricColor(String label) {
  final l = label.toLowerCase();
  if (l.contains('outstanding') || l.contains('balance')) {
    return KColors.warning;
  }
  if (l.contains('tax') || l.contains('gst') || l.contains('tds')) {
    return KColors.primary;
  }
  if (l.contains('total')) return KColors.success;
  if (l.contains('count') || l.contains('invoice') || l.contains('bill')) {
    return KColors.secondary;
  }
  return KColors.textPrimary;
}

class _StockMovementToolbar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String stockTypeFilter;
  final bool onlyBatchRows;
  final int totalRows;
  final int visibleRows;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<bool> onToggleBatchOnly;
  final VoidCallback onClear;

  const _StockMovementToolbar({
    required this.searchController,
    required this.searchQuery,
    required this.stockTypeFilter,
    required this.onlyBatchRows,
    required this.totalRows,
    required this.visibleRows,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onToggleBatchOnly,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    const stockTypes = [
      'ALL',
      'PURCHASE',
      'SALE',
      'OPENING',
      'RETURN_IN',
      'RETURN_OUT',
      'ADJUSTMENT',
      'TRANSFER_IN',
      'TRANSFER_OUT',
    ];
    return KCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Filter rows', style: KTypography.labelLarge),
              ),
              Text(
                '$visibleRows of $totalRows',
                style: KTypography.bodySmall
                    .copyWith(color: KColors.textSecondary),
              ),
            ],
          ),
          KSpacing.vGapSm,
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search item, SKU, batch, expiry, warehouse or ref',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onClear,
                    )
                  : null,
              isDense: true,
            ),
            onChanged: onSearchChanged,
          ),
          KSpacing.vGapSm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              DropdownButton<String>(
                value: stockTypeFilter,
                items: stockTypes
                    .map(
                      (type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type == 'ALL' ? 'All types' : type),
                      ),
                    )
                    .toList(),
                onChanged: (value) => onTypeChanged(value ?? 'ALL'),
              ),
              FilterChip(
                label: const Text('Batch only'),
                selected: onlyBatchRows,
                onSelected: onToggleBatchOnly,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
