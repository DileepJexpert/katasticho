import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/dashboard_repository.dart';
import '../widgets/ar_aging_card.dart';
import '../widgets/bills_to_pay_card.dart';
import '../widgets/cash_flow_card.dart';
import '../widgets/finance_command_center.dart';
import '../widgets/outstanding_receivable_card.dart';
import '../widgets/overdue_invoices_widget.dart';
import '../widgets/pnl_summary_card.dart';
import '../widgets/recent_journals_widget.dart';
import '../widgets/report_links_card.dart';
import '../widgets/sales_chart_widget.dart';
import '../widgets/top_selling_widget.dart';

class AccountingDashboardScreen extends ConsumerStatefulWidget {
  const AccountingDashboardScreen({super.key});

  @override
  ConsumerState<AccountingDashboardScreen> createState() =>
      _AccountingDashboardScreenState();
}

class _AccountingDashboardScreenState
    extends ConsumerState<AccountingDashboardScreen> {
  String? _expandedAging;

  void _toggleAging(String id) {
    setState(() {
      _expandedAging = _expandedAging == id ? null : id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= KSpacing.desktopBreakpoint;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyProfitProvider);
          ref.invalidate(arSummaryProvider);
          ref.invalidate(apSummaryProvider);
          ref.invalidate(profitLossProvider);
          ref.invalidate(cashFlowProvider);
          ref.invalidate(arAgingProvider);
          ref.invalidate(apAgingProvider);
          ref.invalidate(revenueTrendProvider(365));
          ref.invalidate(recentJournalsProvider);
          ref.invalidate(outstandingReceivableProvider);
          ref.invalidate(topSellingProvider);
          await Future.delayed(const Duration(milliseconds: 200));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AccountingHeader(
                userName: authState.userName ?? 'User',
                orgName: authState.orgName ?? 'Your Business',
              ),
              KSpacing.vGapMd,
              AccountingControlCenter(isDesktop: isDesktop),
              KSpacing.vGapMd,
              _AccountingKpis(
                isDesktop: isDesktop,
                expandedAging: _expandedAging,
                onToggleAging: _toggleAging,
              ),
              KSpacing.vGapMd,
              _LedgerHealthStrip(isDesktop: isDesktop),
              KSpacing.vGapLg,
              if (isDesktop) _buildDesktopLayout() else _buildMobileLayout(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: const [
              SalesChartWidget(),
              SizedBox(height: 16),
              PnlSummaryCard(),
              SizedBox(height: 16),
              CashFlowCard(),
              SizedBox(height: 16),
              OverdueInvoicesWidget(),
            ],
          ),
        ),
        KSpacing.hGapMd,
        const Expanded(
          flex: 2,
          child: Column(
            children: [
              OutstandingReceivableCard(),
              SizedBox(height: 16),
              BillsToPayCard(),
              SizedBox(height: 16),
              TopSellingWidget(),
              SizedBox(height: 16),
              ReportLinksCard(),
              SizedBox(height: 16),
              RecentJournalsWidget(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: const [
        SalesChartWidget(),
        SizedBox(height: 12),
        OutstandingReceivableCard(),
        SizedBox(height: 12),
        PnlSummaryCard(),
        SizedBox(height: 12),
        CashFlowCard(),
        SizedBox(height: 12),
        BillsToPayCard(),
        SizedBox(height: 12),
        OverdueInvoicesWidget(),
        SizedBox(height: 12),
        TopSellingWidget(),
        SizedBox(height: 12),
        ReportLinksCard(),
        SizedBox(height: 12),
        RecentJournalsWidget(),
      ],
    );
  }
}

class _LedgerHealthStrip extends ConsumerWidget {
  final bool isDesktop;

  const _LedgerHealthStrip({required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arAging = ref.watch(arAgingProvider);
    final apAging = ref.watch(apAgingProvider);
    final cashFlow = ref.watch(cashFlowProvider);
    final profitLoss = ref.watch(profitLossProvider);

    final cards = [
      arAging.when(
        loading: () => const _HealthTile.loading(title: 'AR Risk'),
        error: (_, __) => const _HealthTile.error(title: 'AR Risk'),
        data: (ar) {
          final overdue =
              ar.days1to30 + ar.days31to60 + ar.days61to90 + ar.days90plus;
          final ratio =
              ar.totalOutstanding > 0 ? overdue / ar.totalOutstanding : 0.0;
          return _HealthTile(
            title: 'AR Risk',
            value: CurrencyFormatter.formatCompact(overdue),
            caption: overdue > 0 ? 'overdue receivables' : 'all current',
            icon: Icons.receipt_long_rounded,
            color: _riskColor(ratio),
          );
        },
      ),
      apAging.when(
        loading: () => const _HealthTile.loading(title: 'AP Risk'),
        error: (_, __) => const _HealthTile.error(title: 'AP Risk'),
        data: (ap) {
          final overdue =
              ap.days1to30 + ap.days31to60 + ap.days61to90 + ap.days90plus;
          final ratio =
              ap.totalOutstanding > 0 ? overdue / ap.totalOutstanding : 0.0;
          return _HealthTile(
            title: 'AP Risk',
            value: CurrencyFormatter.formatCompact(overdue),
            caption: overdue > 0 ? 'overdue payables' : 'all current',
            icon: Icons.payments_rounded,
            color: _riskColor(ratio),
          );
        },
      ),
      cashFlow.when(
        loading: () => const _HealthTile.loading(title: 'Cash Flow'),
        error: (_, __) => const _HealthTile.error(title: 'Cash Flow'),
        data: (cf) => _HealthTile(
          title: 'Cash Flow',
          value: CurrencyFormatter.formatCompact(cf.netCashFlow),
          caption: cf.netCashFlow >= 0 ? 'net inflow' : 'net outflow',
          icon: cf.netCashFlow >= 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          color: cf.netCashFlow >= 0 ? KColors.success : KColors.error,
        ),
      ),
      profitLoss.when(
        loading: () => const _HealthTile.loading(title: 'P&L'),
        error: (_, __) => const _HealthTile.error(title: 'P&L'),
        data: (pl) => _HealthTile(
          title: 'P&L',
          value: CurrencyFormatter.formatCompact(pl.netProfit),
          caption: pl.netProfit >= 0 ? 'net profit MTD' : 'net loss MTD',
          icon: pl.netProfit >= 0
              ? Icons.insights_rounded
              : Icons.warning_amber_rounded,
          color: pl.netProfit >= 0 ? KColors.success : KColors.error,
        ),
      ),
    ];

    if (!isDesktop) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: cards[1]),
            ],
          ),
          const SizedBox(height: KSpacing.sm),
          Row(
            children: [
              Expanded(child: cards[2]),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: cards[3]),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: KSpacing.md),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  static Color _riskColor(double ratio) {
    if (ratio >= 0.35) return KColors.error;
    if (ratio >= 0.12) return KColors.warning;
    return KColors.success;
  }
}

class _HealthTile extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final bool isLoading;

  const _HealthTile({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  }) : isLoading = false;

  const _HealthTile.loading({required this.title})
      : value = '...',
        caption = 'loading',
        icon = Icons.hourglass_empty_rounded,
        color = KColors.textHint,
        isLoading = true;

  const _HealthTile.error({required this.title})
      : value = '--',
        caption = 'not available',
        icon = Icons.error_outline_rounded,
        color = KColors.error,
        isLoading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 82,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(KSpacing.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(9),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KTypography.labelSmall.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: KTypography.amountSmall.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  caption,
                  style: KTypography.labelSmall.copyWith(
                    color: cs.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountingHeader extends StatelessWidget {
  final String userName;
  final String orgName;

  const _AccountingHeader({required this.userName, required this.orgName});

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
            child: Icon(Icons.account_balance_rounded,
                size: 18, color: cs.primary),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Accounting Dashboard',
                  style: KTypography.labelLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
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
                        style: KTypography.bodySmall
                            .copyWith(color: cs.onSurfaceVariant),
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

class _AccountingKpis extends ConsumerWidget {
  final bool isDesktop;
  final String? expandedAging;
  final ValueChanged<String> onToggleAging;

  const _AccountingKpis({
    required this.isDesktop,
    required this.expandedAging,
    required this.onToggleAging,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cols = isDesktop ? 4 : 2;
    final tileH = isDesktop ? 112.0 : 116.0;

    final monthlyProfitAsync = ref.watch(monthlyProfitProvider);
    final arSummaryAsync = ref.watch(arSummaryProvider);
    final apSummaryAsync = ref.watch(apSummaryProvider);
    final profitLossAsync = ref.watch(profitLossProvider);

    final tiles = <Widget>[
      monthlyProfitAsync.when(
        loading: () =>
            _placeholder('Revenue', Icons.monetization_on, KColors.primary),
        error: (_, __) => _placeholder(
            'Revenue', Icons.monetization_on, KColors.primary,
            value: '--'),
        data: (mp) => KKpiCard(
          title: 'Revenue',
          value: CurrencyFormatter.formatCompact(mp.revenue),
          icon: Icons.monetization_on,
          iconColor: KColors.primary,
          trend: 'MTD',
        ),
      ),
      arSummaryAsync.when(
        loading: () => _placeholder(
            'Receivables', Icons.account_balance_wallet, KColors.warning),
        error: (_, __) => _placeholder(
            'Receivables', Icons.account_balance_wallet, KColors.warning,
            value: '--'),
        data: (ar) {
          final String trend;
          final bool trendPositive;
          if (ar.overdueCount > 0) {
            trend = '${ar.overdueCount} overdue';
            trendPositive = false;
          } else {
            trend = 'All current';
            trendPositive = true;
          }
          return KKpiCard(
            title: 'Receivables',
            value: CurrencyFormatter.formatCompact(ar.totalOutstanding),
            icon: Icons.account_balance_wallet,
            iconColor: KColors.warning,
            trend: trend,
            trendPositive: trendPositive,
            showChevron: true,
            expanded: expandedAging == 'ar',
            onTap: () => onToggleAging('ar'),
          );
        },
      ),
      apSummaryAsync.when(
        loading: () => _placeholder('Payables', Icons.payment, KColors.error),
        error: (_, __) =>
            _placeholder('Payables', Icons.payment, KColors.error, value: '--'),
        data: (ap) {
          final String trend;
          final bool trendPositive;
          if (ap.overdueCount > 0) {
            trend = '${ap.overdueCount} overdue';
            trendPositive = false;
          } else {
            trend = 'All current';
            trendPositive = true;
          }
          return KKpiCard(
            title: 'Payables',
            value: CurrencyFormatter.formatCompact(ap.totalOutstanding),
            icon: Icons.payment,
            iconColor: KColors.error,
            trend: trend,
            trendPositive: trendPositive,
            showChevron: true,
            expanded: expandedAging == 'ap',
            onTap: () => onToggleAging('ap'),
          );
        },
      ),
      profitLossAsync.when(
        loading: () =>
            _placeholder('Net Profit', Icons.trending_up, KColors.success),
        error: (_, __) => _placeholder(
            'Net Profit', Icons.trending_up, KColors.success,
            value: '--'),
        data: (pl) => KKpiCard(
          title: 'Net Profit',
          value: CurrencyFormatter.formatCompact(pl.netProfit),
          icon: pl.netProfit >= 0 ? Icons.trending_up : Icons.trending_down,
          iconColor: pl.netProfit >= 0 ? KColors.success : KColors.error,
          trend: 'MTD',
        ),
      ),
    ];

    final children = <Widget>[];

    for (var r = 0; r < tiles.length; r += cols) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(height: KSpacing.md));
      }

      final end = (r + cols).clamp(0, tiles.length);
      final rowWidgets = <Widget>[];
      for (var c = r; c < end; c++) {
        if (c > r) rowWidgets.add(const SizedBox(width: KSpacing.md));
        rowWidgets
            .add(Expanded(child: SizedBox(height: tileH, child: tiles[c])));
      }
      for (var c = end; c < r + cols; c++) {
        rowWidgets.add(const SizedBox(width: KSpacing.md));
        rowWidgets.add(Expanded(child: SizedBox(height: tileH)));
      }
      children.add(Row(children: rowWidgets));

      // Aging expansion panels
      final kpiIds = ['revenue', 'receivables', 'payables', 'net_profit'];
      int? expandedCol;
      for (var c = r; c < end; c++) {
        final id = kpiIds[c];
        if ((id == 'receivables' && expandedAging == 'ar') ||
            (id == 'payables' && expandedAging == 'ap')) {
          expandedCol = c - r;
          break;
        }
      }

      final hasExpandable = kpiIds
          .sublist(r, end)
          .any((k) => k == 'receivables' || k == 'payables');

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
          Expanded(child: _AgingPanel(type: expandedAging!)),
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

  Widget _placeholder(String title, IconData icon, Color color,
      {String value = '...'}) {
    return KKpiCard(
        title: title, value: value, icon: icon, iconColor: color, trend: '--');
  }
}

class _AgingPanel extends ConsumerWidget {
  final String type;
  const _AgingPanel({required this.type});

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
