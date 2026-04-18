import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/dashboard_config.dart';
import '../data/dashboard_repository.dart';
import '../widgets/quick_action_grid.dart';
import '../widgets/overdue_invoices_widget.dart';
import '../widgets/sales_chart_widget.dart';
import '../widgets/low_stock_widget.dart';
import '../widgets/revenue_by_branch_widget.dart';
import '../widgets/purchases_by_branch_widget.dart';
import '../widgets/cash_position_widget.dart';
import '../widgets/recent_bills_widget.dart';
import '../widgets/top_selling_widget.dart';
import '../widgets/branch_selector_widget.dart';
import '../widgets/date_range_picker_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final config = DashboardConfig.forIndustry(authState.industry);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= KSpacing.desktopBreakpoint;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Invalidate dashboard providers so the pull-down kicks a
          // fresh fetch on every aggregation widget at once.
          ref.invalidate(todaySalesProvider);
          ref.invalidate(topSellingProvider);
          ref.invalidate(branchesProvider);
          ref.invalidate(apSummaryProvider);
          ref.invalidate(recentBillsProvider);
          ref.invalidate(arSummaryProvider);
          ref.invalidate(monthlyProfitProvider);
          await Future.delayed(const Duration(milliseconds: 200));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact greeting strip — single line, no banner
              _GreetingStrip(
                greeting: config.greeting,
                userName: authState.userName ?? 'User',
                orgName: authState.orgName ?? 'Your Business',
              ),
              KSpacing.vGapMd,

              // Filter bar — date range + branch selector. Updates the
              // shared dashboardFilterProvider which every aggregation
              // widget on the page keys off of.
              const _FilterBar(),
              KSpacing.vGapMd,

              // KPI Cards — now driven by todaySalesProvider for the
              // "today_sales" tile; other tiles still render static
              // placeholders until their own endpoints come online.
              _KpiGrid(kpis: config.kpis, isDesktop: isDesktop),
              KSpacing.vGapMd,

              // Quick Actions
              Text('Quick Actions', style: KTypography.h3),
              KSpacing.vGapSm,
              QuickActionGrid(actions: config.quickActions),
              KSpacing.vGapLg,

              // Dashboard Widgets
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: const [
                          SalesChartWidget(),
                          SizedBox(height: 16),
                          CashPositionWidget(),
                          SizedBox(height: 16),
                          RevenueByBranchWidget(),
                          SizedBox(height: 16),
                          PurchasesByBranchWidget(),
                          SizedBox(height: 16),
                          LowStockWidget(),
                        ],
                      ),
                    ),
                    KSpacing.hGapMd,
                    const Expanded(
                      child: Column(
                        children: [
                          TopSellingWidget(),
                          SizedBox(height: 16),
                          OverdueInvoicesWidget(),
                          SizedBox(height: 16),
                          RecentBillsWidget(),
                        ],
                      ),
                    ),
                  ],
                )
              else ...[
                const SalesChartWidget(),
                KSpacing.vGapMd,
                const CashPositionWidget(),
                KSpacing.vGapMd,
                const RevenueByBranchWidget(),
                KSpacing.vGapMd,
                const PurchasesByBranchWidget(),
                KSpacing.vGapMd,
                const TopSellingWidget(),
                KSpacing.vGapMd,
                const OverdueInvoicesWidget(),
                KSpacing.vGapMd,
                const RecentBillsWidget(),
                KSpacing.vGapMd,
                const LowStockWidget(),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/invoices/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
    );
  }
}

/// Compact single-row greeting. Replaces the oversized gradient hero banner.
///
/// Layout: small circular avatar + "Namaste, Dileep" + dot + org name. The
/// whole strip sits inside a low-elevation surface tile so it reads as part
/// of the page chrome rather than a marketing banner.
class _GreetingStrip extends StatelessWidget {
  final String greeting;
  final String userName;
  final String orgName;

  const _GreetingStrip({
    required this.greeting,
    required this.userName,
    required this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(KSpacing.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.waving_hand_rounded,
                size: 18, color: cs.primary),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$greeting, $userName',
                  style: KTypography.labelLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Icon(Icons.business_rounded,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        orgName,
                        style: KTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

/// KPI tile grid. The four tiles come from the industry config, but the
/// "today_sales" and "cash_collected" tiles are hydrated from the
/// shared [todaySalesProvider] so they respond to the date + branch
/// filter. Remaining tiles still fall back to a neutral placeholder
/// until their own endpoints come online.
class _KpiGrid extends ConsumerWidget {
  final List<KpiConfig> kpis;
  final bool isDesktop;

  const _KpiGrid({required this.kpis, required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crossAxisCount = isDesktop ? 4 : 2;
    final todaySalesAsync = ref.watch(todaySalesProvider);
    final apSummaryAsync = ref.watch(apSummaryProvider);
    final arSummaryAsync = ref.watch(arSummaryProvider);
    final monthlyProfitAsync = ref.watch(monthlyProfitProvider);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: KSpacing.md,
        mainAxisSpacing: KSpacing.md,
        // Fixed tile height — avoids RenderFlex overflow that aspect-ratio
        // grids produce when the card content is taller than the slot.
        mainAxisExtent: isDesktop ? 152 : 158,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];

        // Payables KPI hydrates from apSummaryProvider
        if (kpi.id == 'payables') {
          return apSummaryAsync.when(
            loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
            error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
            data: (ap) {
              final value =
                  CurrencyFormatter.formatCompact(ap.totalOutstanding);
              final trend = ap.overdueCount > 0
                  ? '${ap.overdueCount} overdue'
                  : 'All current';
              return KKpiCard(
                title: kpi.title,
                value: value,
                icon: kpi.icon,
                iconColor: kpi.color,
                trend: trend,
              );
            },
          );
        }

        // Receivables KPI hydrates from arSummaryProvider
        if (kpi.id == 'receivables') {
          return arSummaryAsync.when(
            loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
            error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
            data: (ar) {
              final value =
                  CurrencyFormatter.formatCompact(ar.totalOutstanding);
              final trend = ar.overdueCount > 0
                  ? '${ar.overdueCount} overdue'
                  : 'All current';
              return KKpiCard(
                title: kpi.title,
                value: value,
                icon: kpi.icon,
                iconColor: kpi.color,
                trend: trend,
              );
            },
          );
        }

        // Monthly Profit KPI hydrates from monthlyProfitProvider
        if (kpi.id == 'monthly_profit') {
          return monthlyProfitAsync.when(
            loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
            error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
            data: (mp) {
              final value = CurrencyFormatter.formatCompact(mp.grossProfit);
              return KKpiCard(
                title: kpi.title,
                value: value,
                icon: kpi.icon,
                iconColor: kpi.color,
                trend: 'MTD',
              );
            },
          );
        }

        return todaySalesAsync.when(
          loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
          error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
          data: (data) {
            final (value, trend) = _valueFor(kpi.id, data);
            return KKpiCard(
              title: kpi.title,
              value: value,
              icon: kpi.icon,
              iconColor: kpi.color,
              trend: trend,
            );
          },
        );
      },
    );
  }

  /// Resolve a KPI tile value + trend label from the today-sales payload.
  /// Non-sales KPIs (receivables, low-stock-count, etc.) fall back to a
  /// neutral placeholder — they'll get their own providers later.
  (String, String) _valueFor(String id, dynamic data) {
    switch (id) {
      case 'today_sales':
        return (CurrencyFormatter.formatCompact(data.revenue as double), 'Today');
      case 'cash_collected':
        return (CurrencyFormatter.formatCompact(data.cashCollected as double), 'Today');
      case 'monthly_revenue':
        return (CurrencyFormatter.formatCompact(data.revenue as double), 'MTD');
      case 'avg_order_value':
        return (CurrencyFormatter.formatCompact(data.revenue as double), 'Avg');
      default:
        return (CurrencyFormatter.formatCompact(0), '--');
    }
  }
}

class _KpiPlaceholder extends StatelessWidget {
  final KpiConfig kpi;
  final String value;
  const _KpiPlaceholder({required this.kpi, required this.value});

  @override
  Widget build(BuildContext context) {
    return KKpiCard(
      title: kpi.title,
      value: value,
      icon: kpi.icon,
      iconColor: kpi.color,
      trend: '--',
    );
  }
}

/// Dashboard-level filter bar: date-range picker + branch selector.
/// Writes straight to `dashboardFilterProvider`. Layout shifts to a
/// column on narrow screens so neither control gets squeezed.
class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final stacked = width < 600;

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          DashboardDateRangePicker(),
          SizedBox(height: 8),
          BranchSelectorWidget(),
        ],
      );
    }
    return Row(
      children: const [
        Expanded(child: DashboardDateRangePicker()),
        SizedBox(width: 12),
        Expanded(child: BranchSelectorWidget()),
      ],
    );
  }
}
