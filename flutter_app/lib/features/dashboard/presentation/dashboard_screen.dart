import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/business_capabilities.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../onboarding/data/organisation_repository.dart';
import '../data/dashboard_config.dart';
import '../data/dashboard_repository.dart';
import '../widgets/aaj_ka_hisaab_card.dart';
import '../widgets/ar_aging_card.dart';
import '../widgets/week_trend_card.dart';
import '../widgets/top_selling_widget.dart';
import '../widgets/credit_due_card.dart';
import '../widgets/low_stock_widget.dart';
import '../widgets/bills_to_pay_card.dart';
import '../widgets/expiring_soon_widget.dart';
import '../widgets/outstanding_receivable_card.dart';
import '../widgets/quick_action_grid.dart';
import '../widgets/overdue_invoices_widget.dart';
import '../widgets/sales_chart_widget.dart';
import '../widgets/revenue_by_branch_widget.dart';
import '../widgets/purchases_by_branch_widget.dart';
import '../widgets/recent_bills_widget.dart';
import '../widgets/branch_selector_widget.dart';
import '../widgets/date_range_picker_widget.dart';
import '../widgets/finance_command_center.dart';
import '../widgets/so_alerts_card.dart';
import '../../inventory/data/item_repository.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _expandedAging;
  bool _redirected = false;

  void _toggleAging(String id) {
    setState(() {
      _expandedAging = _expandedAging == id ? null : id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final orgDetails = ref.watch(orgDetailsProvider).valueOrNull;
    final capabilities = ref.watch(businessCapabilitiesProvider);
    final config = DashboardConfig.forProfile(
      businessType:
          orgDetails?['businessType'] as String? ?? authState.businessType,
      industry: authState.industry,
      industryCode:
          orgDetails?['industryCode'] as String? ?? authState.industryCode,
    );
    final quickActions =
        _visibleQuickActions(config.quickActions, capabilities);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= KSpacing.desktopBreakpoint;
    final isRetail = config.vertical == DashboardVertical.retail ||
        config.vertical == DashboardVertical.pharmacy ||
        config.vertical == DashboardVertical.foodBeverage;
    final isOrderDriven = config.vertical == DashboardVertical.distributor ||
        config.vertical == DashboardVertical.pharmaDistributor ||
        config.vertical == DashboardVertical.manufacturer;
    final role = authState.role?.toUpperCase() ?? 'OWNER';
    final isCashier = role == 'OPERATOR' || role == 'CASHIER';
    final prefersPos = (isCashier || isRetail) && capabilities.canUsePos;
    final prefersSalesOrder =
        !prefersPos && isOrderDriven && capabilities.canUseDistribution;
    final prefersInvoice =
        !prefersPos && !prefersSalesOrder && capabilities.canUseAccounting;
    final prefersItemCreate = !prefersPos &&
        !prefersSalesOrder &&
        !prefersInvoice &&
        capabilities.canUseInventory;
    final primaryRoute = prefersPos
        ? '/pos'
        : prefersSalesOrder
            ? '/sales-orders/create'
            : prefersInvoice
                ? '/invoices/create'
                : prefersItemCreate
                    ? '/items/create'
                    : '/contacts/create';
    final primaryIcon = prefersPos
        ? Icons.point_of_sale_rounded
        : prefersSalesOrder
            ? Icons.assignment_rounded
            : prefersInvoice
                ? Icons.receipt_long_rounded
                : prefersItemCreate
                    ? Icons.inventory_2_rounded
                    : Icons.person_add_alt_1_rounded;
    final primaryLabel = prefersPos
        ? 'New Sale'
        : prefersSalesOrder
            ? 'Sales Order'
            : prefersInvoice
                ? 'New Invoice'
                : prefersItemCreate
                    ? 'New Item'
                    : 'New Contact';

    // Accountant role redirects to accounting dashboard
    if (role == 'ACCOUNTANT' && !_redirected) {
      _redirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/accounting/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Cashier/Operator sees simplified POS-only view
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
          ref.invalidate(outstandingReceivableProvider);
          ref.invalidate(revenueTrendProvider(7));
          ref.invalidate(revenueTrendProvider(30));
          ref.invalidate(revenueTrendProvider(90));
          await Future.delayed(const Duration(milliseconds: 200));
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GreetingStrip(
                greeting: config.greeting,
                userName: authState.userName ?? 'User',
                orgName: authState.orgName ?? 'Your Business',
              ),
              const SizedBox(height: 10),
              if (isCashier)
                _CashierDashboard(isDesktop: isDesktop)
              else if (isRetail)
                _RetailDashboard(
                  isDesktop: isDesktop,
                  config: config,
                  quickActions: quickActions,
                  capabilities: capabilities,
                )
              else
                _AccountingDashboard(
                  config: config,
                  quickActions: quickActions,
                  capabilities: capabilities,
                  isDesktop: isDesktop,
                  expandedAging: _expandedAging,
                  onToggleAging: _toggleAging,
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(primaryRoute),
        icon: Icon(primaryIcon),
        label: Text(primaryLabel),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CASHIER DASHBOARD — simplified POS-only view (no cost/earning)
// ═══════════════════════════════════════════════════════════════════

class _CashierDashboard extends ConsumerWidget {
  final bool isDesktop;
  const _CashierDashboard({required this.isDesktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySalesAsync = ref.watch(todaySalesProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        todaySalesAsync.when(
          loading: () => const KCard(
            title: "Today's Sales",
            child: SizedBox(
                height: 80,
                child:
                    Center(child: CircularProgressIndicator(strokeWidth: 2))),
          ),
          error: (err, _) => KCard(
            title: "Today's Sales",
            child: KErrorBanner(message: 'Failed to load: $err'),
          ),
          data: (data) => KCard(
            title: "Today's Sales",
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.point_of_sale_rounded,
                          color: cs.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CurrencyFormatter.formatIndian(data.posSalesTotal),
                            style:
                                KTypography.amountMedium.copyWith(fontSize: 22),
                          ),
                          Text(
                            '${data.posTransactionCount} transactions',
                            style: KTypography.labelSmall
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _CashierStat(
                      label: 'Cash / UPI',
                      value:
                          CurrencyFormatter.formatCompact(data.posSalesTotal),
                      color: KColors.success,
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _CashierStat(
                      label: 'Credit',
                      value: CurrencyFormatter.formatCompact(data.creditTotal),
                      color: KColors.warning,
                    )),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const TopSellingWidget(),
      ],
    );
  }
}

class _CashierStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CashierStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: KTypography.amountSmall.copyWith(color: cs.onSurface)),
          Text(label,
              style: KTypography.labelSmall
                  .copyWith(color: cs.onSurfaceVariant, fontSize: 10)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  RETAIL DASHBOARD — for KIRANA / PHARMACY (Owner view)
// ═══════════════════════════════════════════════════════════════════

List<QuickAction> _visibleQuickActions(
  List<QuickAction> actions,
  BusinessCapabilities capabilities,
) {
  return actions
      .where((action) => _isQuickActionVisible(action.route, capabilities))
      .toList(growable: false);
}

bool _isQuickActionVisible(
  String route,
  BusinessCapabilities capabilities,
) {
  if (route == '/pos') return capabilities.canUsePos;
  if (route == '/sales-orders/create') return capabilities.canUseDistribution;
  if (route == '/inventory/near-expiry') return capabilities.canUseBatchExpiry;
  if (route == '/gst' || route == '/invoices' || route == '/invoices/create') {
    return capabilities.canUseAccounting;
  }
  if (route == '/reports') return capabilities.canUseReports;
  return true;
}

class _RetailDashboard extends StatelessWidget {
  final bool isDesktop;
  final DashboardConfig config;
  final List<QuickAction> quickActions;
  final BusinessCapabilities capabilities;
  const _RetailDashboard({
    required this.isDesktop,
    required this.config,
    required this.quickActions,
    required this.capabilities,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) return _buildDesktop();
    return _buildMobile();
  }

  Widget _buildMobile() {
    return Column(
      children: [
        BusinessCommandCenter(
          isDesktop: isDesktop,
          vertical: config.vertical,
        ),
        if (quickActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          QuickActionGrid(actions: quickActions),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 12),
        const TodaySummaryCard(),
        if (capabilities.canUseDistribution) ...[
          const SizedBox(height: 12),
          const SoAlertsCard(),
        ],
        const SizedBox(height: 12),
        const WeekTrendCard(),
        if (capabilities.canUseAccounting) ...[
          const SizedBox(height: 12),
          const OutstandingReceivableCard(),
        ],
        const SizedBox(height: 12),
        const TopSellingWidget(),
        if (capabilities.canUseAccounting) ...[
          const SizedBox(height: 12),
          const CreditDueCard(),
        ],
        if (capabilities.canUseInventory) ...[
          const SizedBox(height: 12),
          const LowStockWidget(),
        ],
        if (capabilities.canUseAccounting) ...[
          const SizedBox(height: 12),
          const BillsToPayCard(),
        ],
        if (capabilities.canUseBatchExpiry) ...[
          const SizedBox(height: 12),
          const ExpiringSoonWidget(),
        ],
      ],
    );
  }

  Widget _buildDesktop() {
    return Column(
      children: [
        BusinessCommandCenter(
          isDesktop: isDesktop,
          vertical: config.vertical,
        ),
        if (quickActions.isNotEmpty) ...[
          const SizedBox(height: 16),
          QuickActionGrid(actions: quickActions),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  const TodaySummaryCard(),
                  if (capabilities.canUseDistribution) ...[
                    const SizedBox(height: 12),
                    const SoAlertsCard(),
                  ],
                  const SizedBox(height: 12),
                  const WeekTrendCard(),
                  const SizedBox(height: 12),
                  const TopSellingWidget(),
                  if (capabilities.canUseBatchExpiry) ...[
                    const SizedBox(height: 12),
                    const ExpiringSoonWidget(),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  if (capabilities.canUseAccounting) ...[
                    const OutstandingReceivableCard(),
                    const SizedBox(height: 12),
                    const CreditDueCard(),
                  ],
                  if (capabilities.canUseInventory) ...[
                    const LowStockWidget(),
                  ],
                  if (capabilities.canUseAccounting) ...[
                    const SizedBox(height: 12),
                    const BillsToPayCard(),
                  ],
                ],
              ),
            ),
          ],
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
  final List<QuickAction> quickActions;
  final BusinessCapabilities capabilities;
  final bool isDesktop;
  final String? expandedAging;
  final ValueChanged<String> onToggleAging;

  const _AccountingDashboard({
    required this.config,
    required this.quickActions,
    required this.capabilities,
    required this.isDesktop,
    required this.expandedAging,
    required this.onToggleAging,
  });

  @override
  Widget build(BuildContext context) {
    final isDistributorVertical =
        config.vertical == DashboardVertical.distributor ||
            config.vertical == DashboardVertical.pharmaDistributor;

    if (isDistributorVertical) {
      return _DistributorDashboard(
        config: config,
        quickActions: quickActions,
        capabilities: capabilities,
        isDesktop: isDesktop,
        expandedAging: expandedAging,
        onToggleAging: onToggleAging,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FinanceDashboardHero(
          actions: quickActions,
          isDesktop: isDesktop,
          vertical: config.vertical,
        ),
        if (quickActions.isNotEmpty) KSpacing.vGapMd,
        _KpiGrid(
          kpis: config.kpis,
          isDesktop: isDesktop,
          expandedAging: expandedAging,
          onToggleAging: onToggleAging,
        ),
        if (isDistributorVertical && capabilities.canUseDistribution) ...[
          KSpacing.vGapLg,
          const SoAlertsCard(),
        ],
        KSpacing.vGapLg,
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    const SalesChartWidget(),
                    if (capabilities.canUseDistribution ||
                        capabilities.canUseInventory) ...[
                      const SizedBox(height: 16),
                      const RevenueByBranchWidget(),
                    ],
                    if (capabilities.canUseInventory) ...[
                      const SizedBox(height: 16),
                      const PurchasesByBranchWidget(),
                      if (isDistributorVertical) ...[
                        const SizedBox(height: 16),
                        const ExpiringSoonWidget(),
                      ],
                      const SizedBox(height: 16),
                      const LowStockWidget(),
                    ],
                  ],
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  children: [
                    if (capabilities.canUseAccounting) ...[
                      const OutstandingReceivableCard(),
                      const SizedBox(height: 16),
                    ],
                    const TopSellingWidget(),
                    if (capabilities.canUseAccounting) ...[
                      const SizedBox(height: 16),
                      const OverdueInvoicesWidget(),
                      const SizedBox(height: 16),
                      const RecentBillsWidget(),
                    ],
                  ],
                ),
              ),
            ],
          )
        else ...[
          if (capabilities.canUseAccounting) const OutstandingReceivableCard(),
          KSpacing.vGapMd,
          const SalesChartWidget(),
          if (capabilities.canUseDistribution ||
              capabilities.canUseInventory) ...[
            KSpacing.vGapMd,
            const RevenueByBranchWidget(),
          ],
          if (capabilities.canUseInventory) ...[
            KSpacing.vGapMd,
            const PurchasesByBranchWidget(),
          ],
          KSpacing.vGapMd,
          const TopSellingWidget(),
          if (capabilities.canUseAccounting) ...[
            KSpacing.vGapMd,
            const OverdueInvoicesWidget(),
            KSpacing.vGapMd,
            const RecentBillsWidget(),
          ],
          if (capabilities.canUseInventory) ...[
            KSpacing.vGapMd,
            const LowStockWidget(),
            if (isDistributorVertical) ...[
              KSpacing.vGapMd,
              const ExpiringSoonWidget(),
            ],
          ],
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SHARED COMPONENTS
// ═══════════════════════════════════════════════════════════════════

class _DistributorDashboard extends StatelessWidget {
  final DashboardConfig config;
  final List<QuickAction> quickActions;
  final BusinessCapabilities capabilities;
  final bool isDesktop;
  final String? expandedAging;
  final ValueChanged<String> onToggleAging;

  const _DistributorDashboard({
    required this.config,
    required this.quickActions,
    required this.capabilities,
    required this.isDesktop,
    required this.expandedAging,
    required this.onToggleAging,
  });

  bool get _isPharma => config.vertical == DashboardVertical.pharmaDistributor;

  @override
  Widget build(BuildContext context) {
    final actionTitle = _isPharma ? 'Pharma actions' : 'Distributor actions';

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BusinessCommandCenter(
                  isDesktop: isDesktop,
                  vertical: config.vertical,
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) => _KpiGrid(
                    kpis: config.kpis,
                    isDesktop: isDesktop,
                    compact: true,
                    availableWidth: constraints.maxWidth,
                    expandedAging: expandedAging,
                    onToggleAging: onToggleAging,
                  ),
                ),
                if (capabilities.canUseDistribution) ...[
                  const SizedBox(height: 10),
                  const SoAlertsCard(),
                ],
                const SizedBox(height: 10),
                const SalesChartWidget(),
                if (capabilities.canUseInventory) ...[
                  const SizedBox(height: 10),
                  const LowStockWidget(),
                  if (_isPharma && capabilities.canUseBatchExpiry) ...[
                    const SizedBox(height: 10),
                    const ExpiringSoonWidget(),
                  ],
                ],
              ],
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            flex: 4,
            child: Column(
              children: [
                if (quickActions.isNotEmpty) ...[
                  _BusinessActionPanel(
                    title: actionTitle,
                    actions: quickActions,
                  ),
                  const SizedBox(height: 10),
                ],
                if (capabilities.canUseAccounting) ...[
                  const OutstandingReceivableCard(),
                  const SizedBox(height: 10),
                  const OverdueInvoicesWidget(),
                  const SizedBox(height: 10),
                  const BillsToPayCard(),
                ],
                if (!_isPharma && capabilities.canUseInventory) ...[
                  const SizedBox(height: 10),
                  const ExpiringSoonWidget(),
                ],
                const SizedBox(height: 10),
                const TopSellingWidget(),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BusinessCommandCenter(
          isDesktop: isDesktop,
          vertical: config.vertical,
        ),
        if (quickActions.isNotEmpty) ...[
          KSpacing.vGapSm,
          _BusinessActionPanel(title: actionTitle, actions: quickActions),
        ],
        const SizedBox(height: 10),
        _KpiGrid(
          kpis: config.kpis,
          isDesktop: isDesktop,
          compact: true,
          expandedAging: expandedAging,
          onToggleAging: onToggleAging,
        ),
        if (capabilities.canUseDistribution) ...[
          const SizedBox(height: 10),
          const SoAlertsCard(),
        ],
        const SizedBox(height: 10),
        if (capabilities.canUseAccounting) ...[
          const OutstandingReceivableCard(),
          KSpacing.vGapMd,
        ],
        if (capabilities.canUseInventory) ...[
          const LowStockWidget(),
          if (capabilities.canUseBatchExpiry) ...[
            KSpacing.vGapMd,
            const ExpiringSoonWidget(),
          ],
          KSpacing.vGapMd,
        ],
        const SalesChartWidget(),
        if (capabilities.canUseAccounting) ...[
          KSpacing.vGapMd,
          const OverdueInvoicesWidget(),
          KSpacing.vGapMd,
          const BillsToPayCard(),
        ],
        KSpacing.vGapMd,
        const TopSellingWidget(),
      ],
    );
  }
}

class _FinanceDashboardHero extends StatelessWidget {
  final List<QuickAction> actions;
  final bool isDesktop;
  final DashboardVertical vertical;

  const _FinanceDashboardHero({
    required this.actions,
    required this.isDesktop,
    required this.vertical,
  });

  bool get _useBusinessCommandCenter =>
      vertical == DashboardVertical.distributor ||
      vertical == DashboardVertical.pharmaDistributor ||
      vertical == DashboardVertical.manufacturer;

  Widget _buildCommandCenter() {
    if (_useBusinessCommandCenter) {
      return BusinessCommandCenter(isDesktop: isDesktop, vertical: vertical);
    }
    return AccountingControlCenter(isDesktop: isDesktop);
  }

  @override
  Widget build(BuildContext context) {
    if (!isDesktop) {
      if (actions.isEmpty) {
        return _buildCommandCenter();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCommandCenter(),
          KSpacing.vGapSm,
          _FinanceActionPanel(actions: actions),
        ],
      );
    }

    if (actions.isEmpty) {
      return _buildCommandCenter();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 7,
          child: _buildCommandCenter(),
        ),
        KSpacing.hGapMd,
        Expanded(
          flex: 4,
          child: _FinanceActionPanel(actions: actions),
        ),
      ],
    );
  }
}

class _BusinessActionPanel extends StatelessWidget {
  final String title;
  final List<QuickAction> actions;

  const _BusinessActionPanel({
    required this.title,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: KSpacing.borderRadiusLg,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on_rounded, size: 18, color: cs.primary),
              KSpacing.hGapSm,
              Expanded(
                child: Text(
                  title,
                  style: KTypography.labelLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _FilterBar(compact: true),
          const SizedBox(height: 10),
          QuickActionGrid(actions: actions),
        ],
      ),
    );
  }
}

class _FinanceActionPanel extends StatelessWidget {
  final List<QuickAction> actions;

  const _FinanceActionPanel({required this.actions});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: KSpacing.borderRadiusLg,
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: cs.primary),
              KSpacing.hGapSm,
              Expanded(
                child: Text(
                  'Finance shortcuts',
                  style: KTypography.labelLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _FilterBar(compact: true),
          const SizedBox(height: 10),
          QuickActionGrid(actions: actions),
        ],
      ),
    );
  }
}

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(KSpacing.radiusLg),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.waving_hand_rounded, size: 16, color: cs.primary),
          ),
          const SizedBox(width: 10),
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

class _CompactKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? trend;
  final bool? trendPositive;
  final bool showChevron;
  final bool expanded;
  final VoidCallback? onTap;

  const _CompactKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.trend,
    this.trendPositive,
    this.showChevron = false,
    this.expanded = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = iconColor ?? cs.primary;
    final positive = trendPositive == true;
    final trendColor = positive ? KColors.success : KColors.error;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(KSpacing.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(KSpacing.radiusSm),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: KTypography.amountMedium.copyWith(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      title,
                      style: KTypography.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trend != null) ...[
                const SizedBox(width: 8),
                Container(
                  constraints: const BoxConstraints(maxWidth: 92),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: trendColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(KSpacing.radiusRound),
                  ),
                  child: Text(
                    trend!,
                    style: KTypography.labelSmall.copyWith(
                      color: trendColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (showChevron) ...[
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final bool compact;

  const _FilterBar({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.of(context).size.width;
    final stacked = compact || width < 600;

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
  final bool compact;
  final double? availableWidth;
  final String? expandedAging;
  final ValueChanged<String> onToggleAging;

  const _KpiGrid({
    required this.kpis,
    required this.isDesktop,
    this.compact = false,
    this.availableWidth,
    required this.expandedAging,
    required this.onToggleAging,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The distributor dashboard splits desktop content into two columns.
    // The left column is often too narrow for four compact cards, even on a wide
    // browser window, so choose the grid from its actual available width.
    final cols = compact && (availableWidth ?? double.infinity) < 960
        ? 2
        : (isDesktop ? 4 : 2);
    final tileH =
        compact ? (isDesktop ? 78.0 : 88.0) : (isDesktop ? 112.0 : 116.0);
    final todaySalesAsync = ref.watch(todaySalesProvider);
    final apSummaryAsync = ref.watch(apSummaryProvider);
    final arSummaryAsync = ref.watch(arSummaryProvider);
    final monthlyProfitAsync = ref.watch(monthlyProfitProvider);
    final expiringSoonAsync = ref.watch(expiringSoonProvider);
    final lowStockAsync = ref.watch(lowStockProvider);

    Widget buildTile(KpiConfig kpi) {
      if (kpi.id == 'payables') {
        return apSummaryAsync.when(
          loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
          error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
          data: (ap) {
            final value = CurrencyFormatter.formatCompact(ap.totalOutstanding);
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
            return _buildKpiCard(
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
            final value = CurrencyFormatter.formatCompact(ar.totalOutstanding);
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
            return _buildKpiCard(
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
          data: (mp) => _buildKpiCard(
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
          data: (mp) => _buildKpiCard(
            title: kpi.title,
            value: CurrencyFormatter.formatCompact(mp.revenue),
            icon: kpi.icon,
            iconColor: kpi.color,
            trend: 'MTD',
          ),
        );
      }

      if (kpi.id == 'expiring_stock') {
        return expiringSoonAsync.when(
          loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
          error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '--'),
          data: (items) => _buildKpiCard(
            title: kpi.title,
            value: '${items.length}',
            icon: kpi.icon,
            iconColor: kpi.color,
            trend: items.isEmpty ? 'Clear' : '90 days',
          ),
        );
      }

      if (kpi.id == 'low_stock') {
        return lowStockAsync.when(
          loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
          error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '--'),
          data: (raw) {
            final content = raw['data'] ?? raw;
            final items = content is List
                ? content
                : (content is Map ? (content['content'] as List?) ?? [] : []);
            return _buildKpiCard(
              title: kpi.title,
              value: '${items.length}',
              icon: kpi.icon,
              iconColor: kpi.color,
              trend: items.isEmpty ? 'Clear' : 'Reorder',
            );
          },
        );
      }

      return todaySalesAsync.when(
        loading: () => _KpiPlaceholder(kpi: kpi, value: '...'),
        error: (_, __) => _KpiPlaceholder(kpi: kpi, value: '—'),
        data: (data) {
          final (value, trend) = _valueFor(kpi.id, data);
          return _buildKpiCard(
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

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    Color? iconColor,
    String? trend,
    bool? trendPositive,
    bool showChevron = false,
    bool expanded = false,
    VoidCallback? onTap,
  }) {
    if (compact) {
      return _CompactKpiCard(
        title: title,
        value: value,
        icon: icon,
        iconColor: iconColor,
        trend: trend,
        trendPositive: trendPositive,
        showChevron: showChevron,
        expanded: expanded,
        onTap: onTap,
      );
    }
    // Stable id per metric so the user's colour choice sticks to this KPI.
    final colorKey = 'dashboard.kpi.${title.toLowerCase().trim()}';
    return Builder(
      builder: (context) => KKpiCard(
        title: title,
        value: value,
        icon: icon,
        iconColor: iconColor,
        trend: trend,
        trendPositive: trendPositive,
        showChevron: showChevron,
        expanded: expanded,
        onTap: onTap,
        colorKey: colorKey,
        // Long-press a tile to paint it a colour different from the theme.
        onLongPress: () => KComponentColorPicker.show(context, colorKey),
      ),
    );
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
        return (
          CurrencyFormatter.formatCompact(data.totalSales as double),
          'Today'
        );
      case 'cash_collected':
        return (
          CurrencyFormatter.formatCompact(data.cashUpiTotal as double),
          'Today'
        );
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
