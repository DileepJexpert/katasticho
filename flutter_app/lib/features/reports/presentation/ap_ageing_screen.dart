import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/report_repository.dart';

class ApAgeingScreen extends ConsumerStatefulWidget {
  const ApAgeingScreen({super.key});

  @override
  ConsumerState<ApAgeingScreen> createState() => _ApAgeingScreenState();
}

class _ApAgeingScreenState extends ConsumerState<ApAgeingScreen> {
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
      final data = await repo.getApAgeingReport();
      setState(() => _report = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (_) {
      setState(() => _error = 'Failed to load AP ageing report');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AP Ageing Report'),
        actions: [
          if (_report != null)
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Export CSV',
              onPressed: _exportCsv,
            ),
        ],
      ),
      body: _isLoading
          ? const KLoading(message: 'Loading AP ageing report...')
          : _error != null
              ? KErrorView(message: _error!, onRetry: _loadReport)
              : _report == null
                  ? const KEmptyState(
                      icon: Icons.timelapse,
                      title: 'No payables data',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReport,
                      child: _buildReport(),
                    ),
    );
  }

  Widget _buildReport() {
    final totalOutstanding = _num(_report!['totalOutstanding']);
    final vendors =
        (_report!['vendors'] ?? _report!['customers']) as List? ?? [];
    final overdueTotal = _bucket(_report!, 'days1to30') +
        _bucket(_report!, 'days31to60') +
        _bucket(_report!, 'days61to90') +
        _bucket(_report!, 'days90plus');

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Total Payable',
                  value: totalOutstanding,
                  icon: Icons.account_balance_wallet_rounded,
                  color: KColors.error,
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
              final buckets = [
                _AgeingBucket(
                  label: 'Current',
                  amount: _bucket(_report!, 'current'),
                  color: KColors.ageingCurrent,
                ),
                _AgeingBucket(
                  label: '1-30',
                  amount: _bucket(_report!, 'days1to30'),
                  color: KColors.ageing1to30,
                ),
                _AgeingBucket(
                  label: '31-60',
                  amount: _bucket(_report!, 'days31to60'),
                  color: KColors.ageing31to60,
                ),
                _AgeingBucket(
                  label: '61-90',
                  amount: _bucket(_report!, 'days61to90'),
                  color: KColors.ageing61to90,
                ),
                _AgeingBucket(
                  label: '90+',
                  amount: _bucket(_report!, 'days90plus'),
                  color: KColors.ageing90Plus,
                ),
              ];
              if (constraints.maxWidth >= 720) {
                return Row(
                  children: buckets.map((b) => Expanded(child: b)).toList(),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    buckets.map((b) => SizedBox(width: 132, child: b)).toList(),
              );
            },
          ),
          KSpacing.vGapMd,
          Row(
            children: [
              Expanded(child: Text('Vendor Breakdown', style: KTypography.h4)),
              Text(
                '${vendors.length} vendor${vendors.length == 1 ? '' : 's'}',
                style: KTypography.bodySmall.copyWith(
                  color: KColors.textSecondary,
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          if (vendors.isEmpty)
            const KEmptyState(
              icon: Icons.store_outlined,
              title: 'No outstanding payables',
            )
          else
            ...vendors.map((raw) {
              final vendor = raw as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _VendorAgeingTile(vendor: vendor),
              );
            }),
        ],
      ),
    );
  }

  void _exportCsv() {
    final csv = _toCsv();
    final bytes = utf8.encode(csv);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV prepared (${bytes.length} bytes)'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  String _toCsv() {
    final vendors =
        (_report?['vendors'] ?? _report?['customers']) as List? ?? [];
    final buf = StringBuffer();
    buf.writeln(
      'Vendor,Bill,Current,1-30 Days,31-60 Days,61-90 Days,90+ Days,Balance',
    );
    for (final rawVendor in vendors) {
      final vendor = rawVendor as Map<String, dynamic>;
      final name = (vendor['vendorName'] ?? vendor['customerName'] ?? 'Unknown')
          .toString()
          .replaceAll(',', ' ');
      final bills = (vendor['bills'] as List?) ?? [];
      if (bills.isEmpty) {
        buf.writeln(
          '$name,,${_bucket(vendor, 'current')},${_bucket(vendor, 'days1to30')},'
          '${_bucket(vendor, 'days31to60')},${_bucket(vendor, 'days61to90')},'
          '${_bucket(vendor, 'days90plus')},${_num(vendor['totalOutstanding'])}',
        );
      } else {
        for (final rawBill in bills) {
          final bill = rawBill as Map<String, dynamic>;
          final balance = _num(bill['balanceDue']);
          final bucket = bill['bucket']?.toString();
          buf.writeln(
            '$name,${bill['billNumber'] ?? '--'},'
            '${bucket == 'CURRENT' ? balance : 0},'
            '${bucket == '1-30' ? balance : 0},'
            '${bucket == '31-60' ? balance : 0},'
            '${bucket == '61-90' ? balance : 0},'
            '${bucket == '90+' ? balance : 0},'
            '$balance',
          );
        }
      }
    }
    return buf.toString();
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
                KMoney(
                  value,
                  size: KMoneySize.small,
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

class _VendorAgeingTile extends StatelessWidget {
  final Map<String, dynamic> vendor;

  const _VendorAgeingTile({required this.vendor});

  @override
  Widget build(BuildContext context) {
    final name = (vendor['vendorName'] ?? vendor['customerName'] ?? 'Unknown')
        .toString();
    final total = _num(vendor['totalOutstanding']);
    final bills = (vendor['bills'] as List?) ?? [];

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
          '${bills.length} open bill${bills.length == 1 ? '' : 's'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 132,
          child: KMoney(
            total,
            size: KMoneySize.small,
            style: const TextStyle(color: KColors.error, fontWeight: FontWeight.w700),
          ),
        ),
        children: [
          _InlineBuckets(source: vendor),
          KSpacing.vGapSm,
          if (bills.isEmpty)
            Text(
              'No bill level detail returned',
              style: KTypography.bodySmall.copyWith(color: KColors.textHint),
            )
          else
            _BillDetailTable(bills: bills),
        ],
      ),
    );
  }
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
            amount: _bucket(source, 'current'),
            color: KColors.ageingCurrent,
          ),
          _BucketChip(
            label: '1-30',
            amount: _bucket(source, 'days1to30'),
            color: KColors.ageing1to30,
          ),
          _BucketChip(
            label: '31-60',
            amount: _bucket(source, 'days31to60'),
            color: KColors.ageing31to60,
          ),
          _BucketChip(
            label: '61-90',
            amount: _bucket(source, 'days61to90'),
            color: KColors.ageing61to90,
          ),
          _BucketChip(
            label: '90+',
            amount: _bucket(source, 'days90plus'),
            color: KColors.ageing90Plus,
          ),
        ],
      ),
    );
  }
}

class _BillDetailTable extends StatelessWidget {
  final List<dynamic> bills;

  const _BillDetailTable({required this.bills});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            children: bills
                .map((raw) =>
                    _BillDocumentCard(source: raw as Map<String, dynamic>))
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
              DataColumn(label: Text('Bill')),
              DataColumn(label: Text('Age')),
              DataColumn(label: Text('Bucket')),
              DataColumn(label: Text('Balance'), numeric: true),
              DataColumn(label: SizedBox(width: 32)),
            ],
            rows: bills.map((raw) {
              final bill = raw as Map<String, dynamic>;
              final id = bill['billId']?.toString();
              return DataRow(
                cells: [
                  DataCell(Text(
                    bill['billNumber']?.toString() ?? '--',
                    style: KTypography.mono(fontSize: 12, weight: FontWeight.w600),
                  )),
                  DataCell(Text(_ageLabel(bill['daysOverdue']))),
                  DataCell(_BucketLabel(bucket: bill['bucket']?.toString())),
                  DataCell(KMoney(
                    _num(bill['balanceDue']),
                    size: KMoneySize.small,
                    style: const TextStyle(
                      color: KColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  )),
                  DataCell(IconButton(
                    tooltip: 'Open bill',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    onPressed:
                        id == null ? null : () => context.go('/bills/$id'),
                  )),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _BillDocumentCard extends StatelessWidget {
  final Map<String, dynamic> source;

  const _BillDocumentCard({required this.source});

  @override
  Widget build(BuildContext context) {
    final id = source['billId']?.toString();
    final number = source['billNumber']?.toString() ?? '--';
    final balance = _num(source['balanceDue']);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(number, style: KTypography.mono(fontSize: 13, weight: FontWeight.w600)),
      subtitle: Text(_ageLabel(source['daysOverdue'])),
      trailing: KMoney(
        balance,
        size: KMoneySize.small,
        style: const TextStyle(color: KColors.error, fontWeight: FontWeight.w700),
      ),
      onTap: id == null ? null : () => context.go('/bills/$id'),
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
          color: amount > 0 ? color.withValues(alpha: 0.3) : KColors.divider,
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

double _num(dynamic value) => (value as num?)?.toDouble() ?? 0;

double _bucket(Map<String, dynamic> source, String key) {
  final camelKey = key == 'days90plus' ? 'days90Plus' : key;
  return (source[key] as num?)?.toDouble() ??
      (source[camelKey] as num?)?.toDouble() ??
      0;
}

String _ageLabel(dynamic value) {
  final days = (value as num?)?.toInt() ?? 0;
  if (days <= 0) return 'Current';
  return '$days day${days == 1 ? '' : 's'} overdue';
}
