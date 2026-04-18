import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
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
    final buckets =
        (_report!['buckets'] ?? _report!['summary']) as Map<String, dynamic>? ??
            {};
    final customers = (_report!['contacts'] as List?) ?? [];

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
                Text('Total Outstanding', style: KTypography.bodySmall),
                KSpacing.vGapXs,
                Text(
                  CurrencyFormatter.formatIndian(totalOutstanding),
                  style: KTypography.amountLarge,
                ),
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Ageing buckets
          Text('Ageing Summary', style: KTypography.h3),
          KSpacing.vGapSm,
          Row(
            children: [
              _AgeingBucket(
                label: 'Current',
                amount: (buckets['current'] as num?)?.toDouble() ?? 0,
                color: KColors.ageingCurrent,
              ),
              _AgeingBucket(
                label: '1-30',
                amount: (buckets['days1to30'] as num?)?.toDouble() ?? 0,
                color: KColors.ageing1to30,
              ),
              _AgeingBucket(
                label: '31-60',
                amount: (buckets['days31to60'] as num?)?.toDouble() ?? 0,
                color: KColors.ageing31to60,
              ),
              _AgeingBucket(
                label: '61-90',
                amount: (buckets['days61to90'] as num?)?.toDouble() ?? 0,
                color: KColors.ageing61to90,
              ),
              _AgeingBucket(
                label: '90+',
                amount: (buckets['days90Plus'] as num?)?.toDouble() ?? 0,
                color: KColors.ageing90Plus,
              ),
            ],
          ),
          KSpacing.vGapLg,

          // Customer breakdown
          Text('By Customer', style: KTypography.h3),
          KSpacing.vGapSm,
          if (customers.isEmpty)
            const KEmptyState(
              icon: Icons.people_outline,
              title: 'No outstanding receivables',
            )
          else
            ...customers.map((c) {
              final customer = c as Map<String, dynamic>;
              final name = customer['contactName'] as String? ?? 'Unknown';
              final total =
                  (customer['totalOutstanding'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: KCard(
                  child: Row(
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
                        child: Text(name, style: KTypography.bodyMedium),
                      ),
                      Text(
                        CurrencyFormatter.formatIndian(total),
                        style: KTypography.amountSmall.copyWith(
                          color: KColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
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
