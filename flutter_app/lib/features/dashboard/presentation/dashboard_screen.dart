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
import '../widgets/ar_aging_card.dart';
import '../widgets/overdue_invoices_widget.dart';
import '../widgets/sales_chart_widget.dart';
import '../widgets/low_stock_widget.dart';
import '../widgets/revenue_by_branch_widget.dart';
import '../widgets/purchases_by_branch_widget.dart';
import '../widgets/recent_bills_widget.dart';
import '../widgets/top_selling_widget.dart';
import '../widgets/branch_selector_widget.dart';
import '../widgets/date_range_picker_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _expandedAging; // 'ar' | 'ap' | null

  void _toggleAging(String id) {
    setState(() {
      _expandedAging = _expandedAging == id ? null : id;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          ref.invalidate(arAgingProvider);
          ref.invalidate(apAgingProvider);
          // revenueTrendProvider is a family — invalidate both common windows
          ref.invalidate(revenueTrendProvider(7));
          ref.invalidate(revenueTrendProvider(30));
          ref.invalidate(revenueTrendProvider(90));
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

              // KPI Cards
              _KpiGrid(
                kpis: config.kpis,
                isDesktop: isDesktop,
                expandedAging: _expandedAging,
                onToggleAging: _toggleAging,
              ),

              // Inline aging drill-down — slides in below the KPI grid
              // when a Receivables/Payables tile is tapped (Zoho-style).
              _InlineAgingPanel(expandedAging: _expandedAging),
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
  final String? expandedAging;
  final ValueChanged<String> onToggleAging;

  const _KpiGrid({
    required this.kpis,
    required this.isDesktop,
    required this.expandedAging,
    required this.onToggleAging,
  });

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
        mainAxisExtent: isDesktop ? 112 : 116,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];

        // Payables KPI — tap expands AP aging panel inline below the grid
        if (kpi.id == 'payables') {
          return apSummaryAsync.when(
            loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
            error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
            data: (ap) {
              final value =
                  CurrencyFormatter.formatCompact(ap.totalOutstanding);
              final String trend;
              final bool trendPositive;
              if (ap.dueThisWeekCount > 0) {
                trend =
                    '${CurrencyFormatter.formatCompact(ap.dueThisWeek)} this week';
                trendPositive = false;
              } else if (ap.overdueCount > 0) {
                trend = '${ap.overdueCount} overdue';
                trendPositive = false;
              } else {
                trend = 'All current';
                trendPositive = true;
              }
              return KKpiCard(
                title: kpi.title,
                value: value,
                icon: kpi.icon,
                iconColor: kpi.color,
                trend: trend,
                trendPositive: trendPositive,
                showChevron: true,
                expanded: expandedAging == 'ap',
                onTap: () => onToggleAging('ap'),
              );
            },
          );
        }

        // Receivables KPI — tap expands AR aging panel inline below the grid
        if (kpi.id == 'receivables') {
          return arSummaryAsync.when(
            loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
            error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
            data: (ar) {
              final value =
                  CurrencyFormatter.formatCompact(ar.totalOutstanding);
              final String trend;
              final bool trendPositive;
              if (ar.dueThisWeekCount > 0) {
                trend =
                    '${CurrencyFormatter.formatCompact(ar.dueThisWeek)} this week';
                trendPositive = true;
              } else if (ar.overdueCount > 0) {
                trend = '${ar.overdueCount} overdue';
                trendPositive = false;
              } else {
                trend = 'All current';
                trendPositive = true;
              }
              return KKpiCard(
                title: kpi.title,
                value: value,
                icon: kpi.icon,
                iconColor: kpi.color,
                trend: trend,
                trendPositive: trendPositive,
                showChevron: true,
                expanded: expandedAging == 'ar',
                onTap: () => onToggleAging('ar'),
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

        // Monthly Revenue KPI also reads MTD revenue from monthlyProfitProvider
        // so it doesn't get collapsed to zero by the date-range filter.
        if (kpi.id == 'monthly_revenue') {
          return monthlyProfitAsync.when(
            loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
            error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
            data: (mp) {
              final value = CurrencyFormatter.formatCompact(mp.revenue);
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
      case 'avg_order_value':
        return (CurrencyFormatter.formatCompact(data.revenue as double), 'Avg');
      default:
        return (CurrencyFormatter.formatCompact(0), '--');
    }
  }
}

/// Inline aging drill-down panel — replaces the bottom sheet. Slides in
/// below the KPI grid with an AnimatedSize transition, Zoho-style.
class _InlineAgingPanel extends ConsumerWidget {
  final String? expandedAging;
  const _InlineAgingPanel({required this.expandedAging});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: expandedAging == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: KSpacing.md),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      BorderRadius.circular(KSpacing.radiusLg),
                  border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: expandedAging == 'ar'
                    ? const _InlineArAging()
                    : const _InlineApAging(),
              ),
            ),
    );
  }
}

class _InlineArAging extends ConsumerWidget {
  const _InlineArAging();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(arAgingProvider).when(
          loading: () => const SizedBox(
            height: 160,
            child:
                Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox(
            height: 100,
            child: Center(child: Text('Failed to load aging data')),
          ),
          data: (ar) => AgingBreakdown(
            title: 'Receivables Aging',
            totalOutstanding: ar.totalOutstanding,
            current: ar.current,
            days1to30: ar.days1to30,
            days31to60: ar.days31to60,
            days61to90: ar.days61to90,
            days90plus: ar.days90plus,
            reportRoute: '/reports/ageing',
            accentColor: const Color(0xFFF59E0B),
          ),
        );
  }
}

class _InlineApAging extends ConsumerWidget {
  const _InlineApAging();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(apAgingProvider).when(
          loading: () => const SizedBox(
            height: 160,
            child:
                Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const SizedBox(
            height: 100,
            child: Center(child: Text('Failed to load aging data')),
          ),
          data: (ap) => AgingBreakdown(
            title: 'Payables Aging',
            totalOutstanding: ap.totalOutstanding,
            current: ap.current,
            days1to30: ap.days1to30,
            days31to60: ap.days31to60,
            days61to90: ap.days61to90,
            days90plus: ap.days90plus,
            reportRoute: '/reports/ap-ageing',
            accentColor: const Color(0xFFEF4444),
          ),
        );
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
