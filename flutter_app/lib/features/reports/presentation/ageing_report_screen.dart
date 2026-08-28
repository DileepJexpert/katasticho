import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
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
      appBar: AppBar(
        title: const Text('Receivables Ageing Report'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadReport,
          ),
        ],
      ),
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
          // ── Top Summary KPI Cards ──
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
                  label: 'Total Overdue',
                  value: overdueTotal,
                  icon: Icons.warning_amber_rounded,
                  color: overdueTotal > 0 ? KColors.error : KColors.success,
                ),
              ),
            ],
          ),
          KSpacing.vGapMd,

          // ── Ageing Buckets Bar ──
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
                  label: '1-30 Days',
                  amount: _bucket(buckets, 'days1to30'),
                  color: KColors.ageing1to30,
                ),
                _AgeingBucket(
                  label: '31-60 Days',
                  amount: _bucket(buckets, 'days31to60'),
                  color: KColors.ageing31to60,
                ),
                _AgeingBucket(
                  label: '61-90 Days',
                  amount: _bucket(buckets, 'days61to90'),
                  color: KColors.ageing61to90,
                ),
                _AgeingBucket(
                  label: '90+ Days',
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
                    .map((child) => SizedBox(width: 140, child: child))
                    .toList(),
              );
            },
          ),
          KSpacing.vGapLg,

          // ── Customer Breakdown List ──
          Row(
            children: [
              Expanded(
                child: Text('Customer Breakdown', style: KTypography.h4),
              ),
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
              subtitle: 'All customer accounts are fully settled.',
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
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(KSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: KSpacing.borderRadiusMd,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: KSpacing.borderRadiusSm,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          KSpacing.hGapSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: KTypography.labelSmall),
                const SizedBox(height: 2),
                KMoney(
                  value,
                  size: KMoneySize.medium,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: KSpacing.borderRadiusSm,
        border: Border(
          top: BorderSide(color: color, width: 3),
          left: BorderSide(color: color.withValues(alpha: 0.2)),
          right: BorderSide(color: color.withValues(alpha: 0.2)),
          bottom: BorderSide(color: color.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: KTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          KSpacing.vGapXs,
          KMoney(
            amount,
            size: KMoneySize.small,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
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
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: KColors.primary.withValues(alpha: 0.12),
          child: Text(
            name.isEmpty ? '?' : name[0].toUpperCase(),
            style: KTypography.labelLarge.copyWith(color: KColors.primary),
          ),
        ),
        title: Text(
          name,
          style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          [
            if (phone != null && phone.isNotEmpty) phone,
            '${invoices.length} open invoice${invoices.length == 1 ? '' : 's'}',
          ].join(' • '),
          style: KTypography.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: KMoney(
          total,
          size: KMoneySize.medium,
          style: const TextStyle(
            color: KColors.warning,
            fontWeight: FontWeight.w700,
          ),
        ),
        children: [
          _InlineBuckets(source: customer),
          KSpacing.vGapSm,
          if (invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(KSpacing.sm),
              child: Text(
                'No invoice level detail returned',
                style: KTypography.bodySmall.copyWith(color: KColors.textHint),
              ),
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
    final hasAmount = amount > 0.001;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasAmount
            ? color.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: KSpacing.borderRadiusSm,
        border: Border.all(
          color: hasAmount
              ? color.withValues(alpha: 0.35)
              : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: KTypography.labelSmall.copyWith(
              color: hasAmount ? color : Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          if (hasAmount)
            KMoney(
              amount,
              size: KMoneySize.small,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            Text(
              '--',
              style: KTypography.bodySmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
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

        return Container(
          decoration: BoxDecoration(
            borderRadius: KSpacing.borderRadiusMd,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 34,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 44,
              headingRowColor: WidgetStateProperty.all(
                Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              ),
              headingTextStyle: KTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
              dataTextStyle: KTypography.bodySmall,
              columnSpacing: 16,
              horizontalMargin: 12,
              columns: const [
                DataColumn(label: Text('INVOICE')),
                DataColumn(label: Text('DATE')),
                DataColumn(label: Text('AGE')),
                DataColumn(label: Text('BUCKET')),
                DataColumn(label: Text('ORIGINAL'), numeric: true),
                DataColumn(label: Text('BALANCE'), numeric: true),
                DataColumn(label: SizedBox(width: 28)),
              ],
              rows: invoices.map((raw) {
                final invoice = raw as Map<String, dynamic>;
                final id = invoice['invoiceId']?.toString();
                return DataRow(
                  cells: [
                    DataCell(Text(
                      invoice['invoiceNumber']?.toString() ?? '--',
                      style: KTypography.mono(fontSize: 12, weight: FontWeight.w600),
                    )),
                    DataCell(Text(_formatDate(invoice['invoiceDate']))),
                    DataCell(Text(_ageLabel(invoice['daysOverdue']))),
                    DataCell(KStatusChip(
                      status: invoice['bucket']?.toString() ?? 'CURRENT',
                    )),
                    DataCell(KMoney(
                      _num(invoice['totalAmount']),
                      size: KMoneySize.small,
                    )),
                    DataCell(KMoney(
                      _num(invoice['balanceDue']),
                      size: KMoneySize.small,
                      style: const TextStyle(
                        color: KColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    )),
                    DataCell(IconButton(
                      tooltip: 'Open invoice',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      onPressed:
                          id == null ? null : () => context.go('/invoices/$id'),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  double _num(dynamic value) => (value as num?)?.toDouble() ?? 0;
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
      title: Text(number, style: KTypography.mono(fontSize: 13, weight: FontWeight.w600)),
      subtitle: Text('$date • ${_ageLabel(source['daysOverdue'])}'),
      trailing: KMoney(
        balance,
        size: KMoneySize.small,
        style: const TextStyle(color: KColors.warning, fontWeight: FontWeight.w700),
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
