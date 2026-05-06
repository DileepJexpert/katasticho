import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/report_repository.dart';

class ProfitLossScreen extends ConsumerStatefulWidget {
  const ProfitLossScreen({super.key});

  @override
  ConsumerState<ProfitLossScreen> createState() => _ProfitLossScreenState();
}

class _ProfitLossScreenState extends ConsumerState<ProfitLossScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
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
      final data = await repo.getProfitLoss(
        startDate: DateFormatter.api(_startDate),
        endDate: DateFormatter.api(_endDate),
      );
      setState(() => _report = (data['data'] ?? data) as Map<String, dynamic>);
    } catch (e) {
      setState(() => _error = 'Failed to load report');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profit & Loss')),
      body: Column(
        children: [
          Container(
            color: KColors.surface,
            padding: const EdgeInsets.all(KSpacing.md),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < KSpacing.mobileBreakpoint;
                final fieldWidth = narrow
                    ? constraints.maxWidth
                    : (constraints.maxWidth - KSpacing.sm) / 2;
                return Wrap(
                  spacing: KSpacing.sm,
                  runSpacing: KSpacing.sm,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: KDatePicker(
                        label: 'From',
                        value: _startDate,
                        onChanged: (d) {
                          _startDate = d;
                          _loadReport();
                        },
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: KDatePicker(
                        label: 'To',
                        value: _endDate,
                        onChanged: (d) {
                          _endDate = d;
                          _loadReport();
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const KLoading(message: 'Generating P&L...')
                : _error != null
                    ? KErrorView(message: _error!, onRetry: _loadReport)
                    : _report == null
                        ? const KEmptyState(
                            icon: Icons.trending_up,
                            title: 'No data available',
                          )
                        : _buildReport(),
          ),
        ],
      ),
    );
  }

  Widget _buildReport() {
    final totalRevenue =
        (_report!['totalRevenue'] as num?)?.toDouble() ?? 0;
    final totalExpenses =
        (_report!['totalExpenses'] as num?)?.toDouble() ?? 0;
    final netProfit = (_report!['netProfit'] as num?)?.toDouble() ?? 0;
    final revenueAccounts = (_report!['revenueAccounts'] as List?) ?? [];
    final expenseAccounts = (_report!['expenseAccounts'] as List?) ?? [];
    final isProfit = netProfit >= 0;

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < KSpacing.mobileBreakpoint;
              final revenue = _MetricPanel(
                label: 'Revenue',
                amount: totalRevenue,
                color: KColors.success,
              );
              final expenses = _MetricPanel(
                label: 'Expenses',
                amount: totalExpenses,
                color: KColors.error,
              );
              if (narrow) {
                return Column(
                  children: [
                    revenue,
                    KSpacing.vGapSm,
                    expenses,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: revenue),
                  KSpacing.hGapSm,
                  Expanded(child: expenses),
                ],
              );
            },
          ),
          KSpacing.vGapMd,

          // Net profit card
          KCard(
            borderColor: isProfit ? KColors.success : KColors.error,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isProfit ? 'Net Profit' : 'Net Loss',
                  style: KTypography.h3,
                ),
                Flexible(
                  child: Text(
                    CurrencyFormatter.formatIndian(netProfit.abs()),
                    style: KTypography.amountLarge.copyWith(
                      color: isProfit ? KColors.success : KColors.error,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,

          // Revenue breakdown
          Text('Revenue', style: KTypography.h3),
          KSpacing.vGapSm,
          if (revenueAccounts.isEmpty)
            _EmptyReportLine(label: 'No revenue posted in this period')
          else
            ...revenueAccounts.map((acct) {
              final a = acct as Map<String, dynamic>;
              return _AccountLine(
                code: a['accountCode'] as String? ?? '',
                name: a['accountName'] as String? ?? '',
                amount: (a['amount'] as num?)?.toDouble() ?? 0,
                color: KColors.success,
              );
            }),
          KSpacing.vGapLg,

          // Expense breakdown
          Text('Expenses', style: KTypography.h3),
          KSpacing.vGapSm,
          if (expenseAccounts.isEmpty)
            _EmptyReportLine(label: 'No expenses posted in this period')
          else
            ...expenseAccounts.map((acct) {
              final a = acct as Map<String, dynamic>;
              return _AccountLine(
                code: a['accountCode'] as String? ?? '',
                name: a['accountName'] as String? ?? '',
                amount: (a['amount'] as num?)?.toDouble() ?? 0,
                color: KColors.error,
              );
            }),
        ],
      ),
    );
  }
}

class _AccountLine extends StatelessWidget {
  final String code;
  final String name;
  final double amount;
  final Color color;

  const _AccountLine({
    required this.code,
    required this.name,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(code, style: KTypography.bodySmall),
          ),
          Expanded(
            child: Text(
              name,
              style: KTypography.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              CurrencyFormatter.formatIndian(amount),
              style: KTypography.amountSmall.copyWith(color: color),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPanel extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _MetricPanel({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: KTypography.bodySmall),
          KSpacing.vGapXs,
          Text(
            CurrencyFormatter.formatIndian(amount),
            style: KTypography.amountMedium.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyReportLine extends StatelessWidget {
  final String label;

  const _EmptyReportLine({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        label,
        style: KTypography.bodySmall.copyWith(color: KColors.textSecondary),
      ),
    );
  }
}
