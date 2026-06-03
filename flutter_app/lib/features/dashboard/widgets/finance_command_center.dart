import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/dashboard_config.dart';
import '../data/dashboard_models.dart';
import '../data/dashboard_repository.dart';

class BusinessCommandCenter extends ConsumerWidget {
  final bool isDesktop;
  final DashboardVertical vertical;

  const BusinessCommandCenter({
    super.key,
    required this.isDesktop,
    required this.vertical,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todaySalesProvider);
    final ar = ref.watch(arSummaryProvider);
    final ap = ref.watch(apSummaryProvider);
    final expiring = ref.watch(expiringSoonProvider);
    final soAlerts = ref.watch(soAlertsProvider);
    final profile = _BusinessVerticalProfile.forVertical(vertical);
    final usesDispatchFlow = vertical == DashboardVertical.distributor ||
        vertical == DashboardVertical.pharmaDistributor ||
        vertical == DashboardVertical.manufacturer;

    final signals = [
      ar.when(
        loading: () => _CommandSignal.loading(profile.collectTitle),
        error: (_, __) => _CommandSignal.error(profile.collectTitle),
        data: (v) => _CommandSignal(
          title: profile.collectTitle,
          value: CurrencyFormatter.formatCompact(v.dueThisWeek),
          caption: v.dueThisWeekCount > 0
              ? '${v.dueThisWeekCount} ${profile.customerDocPlural} due this week'
              : 'no ${profile.customerDocPlural} due this week',
          icon: Icons.call_received_rounded,
          color: v.dueThisWeekCount > 0 ? KColors.warning : KColors.success,
          route: '/reports/ageing',
        ),
      ),
      ap.when(
        loading: () => _CommandSignal.loading(profile.payTitle),
        error: (_, __) => _CommandSignal.error(profile.payTitle),
        data: (v) => _CommandSignal(
          title: profile.payTitle,
          value: CurrencyFormatter.formatCompact(v.dueThisWeek),
          caption: v.dueThisWeekCount > 0
              ? '${v.dueThisWeekCount} ${profile.vendorDocPlural} due this week'
              : 'no ${profile.vendorDocPlural} due this week',
          icon: Icons.call_made_rounded,
          color: v.dueThisWeekCount > 0 ? KColors.error : KColors.success,
          route: '/bills',
        ),
      ),
      if (usesDispatchFlow)
        soAlerts.when(
          loading: () => _CommandSignal.loading(profile.velocityTitle),
          error: (_, __) => _CommandSignal.error(profile.velocityTitle),
          data: (v) {
            final ready = (v['confirmedCount'] as num?)?.toInt() ?? 0;
            final backorder = (v['backorderCount'] as num?)?.toInt() ?? 0;
            final partial = (v['partiallyShippedCount'] as num?)?.toInt() ?? 0;
            final draftChallans =
                (v['draftChallanCount'] as num?)?.toInt() ?? 0;
            final dispatched =
                (v['dispatchedChallanCount'] as num?)?.toInt() ?? 0;
            final active = ready + backorder + partial + draftChallans;
            final caption = active > 0
                ? '$ready ready SO, $draftChallans draft DC'
                : dispatched > 0
                    ? '$dispatched dispatched DC'
                    : 'no dispatch exceptions';
            return _CommandSignal(
              title: profile.velocityTitle,
              value: '$active',
              caption: caption,
              icon: Icons.local_shipping_rounded,
              color: active > 0 ? KColors.warning : KColors.success,
              route: profile.salesRoute,
            );
          },
        )
      else
        today.when(
          loading: () => _CommandSignal.loading(profile.velocityTitle),
          error: (_, __) => _CommandSignal.error(profile.velocityTitle),
          data: (v) {
            final isCounterFlow = profile.salesRoute == '/pos';
            final count =
                isCounterFlow ? v.posTransactionCount : v.transactionCount;
            final amount = isCounterFlow ? v.posSalesTotal : v.totalSales;
            return _CommandSignal(
              title: profile.velocityTitle,
              value: '$count',
              caption:
                  '${CurrencyFormatter.formatCompact(amount)} ${profile.salesCaption}',
              icon: Icons.speed_rounded,
              color: KColors.primary,
              route: profile.salesRoute,
            );
          },
        ),
      expiring.when(
        loading: () => _CommandSignal.loading(profile.riskTitle),
        error: (_, __) => _CommandSignal.error(profile.riskTitle),
        data: (items) => _CommandSignal(
          title: profile.riskTitle,
          value: '${items.length}',
          caption: items.isEmpty ? profile.noRiskText : profile.riskText,
          icon: profile.riskIcon,
          color: items.isEmpty ? KColors.success : KColors.warning,
          route: profile.riskRoute,
        ),
      ),
    ];

    return _CommandCenterShell(
      title: profile.title,
      subtitle: profile.subtitle,
      icon: profile.icon,
      accent: profile.accent,
      isDesktop: isDesktop,
      signals: signals,
      insight: _BusinessInsight(
        today: today,
        ar: ar,
        ap: ap,
        vertical: profile,
      ),
    );
  }
}

class _BusinessVerticalProfile {
  final String title;
  final String subtitle;
  final String collectTitle;
  final String payTitle;
  final String velocityTitle;
  final String riskTitle;
  final String customerDocPlural;
  final String vendorDocPlural;
  final String salesCaption;
  final String riskText;
  final String noRiskText;
  final String salesRoute;
  final String riskRoute;
  final IconData icon;
  final IconData riskIcon;
  final Color accent;

  const _BusinessVerticalProfile({
    required this.title,
    required this.subtitle,
    required this.collectTitle,
    required this.payTitle,
    required this.velocityTitle,
    required this.riskTitle,
    required this.customerDocPlural,
    required this.vendorDocPlural,
    required this.salesCaption,
    required this.riskText,
    required this.noRiskText,
    required this.salesRoute,
    required this.riskRoute,
    required this.icon,
    required this.riskIcon,
    required this.accent,
  });

  static _BusinessVerticalProfile forVertical(DashboardVertical vertical) {
    return switch (vertical) {
      DashboardVertical.manufacturer => const _BusinessVerticalProfile(
          title: 'Manufacturing Autopilot',
          subtitle: 'Orders, receivables, supplier exposure, and material risk',
          collectTitle: 'Collect',
          payTitle: 'Vendors',
          velocityTitle: 'Dispatch Flow',
          riskTitle: 'Material Risk',
          customerDocPlural: 'invoices',
          vendorDocPlural: 'vendor bills',
          salesCaption: 'in dispatch value',
          riskText: 'materials need planning review',
          noRiskText: 'material queue is clean',
          salesRoute: '/sales-orders',
          riskRoute: '/reorder',
          icon: Icons.precision_manufacturing_rounded,
          riskIcon: Icons.inventory_rounded,
          accent: KColors.accent,
        ),
      DashboardVertical.distributor => const _BusinessVerticalProfile(
          title: 'Distribution Autopilot',
          subtitle:
              'Dispatches, dealer collections, supplier dues, and stock risk',
          collectTitle: 'Dealer Collections',
          payTitle: 'Suppliers',
          velocityTitle: 'Dispatch Flow',
          riskTitle: 'Stock Risk',
          customerDocPlural: 'dealer invoices',
          vendorDocPlural: 'supplier bills',
          salesCaption: 'in dispatch value',
          riskText: 'items need refill or allocation review',
          noRiskText: 'stock allocation is clean',
          salesRoute: '/sales-orders',
          riskRoute: '/reorder',
          icon: Icons.local_shipping_rounded,
          riskIcon: Icons.inventory_2_rounded,
          accent: KColors.primary,
        ),
      DashboardVertical.pharmaDistributor => const _BusinessVerticalProfile(
          title: 'Pharma Distribution Autopilot',
          subtitle:
              'Dispatches, dealer collections, expiry risk, and supplier dues',
          collectTitle: 'Dealer Collections',
          payTitle: 'Suppliers',
          velocityTitle: 'Dispatch Flow',
          riskTitle: 'Expiry Risk',
          customerDocPlural: 'dealer invoices',
          vendorDocPlural: 'supplier bills',
          salesCaption: 'in medicine dispatch value',
          riskText: 'batches need expiry or allocation review',
          noRiskText: 'batch allocation is clean',
          salesRoute: '/sales-orders',
          riskRoute: '/inventory/near-expiry',
          icon: Icons.local_shipping_rounded,
          riskIcon: Icons.event_busy_rounded,
          accent: KColors.success,
        ),
      DashboardVertical.retail => const _BusinessVerticalProfile(
          title: 'Kirana Autopilot',
          subtitle: 'Counter sales, stock movement, credit, and payables',
          collectTitle: 'Credit Sales',
          payTitle: 'Suppliers',
          velocityTitle: 'Counter Flow',
          riskTitle: 'Stock Risk',
          customerDocPlural: 'credit invoices',
          vendorDocPlural: 'supplier bills',
          salesCaption: 'at counter today',
          riskText: 'items need refill or review',
          noRiskText: 'stock rhythm is clean',
          salesRoute: '/pos',
          riskRoute: '/reorder',
          icon: Icons.storefront_rounded,
          riskIcon: Icons.inventory_2_rounded,
          accent: KColors.primary,
        ),
      DashboardVertical.pharmacy => const _BusinessVerticalProfile(
          title: 'Pharmacy Autopilot',
          subtitle: 'Expiry risk, medicine flow, credit, and supplier dues',
          collectTitle: 'Collect',
          payTitle: 'Distributors',
          velocityTitle: 'Rx Flow',
          riskTitle: 'Expiry Risk',
          customerDocPlural: 'invoices',
          vendorDocPlural: 'distributor bills',
          salesCaption: 'in medicine sales',
          riskText: 'batches need expiry review',
          noRiskText: 'no expiry risk',
          salesRoute: '/pos',
          riskRoute: '/reorder',
          icon: Icons.local_pharmacy_rounded,
          riskIcon: Icons.event_busy_rounded,
          accent: KColors.success,
        ),
      DashboardVertical.service => const _BusinessVerticalProfile(
          title: 'Services Autopilot',
          subtitle: 'Billing, collections, profitability, and client follow-up',
          collectTitle: 'Collect',
          payTitle: 'Costs',
          velocityTitle: 'Billing Flow',
          riskTitle: 'Client Risk',
          customerDocPlural: 'invoices',
          vendorDocPlural: 'bills',
          salesCaption: 'billed today',
          riskText: 'client follow-ups need review',
          noRiskText: 'client risk is low',
          salesRoute: '/invoices',
          riskRoute: '/reports/ageing',
          icon: Icons.design_services_rounded,
          riskIcon: Icons.people_alt_rounded,
          accent: KColors.secondary,
        ),
      DashboardVertical.foodBeverage => const _BusinessVerticalProfile(
          title: 'F&B Autopilot',
          subtitle: 'Order flow, credits, supplier dues, and stock freshness',
          collectTitle: 'Collect',
          payTitle: 'Suppliers',
          velocityTitle: 'Order Flow',
          riskTitle: 'Freshness Risk',
          customerDocPlural: 'invoices',
          vendorDocPlural: 'supplier bills',
          salesCaption: 'in orders today',
          riskText: 'stock freshness needs review',
          noRiskText: 'freshness risk is low',
          salesRoute: '/pos',
          riskRoute: '/reorder',
          icon: Icons.restaurant_rounded,
          riskIcon: Icons.inventory_2_rounded,
          accent: KColors.warning,
        ),
      DashboardVertical.general => const _BusinessVerticalProfile(
          title: 'Business Autopilot',
          subtitle: 'Live operating signals and next best actions',
          collectTitle: 'Collect',
          payTitle: 'Pay',
          velocityTitle: 'Velocity',
          riskTitle: 'Stock Risk',
          customerDocPlural: 'invoices',
          vendorDocPlural: 'bills',
          salesCaption: 'today',
          riskText: 'items need review',
          noRiskText: 'no stock risk',
          salesRoute: '/invoices',
          riskRoute: '/reorder',
          icon: Icons.auto_awesome_rounded,
          riskIcon: Icons.inventory_2_rounded,
          accent: KColors.primary,
        ),
    };
  }
}

class AccountingControlCenter extends ConsumerWidget {
  final bool isDesktop;

  const AccountingControlCenter({super.key, required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arAging = ref.watch(arAgingProvider);
    final apAging = ref.watch(apAgingProvider);
    final cashFlow = ref.watch(cashFlowProvider);
    final profitLoss = ref.watch(profitLossProvider);

    final signals = [
      arAging.when(
        loading: () => const _CommandSignal.loading('AR Exposure'),
        error: (_, __) => const _CommandSignal.error('AR Exposure'),
        data: (v) {
          final overdue =
              v.days1to30 + v.days31to60 + v.days61to90 + v.days90plus;
          return _CommandSignal(
            title: 'AR Exposure',
            value: CurrencyFormatter.formatCompact(overdue),
            caption: overdue > 0 ? 'overdue receivables' : 'clean aging',
            icon: Icons.receipt_long_rounded,
            color: overdue > 0 ? KColors.warning : KColors.success,
            route: '/reports/ageing',
          );
        },
      ),
      apAging.when(
        loading: () => const _CommandSignal.loading('AP Exposure'),
        error: (_, __) => const _CommandSignal.error('AP Exposure'),
        data: (v) {
          final overdue =
              v.days1to30 + v.days31to60 + v.days61to90 + v.days90plus;
          return _CommandSignal(
            title: 'AP Exposure',
            value: CurrencyFormatter.formatCompact(overdue),
            caption: overdue > 0 ? 'overdue payables' : 'clean payables',
            icon: Icons.account_balance_wallet_rounded,
            color: overdue > 0 ? KColors.error : KColors.success,
            route: '/reports/ap-ageing',
          );
        },
      ),
      cashFlow.when(
        loading: () => const _CommandSignal.loading('Liquidity'),
        error: (_, __) => const _CommandSignal.error('Liquidity'),
        data: (v) => _CommandSignal(
          title: 'Liquidity',
          value: CurrencyFormatter.formatCompact(v.netCashFlow),
          caption: v.netCashFlow >= 0 ? 'net inflow' : 'net outflow',
          icon: Icons.waterfall_chart_rounded,
          color: v.netCashFlow >= 0 ? KColors.success : KColors.error,
          route: '/reports',
        ),
      ),
      profitLoss.when(
        loading: () => const _CommandSignal.loading('Close Pulse'),
        error: (_, __) => const _CommandSignal.error('Close Pulse'),
        data: (v) => _CommandSignal(
          title: 'Close Pulse',
          value: CurrencyFormatter.formatCompact(v.netProfit),
          caption: v.netProfit >= 0 ? 'profitable MTD' : 'loss MTD',
          icon: Icons.fact_check_rounded,
          color: v.netProfit >= 0 ? KColors.success : KColors.error,
          route: '/reports/profit-loss',
        ),
      ),
    ];

    return _CommandCenterShell(
      title: 'Accounting Control Tower',
      subtitle: 'Exceptions, exposure, liquidity, and close readiness',
      icon: Icons.radar_rounded,
      accent: KColors.accent,
      isDesktop: isDesktop,
      signals: signals,
      insight: _AccountingInsight(
        arAging: arAging,
        apAging: apAging,
        cashFlow: cashFlow,
      ),
    );
  }
}

class _CommandCenterShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final bool isDesktop;
  final List<Widget> signals;
  final Widget insight;

  const _CommandCenterShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.isDesktop,
    required this.signals,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(KSpacing.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accent, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: KTypography.h4.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: KTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Row(
                    children: [
                      for (var i = 0; i < signals.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: signals[i]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: insight),
              ],
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final signal in signals)
                  SizedBox(
                    width: MediaQuery.of(context).size.width < 520
                        ? double.infinity
                        : (MediaQuery.of(context).size.width - 70) / 2,
                    child: signal,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            insight,
          ],
        ],
      ),
    );
  }
}

class _CommandSignal extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final String? route;
  final bool loading;

  const _CommandSignal({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    this.route,
  }) : loading = false;

  const _CommandSignal.loading(this.title)
      : value = '...',
        caption = 'loading',
        icon = Icons.hourglass_empty_rounded,
        color = KColors.textHint,
        route = null,
        loading = true;

  const _CommandSignal.error(this.title)
      : value = '--',
        caption = 'not available',
        icon = Icons.error_outline_rounded,
        color = KColors.error,
        route = null,
        loading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(KSpacing.radiusSm),
      onTap: route == null ? null : () => context.go(route!),
      child: Container(
        height: 96,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(KSpacing.radiusSm),
          border: Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(icon, color: color, size: 14),
                ),
                const Spacer(),
                if (route != null)
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: cs.onSurfaceVariant),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: KTypography.amountMedium.copyWith(
                color: cs.onSurface,
                fontSize: 16,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              title,
              style: KTypography.labelSmall.copyWith(
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
    );
  }
}

class _BusinessInsight extends StatelessWidget {
  final AsyncValue<TodaySalesData> today;
  final AsyncValue<ArSummaryData> ar;
  final AsyncValue<ApSummaryData> ap;
  final _BusinessVerticalProfile vertical;

  const _BusinessInsight({
    required this.today,
    required this.ar,
    required this.ap,
    required this.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final todayData = today.valueOrNull;
    final arData = ar.valueOrNull;
    final apData = ap.valueOrNull;
    final creditShare = todayData != null && todayData.totalSales > 0
        ? todayData.creditTotal / todayData.totalSales
        : 0.0;
    final netDue = (arData?.dueThisWeek ?? 0.0) - (apData?.dueThisWeek ?? 0.0);

    String message;
    Color color;
    if (creditShare >= 0.45) {
      message =
          'Credit share is high today. Prioritize ${vertical.collectTitle.toLowerCase()} follow-up.';
      color = KColors.warning;
    } else if (netDue < 0) {
      message = 'This week has more cash out than incoming dues.';
      color = KColors.error;
    } else {
      message =
          '${vertical.title.replaceAll(' Autopilot', '')} rhythm looks healthy.';
      color = KColors.success;
    }

    return _InsightCard(
      label: 'AI Signal',
      message: message,
      color: color,
      actionLabel: 'Open reports',
      route: '/reports',
    );
  }
}

class _AccountingInsight extends StatelessWidget {
  final AsyncValue<ArAgingData> arAging;
  final AsyncValue<ApAgingData> apAging;
  final AsyncValue<CashFlowData> cashFlow;

  const _AccountingInsight({
    required this.arAging,
    required this.apAging,
    required this.cashFlow,
  });

  @override
  Widget build(BuildContext context) {
    final ar = arAging.valueOrNull;
    final ap = apAging.valueOrNull;
    final cf = cashFlow.valueOrNull;
    final ar90 = ar?.days90plus ?? 0.0;
    final ap90 = ap?.days90plus ?? 0.0;
    final netCash = cf?.netCashFlow ?? 0.0;

    String message;
    Color color;
    String route;
    if (ar90 > 0) {
      message = '90+ receivables exist. Prioritize collection before close.';
      color = KColors.error;
      route = '/reports/ageing';
    } else if (ap90 > 0) {
      message = 'Old payables exist. Review vendor exposure and holds.';
      color = KColors.warning;
      route = '/reports/ap-ageing';
    } else if (netCash < 0) {
      message = 'Cash flow is negative. Validate payment timing.';
      color = KColors.error;
      route = '/reports';
    } else {
      message = 'Controls look clean. Review journals and close checklist.';
      color = KColors.success;
      route = '/accounting/journal-entries';
    }

    return _InsightCard(
      label: 'Control Signal',
      message: message,
      color: color,
      actionLabel: 'Investigate',
      route: route,
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String label;
  final String message;
  final Color color;
  final String actionLabel;
  final String route;

  const _InsightCard({
    required this.label,
    required this.message,
    required this.color,
    required this.actionLabel,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      height: 82,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_alt_rounded, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: KTypography.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              message,
              style: KTypography.bodySmall.copyWith(
                color: cs.onSurface,
                height: 1.18,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => context.go(route),
            child: Text(
              actionLabel,
              style: KTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
