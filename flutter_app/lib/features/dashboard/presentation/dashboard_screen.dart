import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/auth_state.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/dashboard_config.dart';
import '../widgets/quick_action_grid.dart';
import '../widgets/overdue_invoices_widget.dart';
import '../widgets/sales_chart_widget.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final config = DashboardConfig.forIndustry(authState.industry);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= KSpacing.desktopBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                '${config.greeting}, ${authState.userName ?? 'User'}!',
                style: KTypography.h1,
              ),
              KSpacing.vGapXs,
              Text(
                authState.orgName ?? 'Your Business',
                style: KTypography.bodyMedium.copyWith(
                  color: KColors.textSecondary,
                ),
              ),
              KSpacing.vGapLg,

              // KPI Cards
              _KpiGrid(kpis: config.kpis, isDesktop: isDesktop),
              KSpacing.vGapLg,

              // Quick Actions
              Text('Quick Actions', style: KTypography.h3),
              KSpacing.vGapMd,
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
                        children: [
                          const SalesChartWidget(),
                          KSpacing.vGapMd,
                        ],
                      ),
                    ),
                    KSpacing.hGapMd,
                    const Expanded(
                      child: OverdueInvoicesWidget(),
                    ),
                  ],
                )
              else ...[
                const SalesChartWidget(),
                KSpacing.vGapMd,
                const OverdueInvoicesWidget(),
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

class _KpiGrid extends StatelessWidget {
  final List<KpiConfig> kpis;
  final bool isDesktop;

  const _KpiGrid({required this.kpis, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = isDesktop ? 4 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: KSpacing.md,
        mainAxisSpacing: KSpacing.md,
        childAspectRatio: isDesktop ? 1.6 : 1.3,
      ),
      itemCount: kpis.length,
      itemBuilder: (context, index) {
        final kpi = kpis[index];
        // Placeholder values — will be replaced with actual API data
        return KKpiCard(
          title: kpi.title,
          value: CurrencyFormatter.formatCompact(0),
          icon: kpi.icon,
          iconColor: kpi.color,
          trend: '--',
        );
      },
    );
  }
}
