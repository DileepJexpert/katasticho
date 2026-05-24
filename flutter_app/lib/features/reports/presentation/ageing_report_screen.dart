import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/report_repository.dart';

class AgeingReportScreen extends ConsumerStatefulWidget {
  const AgeingReportScreen({super.key});

  @override
  ConsumerState<AgeingReportScreen> createState() => _AgeingReportScreenState();
}

class _AgeingReportScreenState extends ConsumerState<AgeingReportScreen> {
  Map<String, dynamic>? _report;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(reportRepositoryProvider);
      final data = await repo.getAgeingReport();
      setState(() => _report = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = 'Failed to load ageing report');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ageing Report')),
      body: _isLoading
          ? const KLoading(message: 'Loading ageing report...')
          : _error != null
              ? KErrorView(message: _error!, onRetry: _loadReport)
              : _report == null
                  ? const KEmptyState(
                      icon: Icons.timelapse,
                      title: 'No receivables data',
                    )
                  : _buildReport(),
    );
  }

  Widget _buildReport() {
    final totalOutstanding =
        (_report!['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final buckets = _report!;
    final customers = (_report!['contacts'] as List?) ?? [];
    final overdueTotal = _bucket(buckets, 'days1to30') +
        _bucket(buckets, 'days31to60') +
        _bucket(buckets, 'days61to90') +
        _bucket(buckets, 'days90plus');

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Receivable',
                  value: totalOutstanding,
                  icon: Icons.account_balance_wallet_outlined,
                  color: KColors.warning,
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: _SummaryCard(
                  label: 'Overdue',
                  value: overdueTotal,
                  icon: Icons.warning_amber_rounded,
                  color: overdueTotal > 0 ? KColors.error : KColors.success,
                ),
              ),
            ],
          ),
          KSpacing.vGapMd,
          Text('Ageing Buckets', style: KTypography.h4),
          KSpacing.vGapSm,
          LayoutBuilder(
            builder: (context, constraints) {
              final wrap = constraints.maxWidth < 720;
              final children = [
                _AgeingBucket(
                  label: 'Current',
                  amount: _bucket(buckets, 'current'),
                  color: KColors.ageingCurrent,
                ),
                _AgeingBucket(
                  label: '1-30',
                  amount: _bucket(buckets, 'days1to30'),
                  color: KColors.ageing1to30,
                ),
                _AgeingBucket(
                  label: '31-60',
                  amount: _bucket(buckets, 'days31to60'),
                  color: KColors.ageing31to60,
                ),
                _AgeingBucket(
                  label: '61-90',
                  amount: _bucket(buckets, 'days61to90'),
                  color: KColors.ageing61to90,
                ),
                _AgeingBucket(
                  label: '90+',
                  amount: _bucket(buckets, 'days90plus'),
                  color: KColors.ageing90Plus,
                ),
              ];
              if (!wrap) {
                return Row(
                  children:
                      children.map((child) => Expanded(child: child)).toList(),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: children
                    .map((child) => SizedBox(width: 132, child: child))
                    .toList(),
              );
            },
          ),
          KSpacing.vGapMd,
          Row(
            children: [
              Expanded(
                  child: Text('Customer Breakdown', style: KTypography.h4)),
              Text(
                '${customers.length} customer${customers.length == 1 ? '' : 's'}',
                style: KTypography.bodySmall.copyWith(
                  color: KColors.textSecondary,
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          if (customers.isEmpty)
            const KEmptyState(
              icon: Icons.people_outline,
              title: 'No outstanding receivables',
            )
          else
            ...customers.map((c) {
              final customer = c as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CustomerAgeingTile(customer: customer),
              );
            }),
        ],
      ),
    );
  }

  double _bucket(Map<String, dynamic> b, String key) {
    final camelKey = key == 'days90plus' ? 'days90Plus' : key;
    return (b[key] as num?)?.toDouble() ??
        (b[camelKey] as num?)?.toDouble() ??
        0;
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.28),
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KSpacing.borderRadiusSm,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: KTypography.labelSmall),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.formatIndian(value),
                  style: KTypography.amountSmall.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerAgeingTile extends StatelessWidget {
  final Map<String, dynamic> customer;

  const _CustomerAgeingTile({required this.customer});

  @override
  Widget build(BuildContext context) {
    final name = customer['contactName'] as String? ?? 'Unknown';
    final phone = customer['phone'] as String?;
    final total = _num(customer['totalOutstanding']);
    final invoices = (customer['invoices'] as List?) ?? [];

    return KCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: KColors.primaryLight.withValues(alpha: 0.15),
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: KTypography.labelMedium.copyWith(color: KColors.primary),
          ),
        ),
        title: Text(
          name,
          style: KTypography.labelMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (phone != null && phone.isNotEmpty) phone,
            '${invoices.length} open invoice${invoices.length == 1 ? '' : 's'}',
          ].join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 132,
          child: Text(
            CurrencyFormatter.formatIndian(total),
            style: KTypography.amountSmall.copyWith(color: KColors.warning),
            textAlign: TextAlign.end,
          ),
        ),
        children: [
          _InlineBuckets(source: customer),
          KSpacing.vGapSm,
          if (invoices.isEmpty)
            Text(
              'No invoice level detail returned',
              style: KTypography.bodySmall.copyWith(color: KColors.textHint),
            )
          else
            _InvoiceDetailTable(invoices: invoices),
        ],
      ),
    );
  }

  double _num(dynamic value) => (value as num?)?.toDouble() ?? 0;
}

class _InlineBuckets extends StatelessWidget {
  final Map<String, dynamic> source;

  const _InlineBuckets({required this.source});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _BucketChip(
            label: 'Current',
            amount: _bucket('current'),
            color: KColors.ageingCurrent,
          ),
          _BucketChip(
            label: '1-30',
            amount: _bucket('days1to30'),
            color: KColors.ageing1to30,
          ),
          _BucketChip(
            label: '31-60',
            amount: _bucket('days31to60'),
            color: KColors.ageing31to60,
          ),
          _BucketChip(
            label: '61-90',
            amount: _bucket('days61to90'),
            color: KColors.ageing61to90,
          ),
          _BucketChip(
            label: '90+',
            amount: _bucket('days90plus'),
            color: KColors.ageing90Plus,
          ),
        ],
      ),
    );
  }

  double _bucket(String key) {
    final camelKey = key == 'days90plus' ? 'days90Plus' : key;
    return (source[key] as num?)?.toDouble() ??
        (source[camelKey] as num?)?.toDouble() ??
        0;
  }
}

class _InvoiceDetailTable extends StatelessWidget {
  final List<dynamic> invoices;

  const _InvoiceDetailTable({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: invoices
                .map((raw) => _DocumentCard(
                      source: raw as Map<String, dynamic>,
                    ))
                .toList(),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 46,
            headingTextStyle: KTypography.labelMedium,
            dataTextStyle: KTypography.bodySmall,
            columnSpacing: 12,
            horizontalMargin: 8,
            columns: const [
              DataColumn(label: Text('Invoice')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Age')),
              DataColumn(label: Text('Bucket')),
              DataColumn(label: Text('Original'), numeric: true),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: SizedBox(width: 32)),
            ],
            rows: invoices.map((raw) {
              final invoice = raw as Map<String, dynamic>;
              final id = invoice['invoiceId']?.toString();
              return DataRow(
                cells: [
                  DataCell(Text(invoice['invoiceNumber']?.toString() ?? '--')),
                  DataCell(Text(_formatDate(invoice['invoiceDate']))),
                  DataCell(Text(_ageLabel(invoice['daysOverdue']))),
                  DataCell(_BucketLabel(bucket: invoice['bucket']?.toString())),
                  DataCell(Text(
                    CurrencyFormatter.formatIndian(
                        _num(invoice['totalAmount'])),
                    style: KTypography.amountSmall,
                  )),
                  DataCell(Text(
                    CurrencyFormatter.formatIndian(_num(invoice['balanceDue'])),
                    style: KTypography.amountSmall.copyWith(
                      color: KColors.warning,
                    ),
                  )),
                  DataCell(IconButton(
                    tooltip: 'Open invoice',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    onPressed:
                        id == null ? null : () => context.go('/invoices/$id'),
                  )),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }

  double _num(dynamic value) => (value as num?)?.toDouble() ?? 0;
}

class _AgeingBucket extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _AgeingBucket({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: KSpacing.borderRadiusSm,
        border: Border(top: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        children: [
          Text(label, style: KTypography.labelSmall.copyWith(color: color)),
          KSpacing.vGapXs,
          Text(
            CurrencyFormatter.formatCompact(amount),
            style: KTypography.amountSmall.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _BucketChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _BucketChip({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: amount > 0
            ? color.withValues(alpha: 0.1)
            : KColors.divider.withValues(alpha: 0.3),
        borderRadius: KSpacing.borderRadiusSm,
        border: Border.all(
          color: amount > 0 ? color.withValues(alpha: 0.35) : KColors.divider,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: KTypography.labelSmall.copyWith(
              color: amount > 0 ? color : KColors.textHint,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amount == 0 ? '--' : CurrencyFormatter.formatCompact(amount),
            style: KTypography.amountSmall.copyWith(
              color: amount > 0 ? color : KColors.textHint,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _BucketLabel extends StatelessWidget {
  final String? bucket;

  const _BucketLabel({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final color = switch (bucket) {
      'CURRENT' => KColors.ageingCurrent,
      '1-30' => KColors.ageing1to30,
      '31-60' => KColors.ageing31to60,
      '61-90' => KColors.ageing61to90,
      '90+' => KColors.ageing90Plus,
      _ => KColors.textHint,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: KSpacing.borderRadiusSm,
      ),
      child: Text(
        bucket ?? '--',
        style: KTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> source;

  const _DocumentCard({required this.source});

  @override
  Widget build(BuildContext context) {
    final id = source['invoiceId']?.toString();
    final number = source['invoiceNumber']?.toString() ?? '--';
    final date = _formatDate(source['invoiceDate']);
    final balance = (source['balanceDue'] as num?)?.toDouble() ?? 0;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(number, style: KTypography.labelLarge),
      subtitle: Text('$date • ${_ageLabel(source['daysOverdue'])}'),
      trailing: Text(
        CurrencyFormatter.formatIndian(balance),
        style: KTypography.amountSmall.copyWith(color: KColors.warning),
      ),
      onTap: id == null ? null : () => context.go('/invoices/$id'),
    );
  }
}

String _formatDate(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return '--';
  final parsed = DateTime.tryParse(text);
  return parsed == null ? text : DateFormatter.short(parsed);
}

String _ageLabel(dynamic value) {
  final days = (value as num?)?.toInt() ?? 0;
  if (days <= 0) return 'Current';
  return '$days day${days == 1 ? '' : 's'} overdue';
}
