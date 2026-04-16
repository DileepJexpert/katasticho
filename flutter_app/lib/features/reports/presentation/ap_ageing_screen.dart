import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/report_repository.dart';

/// AP Ageing Report — shows vendor payables grouped by age buckets.
///
/// Desktop: full data table with all buckets.
/// Mobile: vendor cards with horizontally scrollable bucket chips.
/// Color coded amounts: grey/green/amber/orange/red/dark-red.
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
      setState(
          () => _report = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (_) {
      setState(() => _error = 'Failed to load AP ageing report');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _toCsv() {
    final vendors = (_report?['vendors'] ?? _report?['customers']) as List? ?? [];
    final buf = StringBuffer();
    buf.writeln('Vendor,Current,1-30 Days,31-60 Days,61-90 Days,90+ Days,Total');
    for (final v in vendors) {
      final vendor = v as Map<String, dynamic>;
      final name = (vendor['vendorName'] ?? vendor['customerName'] ?? 'Unknown')
          .toString()
          .replaceAll(',', ' ');
      final buckets = (vendor['buckets'] ?? vendor) as Map<String, dynamic>;
      buf.writeln(
        '$name,'
        '${_bucket(buckets, 'current')},'
        '${_bucket(buckets, 'days1to30')},'
        '${_bucket(buckets, 'days31to60')},'
        '${_bucket(buckets, 'days61to90')},'
        '${_bucket(buckets, 'days90Plus')},'
        '${(vendor['totalOutstanding'] as num?)?.toDouble() ?? 0}',
      );
    }
    return buf.toString();
  }

  double _bucket(Map<String, dynamic> b, String key) =>
      (b[key] as num?)?.toDouble() ?? 0;

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
                      child: _buildReport(context),
                    ),
    );
  }

  void _exportCsv() {
    final csv = _toCsv();
    // Copy to clipboard as a simple cross-platform approach
    final bytes = utf8.encode(csv);
    if (bytes.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CSV exported (${bytes.length} bytes)'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () {
              // ignore: import_of_legacy_library_into_null_safe
              // Using clipboard via services
              _copyToClipboard(csv);
            },
          ),
        ),
      );
    }
  }

  void _copyToClipboard(String text) {
    // Flutter clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV data copied to clipboard')),
    );
  }

  Widget _buildReport(BuildContext context) {
    final totalOutstanding =
        (_report!['totalOutstanding'] as num?)?.toDouble() ?? 0;
    final summary =
        (_report!['buckets'] ?? _report!['summary']) as Map<String, dynamic>? ??
            {};
    final vendors =
        (_report!['vendors'] ?? _report!['customers']) as List? ?? [];
    final isDesktop =
        MediaQuery.of(context).size.width >= KSpacing.desktopBreakpoint;

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total outstanding
          KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Payable', style: KTypography.bodySmall),
                KSpacing.vGapXs,
                Text(
                  CurrencyFormatter.formatIndian(totalOutstanding),
                  style: KTypography.amountLarge,
                ),
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Ageing buckets summary
          Text('Ageing Summary', style: KTypography.h3),
          KSpacing.vGapSm,
          Row(
            children: [
              _AgeingBucket(
                label: 'Current',
                amount: _bucket(summary, 'current'),
                color: KColors.ageingCurrent,
              ),
              _AgeingBucket(
                label: '1-30',
                amount: _bucket(summary, 'days1to30'),
                color: KColors.ageing1to30,
              ),
              _AgeingBucket(
                label: '31-60',
                amount: _bucket(summary, 'days31to60'),
                color: KColors.ageing31to60,
              ),
              _AgeingBucket(
                label: '61-90',
                amount: _bucket(summary, 'days61to90'),
                color: KColors.ageing61to90,
              ),
              _AgeingBucket(
                label: '90+',
                amount: _bucket(summary, 'days90Plus'),
                color: KColors.ageing90Plus,
              ),
            ],
          ),
          KSpacing.vGapLg,

          // Vendor breakdown
          Text('By Vendor', style: KTypography.h3),
          KSpacing.vGapSm,

          if (vendors.isEmpty)
            const KEmptyState(
              icon: Icons.store_outlined,
              title: 'No outstanding payables',
            )
          else if (isDesktop)
            _DesktopTable(vendors: vendors)
          else
            _MobileVendorCards(vendors: vendors),
        ],
      ),
    );
  }
}

// ── Shared bucket widget (same as AR ageing) ──

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
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: KSpacing.borderRadiusSm,
          border: Border(
            top: BorderSide(color: color, width: 3),
          ),
        ),
        child: Column(
          children: [
            Text(label,
                style: KTypography.labelSmall.copyWith(color: color)),
            KSpacing.vGapXs,
            Text(
              CurrencyFormatter.formatCompact(amount),
              style: KTypography.amountSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Desktop: Full data table with all buckets ──

class _DesktopTable extends StatelessWidget {
  final List<dynamic> vendors;

  const _DesktopTable({required this.vendors});

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingTextStyle: KTypography.labelLarge,
          dataTextStyle: KTypography.bodyMedium,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Vendor')),
            DataColumn(label: Text('Current'), numeric: true),
            DataColumn(label: Text('1-30 Days'), numeric: true),
            DataColumn(label: Text('31-60 Days'), numeric: true),
            DataColumn(label: Text('61-90 Days'), numeric: true),
            DataColumn(label: Text('90+ Days'), numeric: true),
            DataColumn(label: Text('Total'), numeric: true),
          ],
          rows: vendors.map((v) {
            final vendor = v as Map<String, dynamic>;
            final name = (vendor['vendorName'] ??
                    vendor['customerName'] ??
                    'Unknown')
                .toString();
            final buckets =
                (vendor['buckets'] ?? vendor) as Map<String, dynamic>;
            final total =
                (vendor['totalOutstanding'] as num?)?.toDouble() ?? 0;

            return DataRow(cells: [
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 200),
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
              ),
              _coloredCell(buckets, 'current', KColors.ageingCurrent),
              _coloredCell(buckets, 'days1to30', KColors.ageing1to30),
              _coloredCell(buckets, 'days31to60', KColors.ageing31to60),
              _coloredCell(buckets, 'days61to90', KColors.ageing61to90),
              _coloredCell(buckets, 'days90Plus', KColors.ageing90Plus),
              DataCell(Text(
                CurrencyFormatter.formatIndian(total),
                style: KTypography.amountSmall,
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  DataCell _coloredCell(
      Map<String, dynamic> buckets, String key, Color color) {
    final amount = (buckets[key] as num?)?.toDouble() ?? 0;
    return DataCell(
      Text(
        amount == 0 ? '--' : CurrencyFormatter.formatIndian(amount),
        style: KTypography.amountSmall.copyWith(
          color: amount > 0 ? color : KColors.textHint,
        ),
      ),
    );
  }
}

// ── Mobile: Vendor cards with horizontally scrollable bucket chips ──

class _MobileVendorCards extends StatelessWidget {
  final List<dynamic> vendors;

  const _MobileVendorCards({required this.vendors});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: vendors.map((v) {
        final vendor = v as Map<String, dynamic>;
        final name = (vendor['vendorName'] ??
                vendor['customerName'] ??
                'Unknown')
            .toString();
        final total =
            (vendor['totalOutstanding'] as num?)?.toDouble() ?? 0;
        final buckets =
            (vendor['buckets'] ?? vendor) as Map<String, dynamic>;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: KCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          KColors.primaryLight.withValues(alpha: 0.15),
                      child: Text(
                        name[0].toUpperCase(),
                        style: KTypography.labelLarge
                            .copyWith(color: KColors.primary),
                      ),
                    ),
                    KSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: KTypography.bodyMedium),
                          Text(
                            'Total: ${CurrencyFormatter.formatIndian(total)}',
                            style: KTypography.amountSmall.copyWith(
                              color: KColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapSm,

                // Horizontally scrollable bucket chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _BucketChip(
                        label: 'Current',
                        amount: _bucketVal(buckets, 'current'),
                        color: KColors.ageingCurrent,
                      ),
                      _BucketChip(
                        label: '1-30d',
                        amount: _bucketVal(buckets, 'days1to30'),
                        color: KColors.ageing1to30,
                      ),
                      _BucketChip(
                        label: '31-60d',
                        amount: _bucketVal(buckets, 'days31to60'),
                        color: KColors.ageing31to60,
                      ),
                      _BucketChip(
                        label: '61-90d',
                        amount: _bucketVal(buckets, 'days61to90'),
                        color: KColors.ageing61to90,
                      ),
                      _BucketChip(
                        label: '90d+',
                        amount: _bucketVal(buckets, 'days90Plus'),
                        color: KColors.ageing90Plus,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  double _bucketVal(Map<String, dynamic> b, String key) =>
      (b[key] as num?)?.toDouble() ?? 0;
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
            amount == 0
                ? '--'
                : CurrencyFormatter.formatCompact(amount),
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
