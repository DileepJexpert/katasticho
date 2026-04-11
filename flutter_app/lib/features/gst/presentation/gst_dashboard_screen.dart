import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../reports/data/report_repository.dart';

class GstDashboardScreen extends ConsumerStatefulWidget {
  const GstDashboardScreen({super.key});

  @override
  ConsumerState<GstDashboardScreen> createState() =>
      _GstDashboardScreenState();
}

class _GstDashboardScreenState extends ConsumerState<GstDashboardScreen> {
  // Default to current financial quarter
  late DateTime _startDate;
  late DateTime _endDate;
  Map<String, dynamic>? _gstr1;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final quarterMonth = ((now.month - 1) ~/ 3) * 3 + 1;
    _startDate = DateTime(now.year, quarterMonth, 1);
    _endDate = DateTime(now.year, quarterMonth + 3, 0);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = ref.read(reportRepositoryProvider);
      final data = await repo.getGstr1(
        startDate: DateFormatter.api(_startDate),
        endDate: DateFormatter.api(_endDate),
      );
      setState(() => _gstr1 = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = 'Failed to load GST data');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GST')),
      body: SingleChildScrollView(
        padding: KSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            Row(
              children: [
                Expanded(
                  child: KDatePicker(
                    label: 'From',
                    value: _startDate,
                    onChanged: (d) {
                      _startDate = d;
                      _loadData();
                    },
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: KDatePicker(
                    label: 'To',
                    value: _endDate,
                    onChanged: (d) {
                      _endDate = d;
                      _loadData();
                    },
                  ),
                ),
              ],
            ),
            KSpacing.vGapLg,

            // GST Summary
            Text('GST Returns', style: KTypography.h2),
            KSpacing.vGapMd,

            // GSTR-1
            KCard(
              onTap: () {},
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KColors.primary.withValues(alpha: 0.1),
                      borderRadius: KSpacing.borderRadiusMd,
                    ),
                    child: const Icon(Icons.upload_file,
                        color: KColors.primary, size: 28),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GSTR-1', style: KTypography.h3),
                        Text(
                          'Outward supplies (Sales)',
                          style: KTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  KStatusChip(
                    status: 'DRAFT',
                    label: _isLoading ? 'Loading...' : 'Ready',
                  ),
                  KSpacing.hGapSm,
                  const Icon(Icons.chevron_right, color: KColors.textHint),
                ],
              ),
            ),
            KSpacing.vGapMd,

            // GSTR-3B (placeholder)
            KCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: KColors.secondary.withValues(alpha: 0.1),
                      borderRadius: KSpacing.borderRadiusMd,
                    ),
                    child: const Icon(Icons.summarize,
                        color: KColors.secondary, size: 28),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GSTR-3B', style: KTypography.h3),
                        Text(
                          'Summary return',
                          style: KTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  KStatusChip(
                    status: 'DRAFT',
                    label: 'Coming Soon',
                  ),
                ],
              ),
            ),
            KSpacing.vGapLg,

            // Quick stats
            if (_gstr1 != null) ...[
              Text('GSTR-1 Summary', style: KTypography.h3),
              KSpacing.vGapMd,
              Row(
                children: [
                  Expanded(
                    child: _GstStatCard(
                      label: 'Total Invoices',
                      value: '${(_gstr1!['totalInvoices'] ?? 0)}',
                      icon: Icons.receipt_long,
                      color: KColors.primary,
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: _GstStatCard(
                      label: 'Total Tax',
                      value: CurrencyFormatter.formatCompact(
                        ((_gstr1!['totalTax'] ?? 0) as num).toDouble(),
                      ),
                      icon: Icons.account_balance,
                      color: KColors.accent,
                    ),
                  ),
                ],
              ),
            ],

            if (_error != null) ...[
              KSpacing.vGapMd,
              KErrorBanner(message: _error!),
            ],
          ],
        ),
      ),
    );
  }
}

class _GstStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _GstStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          KSpacing.vGapSm,
          Text(value, style: KTypography.amountMedium),
          Text(label, style: KTypography.bodySmall),
        ],
      ),
    );
  }
}
