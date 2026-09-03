import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../data/flux_commentary_repository.dart';

class FluxCommentaryScreen extends ConsumerStatefulWidget {
  const FluxCommentaryScreen({super.key});

  @override
  ConsumerState<FluxCommentaryScreen> createState() => _FluxCommentaryScreenState();
}

class _FluxCommentaryScreenState extends ConsumerState<FluxCommentaryScreen> {
  String _selectedPeriod = 'MOM'; // MOM, QOQ, YOY
  String _filterType = 'ALL'; // ALL, EXPENSES, REVENUE, MATERIAL_ONLY
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final queryParams = {'periodType': _selectedPeriod};
    final fluxAsync = ref.watch(fluxReportQueryProvider(queryParams));

    return Scaffold(
      backgroundColor: KColors.bgApp,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(KSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Financial Flux & Variance Commentary', style: KTypography.h2),
                          const SizedBox(height: 4),
                          Text(
                            'Automated period-over-period comparative analysis, material cost spike detection, and management narrative.',
                            style: KTypography.bodyMedium.copyWith(color: KColors.textSecondary),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'MOM',
                                label: Text('Month-over-Month'),
                                icon: Icon(Icons.calendar_view_month_outlined, size: 16),
                              ),
                              ButtonSegment(
                                value: 'QOQ',
                                label: Text('Quarter-over-Quarter'),
                                icon: Icon(Icons.pie_chart_outline, size: 16),
                              ),
                              ButtonSegment(
                                value: 'YOY',
                                label: Text('Year-over-Year'),
                                icon: Icon(Icons.timeline_outlined, size: 16),
                              ),
                            ],
                            selected: {_selectedPeriod},
                            onSelectionChanged: (set) {
                              setState(() {
                                _selectedPeriod = set.first;
                              });
                            },
                            style: SegmentedButton.styleFrom(
                              textStyle: KTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: KSpacing.sm),
                          KButton(
                            label: 'Refresh',
                            icon: Icons.refresh,
                            variant: KButtonVariant.secondary,
                            onPressed: () => ref.invalidate(fluxReportQueryProvider(queryParams)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          fluxAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(
                child: KEmptyState(
                  icon: Icons.error_outline,
                  title: 'Failed to load flux commentary',
                  subtitle: err.toString(),
                ),
              ),
            ),
            data: (report) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Executive AI Commentary Narrative Banner
                    _buildExecutiveSummaryBanner(report),
                    const SizedBox(height: KSpacing.lg),

                    // 2. High-Level Summary KPI Cards
                    _buildSummaryKpiRow(report),
                    const SizedBox(height: KSpacing.xl),

                    // 3. Top Material Drivers Section
                    if (report.topDrivers.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.bolt, color: KColors.warning, size: 20),
                          const SizedBox(width: KSpacing.xs),
                          Text(
                            'Top Material Shift Drivers (${report.topDrivers.length})',
                            style: KTypography.h3,
                          ),
                        ],
                      ),
                      const SizedBox(height: KSpacing.sm),
                      _buildTopDriversGrid(report.topDrivers),
                      const SizedBox(height: KSpacing.xl),
                    ],

                    // 4. Detailed Account Variances Table with Filter
                    _buildAccountVarianceHeader(),
                    const SizedBox(height: KSpacing.sm),
                    _buildAccountVarianceTable(report),
                    const SizedBox(height: KSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveSummaryBanner(FinancialFluxReportModel report) {
    return Container(
      decoration: BoxDecoration(
        color: KColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        border: Border.all(color: KColors.primary.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(KSpacing.xs),
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                ),
                child: const Icon(Icons.auto_awesome, color: KColors.primary, size: 18),
              ),
              const SizedBox(width: KSpacing.sm),
              Text(
                'Management Briefing & Variance Commentary',
                style: KTypography.h4.copyWith(color: KColors.primary, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              KButton(
                label: 'Copy Briefing',
                icon: Icons.copy,
                variant: KButtonVariant.secondary,
                size: KButtonSize.small,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: report.executiveSummary));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Management briefing copied to clipboard')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Text(
            report.executiveSummary.isNotEmpty
                ? report.executiveSummary
                : 'No material financial variances identified between ${report.basePeriodLabel} and ${report.comparisonPeriodLabel}.',
            style: KTypography.bodyMedium.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryKpiRow(FinancialFluxReportModel report) {
    return Row(
      children: [
        // Revenue Card
        Expanded(
          child: _buildKpiCard(
            title: 'Total Revenue',
            baseLabel: report.basePeriodLabel,
            baseAmount: report.totalRevenueBase,
            compLabel: report.comparisonPeriodLabel,
            compAmount: report.totalRevenueComp,
            deltaAmount: report.revenueVarianceAmount,
            deltaPct: report.revenueVariancePercent,
            isPositiveGood: true,
          ),
        ),
        const SizedBox(width: KSpacing.md),

        // Expense Card
        Expanded(
          child: _buildKpiCard(
            title: 'Operating Expenses',
            baseLabel: report.basePeriodLabel,
            baseAmount: report.totalExpenseBase,
            compLabel: report.comparisonPeriodLabel,
            compAmount: report.totalExpenseComp,
            deltaAmount: report.expenseVarianceAmount,
            deltaPct: report.expenseVariancePercent,
            isPositiveGood: false,
          ),
        ),
        const SizedBox(width: KSpacing.md),

        // Net Profit Card
        Expanded(
          child: _buildKpiCard(
            title: 'Net Profit',
            baseLabel: report.basePeriodLabel,
            baseAmount: report.netProfitBase,
            compLabel: report.comparisonPeriodLabel,
            compAmount: report.netProfitComp,
            deltaAmount: report.netProfitVarianceAmount,
            deltaPct: report.netProfitVariancePercent,
            isPositiveGood: true,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String baseLabel,
    required double baseAmount,
    required String compLabel,
    required double compAmount,
    required double deltaAmount,
    required double deltaPct,
    required bool isPositiveGood,
  }) {
    final bool isIncrease = deltaAmount >= 0;
    final bool isFavorable = isPositiveGood ? isIncrease : !isIncrease;
    final Color trendColor = deltaAmount == 0
        ? KColors.textSecondary
        : (isFavorable ? KColors.success : KColors.error);

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: trendColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isIncrease ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: trendColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${deltaPct.abs().toStringAsFixed(1)}%',
                      style: KTypography.caption.copyWith(
                        color: trendColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          KMoney(
            compAmount,
            style: KTypography.h2.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: KSpacing.xs),
          Row(
            children: [
              Text(
                'vs $baseLabel: ',
                style: KTypography.caption.copyWith(color: KColors.textSecondary),
              ),
              KMoney(
                baseAmount,
                style: KTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: KColors.textSecondary,
                ),
              ),
              const SizedBox(width: KSpacing.xs),
              Text(
                '(${deltaAmount >= 0 ? '+' : ''}${deltaAmount.toStringAsFixed(0)})',
                style: KTypography.caption.copyWith(
                  color: trendColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopDriversGrid(List<AccountFluxLineModel> drivers) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: KSpacing.md,
            mainAxisSpacing: KSpacing.md,
            mainAxisExtent: 135,
          ),
          itemCount: drivers.length,
          itemBuilder: (context, index) {
            final d = drivers[index];
            final isExpenseSpike = d.fluxDriver == 'MATERIAL_EXPENSE_SPIKE';
            final isSaving = d.fluxDriver == 'MATERIAL_EXPENSE_SAVING';
            final Color badgeColor = isExpenseSpike
                ? KColors.error
                : (isSaving ? KColors.success : KColors.primary);

            return KCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          d.accountName,
                          style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      KStatusChip(status: d.fluxDriver.replaceAll('_', ' ')),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Variance', style: KTypography.caption.copyWith(color: KColors.textSecondary)),
                          KMoney(
                            d.varianceAmount,
                            style: KTypography.bodyLarge.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Shift %', style: KTypography.caption.copyWith(color: KColors.textSecondary)),
                          Text(
                            '${d.variancePercent >= 0 ? '+' : ''}${d.variancePercent.toStringAsFixed(1)}%',
                            style: KTypography.bodyLarge.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    d.commentary,
                    style: KTypography.caption.copyWith(color: KColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAccountVarianceHeader() {
    return Row(
      children: [
        Text('All Ledger Variances', style: KTypography.h3),
        const Spacer(),
        SizedBox(
          width: 220,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search ledger account...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusSm)),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.toLowerCase();
              });
            },
          ),
        ),
        const SizedBox(width: KSpacing.sm),
        DropdownButton<String>(
          value: _filterType,
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Accounts')),
            DropdownMenuItem(value: 'EXPENSES', child: Text('Expenses Only')),
            DropdownMenuItem(value: 'REVENUE', child: Text('Revenue Only')),
            DropdownMenuItem(value: 'MATERIAL_ONLY', child: Text('Material Only')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _filterType = val;
              });
            }
          },
        ),
      ],
    );
  }

  Widget _buildAccountVarianceTable(FinancialFluxReportModel report) {
    final filtered = report.accountLines.where((l) {
      if (_searchQuery.isNotEmpty &&
          !l.accountName.toLowerCase().contains(_searchQuery) &&
          !l.accountCode.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_filterType == 'EXPENSES' && l.accountType != 'EXPENSE') return false;
      if (_filterType == 'REVENUE' && l.accountType != 'REVENUE') return false;
      if (_filterType == 'MATERIAL_ONLY' && !l.isMaterial) return false;
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const KEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No accounts match criteria',
        subtitle: 'Try adjusting your search or filter options.',
      );
    }

    return KCard(
      padding: EdgeInsets.zero,
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(2),
          3: FlexColumnWidth(2),
          4: FlexColumnWidth(2),
          5: FlexColumnWidth(1.5),
          6: FlexColumnWidth(2),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: KColors.bgApp),
            children: [
              _tableCell('Account', isHeader: true),
              _tableCell('Type', isHeader: true),
              _tableCell(report.basePeriodLabel, isHeader: true, alignRight: true),
              _tableCell(report.comparisonPeriodLabel, isHeader: true, alignRight: true),
              _tableCell('Variance (₹)', isHeader: true, alignRight: true),
              _tableCell('Shift %', isHeader: true, alignRight: true),
              _tableCell('Driver Status', isHeader: true),
            ],
          ),
          ...filtered.map((line) {
            final isExpenseSpike = line.fluxDriver == 'MATERIAL_EXPENSE_SPIKE';
            final isSaving = line.fluxDriver == 'MATERIAL_EXPENSE_SAVING';
            final Color varianceColor = line.varianceAmount == 0
                ? KColors.textSecondary
                : (isExpenseSpike ? KColors.error : (isSaving ? KColors.success : KColors.textPrimary));

            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(KSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(line.accountName, style: KTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                      Text(line.accountCode, style: KTypography.caption.copyWith(color: KColors.textSecondary)),
                    ],
                  ),
                ),
                _tableCell(line.accountType),
                _tableCellMoney(line.basePeriodAmount),
                _tableCellMoney(line.comparisonPeriodAmount),
                _tableCellMoney(line.varianceAmount, color: varianceColor),
                _tableCell(
                  '${line.variancePercent >= 0 ? '+' : ''}${line.variancePercent.toStringAsFixed(1)}%',
                  alignRight: true,
                  style: TextStyle(
                    color: varianceColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(KSpacing.sm),
                  child: KStatusChip(status: line.fluxDriver.replaceAll('_', ' ')),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, bool alignRight = false, TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.all(KSpacing.sm),
      child: Text(
        text,
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: style ??
            (isHeader
                ? KTypography.caption.copyWith(fontWeight: FontWeight.w700, color: KColors.textSecondary)
                : KTypography.bodySmall),
      ),
    );
  }

  Widget _tableCellMoney(double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(KSpacing.sm),
      child: Align(
        alignment: Alignment.centerRight,
        child: KMoney(
          amount,
          style: KTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}