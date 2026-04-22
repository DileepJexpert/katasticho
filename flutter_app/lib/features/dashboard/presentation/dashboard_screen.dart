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
import '../widgets/aaj_ka_hisaab_card.dart';
import '../widgets/ar_aging_card.dart';
import '../widgets/week_trend_card.dart';
import '../widgets/top_selling_widget.dart';
import '../widgets/udhari_card.dart';
import '../widgets/low_stock_widget.dart';
import '../widgets/bills_to_pay_card.dart';
import '../widgets/expiring_soon_widget.dart';
import '../widgets/overdue_invoices_widget.dart';
import '../widgets/sales_chart_widget.dart';
import '../widgets/revenue_by_branch_widget.dart';
import '../widgets/purchases_by_branch_widget.dart';
import '../widgets/recent_bills_widget.dart';
import '../widgets/branch_selector_widget.dart';
import '../widgets/date_range_picker_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _expandedAging;

  void _toggleAging(String id) {
    setState(() {
      _expandedAging = _expandedAging == id ? null : id;
    });
  }

  static const _retailIndustries = {'KIRANA', 'PHARMACY'};

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final config = DashboardConfig.forIndustry(authState.industry);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= KSpacing.desktopBreakpoint;
    final isRetail = _retailIndustries.contains(authState.industry);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dailySummaryProvider);
          ref.invalidate(todaySalesProvider);
          ref.invalidate(topSellingProvider);
          ref.invalidate(branchesProvider);
          ref.invalidate(apSummaryProvider);
          ref.invalidate(recentBillsProvider);
          ref.invalidate(arSummaryProvider);
          ref.invalidate(monthlyProfitProvider);
          ref.invalidate(arAgingProvider);
          ref.invalidate(apAgingProvider);
          ref.invalidate(expiringSoonProvider);
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
              _GreetingStrip(
                greeting: config.greeting,
                userName: authState.userName ?? 'User',
                orgName: authState.orgName ?? 'Your Business',
              ),
              KSpacing.vGapMd,

              if (isRetail)
                _RetailDashboard(isDesktop: isDesktop)
              else
                _AccountingDashboard(
                  config: config,
                  isDesktop: isDesktop,
                  expandedAging: _expandedAging,
                  onToggleAging: _toggleAging,
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(isRetail ? '/pos' : '/invoices/create'),
        icon: Icon(isRetail ? Icons.point_of_sale_rounded : Icons.add),
        label: Text(isRetail ? 'New Sale' : 'New Invoice'),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  RETAIL DASHBOARD — for KIRANA / PHARMACY
// ═══════════════════════════════════════════════════════════════════

class _RetailDashboard extends StatelessWidget {
  final bool isDesktop;
  const _RetailDashboard({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    if (isDesktop) return _buildDesktop();
    return _buildMobile();
  }

  Widget _buildMobile() {
    return Column(
      children: const [
        TodaySummaryCard(),
        SizedBox(height: 12),
        WeekTrendCard(),
        SizedBox(height: 12),
        TopSellingWidget(),
        SizedBox(height: 12),
        CreditDueCard(),
        SizedBox(height: 12),
        LowStockWidget(),
        SizedBox(height: 12),
        BillsToPayCard(),
        SizedBox(height: 12),
        ExpiringSoonWidget(),
      ],
    );
  }

  Widget _buildDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: const [
              TodaySummaryCard(),
              SizedBox(height: 12),
              WeekTrendCard(),
              SizedBox(height: 12),
              TopSellingWidget(),
              SizedBox(height: 12),
              ExpiringSoonWidget(),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Column(
            children: const [
              CreditDueCard(),
              SizedBox(height: 12),
              LowStockWidget(),
              SizedBox(height: 12),
              BillsToPayCard(),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  ACCOUNTING DASHBOARD — for TRADING / SERVICES / MANUFACTURING / etc.
// ═══════════════════════════════════════════════════════════════════

class _AccountingDashboard extends StatelessWidget {
  final DashboardConfig config;
  final bool isDesktop;
  final String? expandedAging;
  final ValueChanged<String> onToggleAging;

  const _AccountingDashboard({
    required this.config,
    required this.isDesktop,
    required this.expandedAging,
    required this.onToggleAging,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FilterBar(),
        KSpacing.vGapMd,

        _KpiGrid(
          kpis: config.kpis,
          isDesktop: isDesktop,
          expandedAging: expandedAging,
          onToggleAging: onToggleAging,
        ),

        KSpacing.vGapLg,

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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════════════

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
    final cols = isDesktop ? 4 : 2;
    final tileH = isDesktop ? 112.0 : 116.0;
    final todaySalesAsync = ref.watch(todaySalesProvider);
    final apSummaryAsync = ref.watch(apSummaryProvider);
    final arSummaryAsync = ref.watch(arSummaryProvider);
    final monthlyProfitAsync = ref.watch(monthlyProfitProvider);

    Widget buildTile(KpiConfig kpi) {
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
                  '${CurrencyFormatter.formatCompact(ap.dueThisWeek)} this wk';
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
                  '${CurrencyFormatter.formatCompact(ar.dueThisWeek)} this wk';
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

      if (kpi.id == 'monthly_profit') {
        return monthlyProfitAsync.when(
          loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
          error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
          data: (mp) => KKpiCard(
            title: kpi.title,
            value: CurrencyFormatter.formatCompact(mp.grossProfit),
            icon: kpi.icon,
            iconColor: kpi.color,
            trend: 'MTD',
          ),
        );
      }

      if (kpi.id == 'monthly_revenue') {
        return monthlyProfitAsync.when(
          loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
          error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
          data: (mp) => KKpiCard(
            title: kpi.title,
            value: CurrencyFormatter.formatCompact(mp.revenue),
            icon: kpi.icon,
            iconColor: kpi.color,
            trend: 'MTD',
          ),
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
    }

    final tiles = kpis.map(buildTile).toList();

    final children = <Widget>[];

    for (var r = 0; r < tiles.length; r += cols) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: KSpacing.md));
      }

      final end = (r + cols).clamp(0, tiles.length);

      final rowWidgets = <Widget>[];
      for (var c = r; c < end; c++) {
        if (c > r) rowWidgets.add(const SizedBox(width: KSpacing.md));
        rowWidgets.add(
          Expanded(child: SizedBox(height: tileH, child: tiles[c])),
        );
      }
      for (var c = end; c < r + cols; c++) {
        rowWidgets.add(const SizedBox(width: KSpacing.md));
        rowWidgets.add(Expanded(child: SizedBox(height: tileH)));
      }
      children.add(Row(children: rowWidgets));

      int? expandedCol;
      for (var c = r; c < end; c++) {
        final id = kpis[c].id;
        if ((id == 'receivables' && expandedAging == 'ar') ||
            (id == 'payables' && expandedAging == 'ap')) {
          expandedCol = c - r;
          break;
        }
      }

      final hasExpandable = kpis
          .sublist(r, end)
          .any((k) => k.id == 'receivables' || k.id == 'payables');

      if (hasExpandable) {
        children.add(
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expandedCol == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _buildAlignedPanel(cols, expandedCol),
                  ),
          ),
        );
      }
    }

    return Column(children: children);
  }

  Widget _buildAlignedPanel(int cols, int column) {
    final rowChildren = <Widget>[];
    for (var c = 0; c < cols; c++) {
      if (c > 0) rowChildren.add(const SizedBox(width: KSpacing.md));
      if (c == column) {
        rowChildren.add(
          Expanded(child: _AgingPanelCard(type: expandedAging!)),
        );
      } else {
        rowChildren.add(const Expanded(child: SizedBox.shrink()));
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rowChildren,
    );
  }

  (String, String) _valueFor(String id, dynamic data) {
    switch (id) {
      case 'today_sales':
        return (CurrencyFormatter.formatCompact(data.totalSales as double), 'Today');
      case 'cash_collected':
        return (CurrencyFormatter.formatCompact(data.cashUpiTotal as double), 'Today');
      case 'avg_order_value':
        final count = (data.transactionCount as int);
        final avg = count > 0 ? (data.totalSales as double) / count : 0.0;
        return (CurrencyFormatter.formatCompact(avg), 'Avg');
      default:
        return (CurrencyFormatter.formatCompact(0), '--');
    }
  }
}

class _AgingPanelCard extends ConsumerWidget {
  final String type;
  const _AgingPanelCard({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isAr = type == 'ar';
    final accentColor =
        isAr ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    final title = isAr ? 'AR Aging' : 'AP Aging';
    final route = isAr ? '/reports/ageing' : '/reports/ap-ageing';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(KSpacing.radiusLg),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: accentColor),
          if (isAr)
            ref.watch(arAgingProvider).when(
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Failed to load'),
                  ),
                  data: (ar) => AgingBreakdown(
                    title: title,
                    totalOutstanding: ar.totalOutstanding,
                    current: ar.current,
                    days1to30: ar.days1to30,
                    days31to60: ar.days31to60,
                    days61to90: ar.days61to90,
                    days90plus: ar.days90plus,
                    reportRoute: route,
                    accentColor: accentColor,
                    compact: true,
                  ),
                )
          else
            ref.watch(apAgingProvider).when(
                  loading: () => const SizedBox(
                    height: 120,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Failed to load'),
                  ),
                  data: (ap) => AgingBreakdown(
                    title: title,
                    totalOutstanding: ap.totalOutstanding,
                    current: ap.current,
                    days1to30: ap.days1to30,
                    days31to60: ap.days31to60,
                    days61to90: ap.days61to90,
                    days90plus: ap.days90plus,
                    reportRoute: route,
                    accentColor: accentColor,
                    compact: true,
                  ),
                ),
        ],
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
