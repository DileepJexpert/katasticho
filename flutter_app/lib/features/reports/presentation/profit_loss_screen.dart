import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
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
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.sm,
            ),
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
    final totalRevenue = (_report!['totalRevenue'] as num?)?.toDouble() ?? 0;
    final totalExpenses = (_report!['totalExpenses'] as num?)?.toDouble() ?? 0;
    final netProfit = (_report!['netProfit'] as num?)?.toDouble() ?? 0;
    final revenueAccounts = (_report!['revenueAccounts'] as List?) ?? [];
    final expenseAccounts = (_report!['expenseAccounts'] as List?) ?? [];
    final isProfit = netProfit >= 0;

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricStrip(
            items: [
              _MetricItem(
                label: 'Revenue',
                amount: totalRevenue,
                color: KColors.success,
              ),
              _MetricItem(
                label: 'Expenses',
                amount: totalExpenses,
                color: KColors.error,
              ),
              _MetricItem(
                label: isProfit ? 'Net Profit' : 'Net Loss',
                amount: netProfit.abs(),
                color: isProfit ? KColors.success : KColors.error,
              ),
            ],
          ),
          KSpacing.vGapMd,

          // Revenue breakdown
          KCard(
            statusAccent: KColors.success,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Revenue', style: KTypography.h4.copyWith(fontWeight: FontWeight.w700)),
                    KMoney(
                      totalRevenue,
                      size: KMoneySize.medium,
                      style: const TextStyle(color: KColors.success, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                if (revenueAccounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _EmptyReportLine(label: 'No revenue posted in this period'),
                  )
                else
                  KDataTable(
                    columns: const [
                      KTableColumn(label: 'Code'),
                      KTableColumn(label: 'Account'),
                      KTableColumn(label: 'Amount', numeric: true),
                    ],
                    rows: [
                      ...revenueAccounts.map((acct) {
                        final a = acct as Map<String, dynamic>;
                        final amt = (a['amount'] as num?)?.toDouble() ?? 0;
                        return [
                          Text(
                            a['accountCode'] as String? ?? '',
                            style: KTypography.mono(
                              size: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            a['accountName'] as String? ?? '',
                            style: KTypography.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          KMoney(amt, size: KMoneySize.small),
                        ];
                      }),
                      [
                        Text('', style: KTypography.labelLarge),
                        Text('TOTAL REVENUE', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                        KMoney(totalRevenue, size: KMoneySize.medium, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
              ],
            ),
          ),
          KSpacing.vGapMd,

          // Expense breakdown
          KCard(
            statusAccent: KColors.error,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Expenses', style: KTypography.h4.copyWith(fontWeight: FontWeight.w700)),
                    KMoney(
                      totalExpenses,
                      size: KMoneySize.medium,
                      style: const TextStyle(color: KColors.error, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                KSpacing.vGapSm,
                if (expenseAccounts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _EmptyReportLine(label: 'No expenses posted in this period'),
                  )
                else
                  KDataTable(
                    columns: const [
                      KTableColumn(label: 'Code'),
                      KTableColumn(label: 'Account'),
                      KTableColumn(label: 'Amount', numeric: true),
                    ],
                    rows: [
                      ...expenseAccounts.map((acct) {
                        final a = acct as Map<String, dynamic>;
                        final amt = (a['amount'] as num?)?.toDouble() ?? 0;
                        return [
                          Text(
                            a['accountCode'] as String? ?? '',
                            style: KTypography.mono(
                              size: 12,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            a['accountName'] as String? ?? '',
                            style: KTypography.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                          KMoney(amt, size: KMoneySize.small),
                        ];
                      }),
                      [
                        Text('', style: KTypography.labelLarge),
                        Text('TOTAL EXPENSES', style: KTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                        KMoney(totalExpenses, size: KMoneySize.medium, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class _MetricItem {
  final String label;
  final double amount;
  final Color color;

  const _MetricItem({
    required this.label,
    required this.amount,
    required this.color,
  });
}

class _MetricStrip extends StatelessWidget {
  final List<_MetricItem> items;

  const _MetricStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= KSpacing.tabletBreakpoint;

        if (isWide) {
          return Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0) KSpacing.hGapSm,
                Expanded(
                  child: KCard(
                    statusAccent: items[i].color,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].label, style: KTypography.labelMedium),
                        const SizedBox(height: 4),
                        KMoney(
                          items[i].amount,
                          size: KMoneySize.medium,
                          style: TextStyle(
                            color: items[i].color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0) KSpacing.vGapSm,
              KCard(
                statusAccent: items[i].color,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(items[i].label, style: KTypography.labelMedium),
                    KMoney(
                      items[i].amount,
                      size: KMoneySize.medium,
                      style: TextStyle(
                        color: items[i].color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
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
