import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/api_error_parser.dart';
import '../data/supply_chain_repository.dart';

final _dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).getDashboard();
});

class SupplyChainDashboardScreen extends ConsumerWidget {
  const SupplyChainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Supply Chain')),
      body: dashAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
        data: (dash) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_dashboardProvider),
          child: ListView(
            padding: KSpacing.screenPadding,
            children: [
              _MetricsRow(dash),
              const SizedBox(height: KSpacing.lg),
              _QuickActions(ref),
              const SizedBox(height: KSpacing.lg),
              _NavigationCards(context),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MetricsRow(this.data);

  @override
  Widget build(BuildContext context) {
    final abc = data['abcClassification'] as Map<String, dynamic>? ?? {};
    return Wrap(
      spacing: KSpacing.md,
      runSpacing: KSpacing.md,
      children: [
        _MetricCard('Open Alerts', '${data['openAlerts'] ?? 0}', KColors.error),
        _MetricCard('Low Stock', '${data['lowStockCount'] ?? 0}', KColors.warning),
        _MetricCard('Class A', '${abc['A'] ?? 0}', KColors.success),
        _MetricCard('Class B', '${abc['B'] ?? 0}', KColors.info),
        _MetricCard('Class C', '${abc['C'] ?? 0}', KColors.neutral),
        _MetricCard('Auto-Reorder', '${data['autoReorderItems'] ?? 0}', KColors.primary),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Column(
            children: [
              Text(value, style: KTypography.headlineMedium.copyWith(color: color)),
              const SizedBox(height: KSpacing.xs),
              Text(label, style: KTypography.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final WidgetRef ref;
  const _QuickActions(this.ref);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: KTypography.titleMedium),
            const SizedBox(height: KSpacing.sm),
            Wrap(
              spacing: KSpacing.sm,
              runSpacing: KSpacing.sm,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    try {
                      await ref.read(supplyChainRepositoryProvider).runAbcClassification();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ABC classification completed')),
                        );
                        ref.invalidate(_dashboardProvider);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ApiErrorParser.message(e))),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.analytics),
                  label: const Text('Run ABC'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    try {
                      await ref.read(supplyChainRepositoryProvider).runAlertScan();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Alert scan completed')),
                        );
                        ref.invalidate(_dashboardProvider);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ApiErrorParser.message(e))),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.warning_amber),
                  label: const Text('Scan Alerts'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    try {
                      await ref.read(supplyChainRepositoryProvider).autoCreateRequisition();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Auto-requisition created from low stock')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ApiErrorParser.message(e))),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Auto-PR'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () async {
                    try {
                      await ref.read(supplyChainRepositoryProvider).generateForecast();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Demand forecast generated')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ApiErrorParser.message(e))),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.trending_up),
                  label: const Text('Forecast'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationCards extends StatelessWidget {
  final BuildContext ctx;
  const _NavigationCards(this.ctx);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modules', style: KTypography.titleMedium),
        const SizedBox(height: KSpacing.sm),
        _NavCard('Purchase Requisitions', Icons.receipt_long,
            'Create and manage purchase requests', '/supply-chain/requisitions'),
        _NavCard('Return Orders', Icons.assignment_return,
            'Manage purchase and sales returns', '/supply-chain/returns'),
        _NavCard('Alerts', Icons.notifications_active,
            'Supply chain alerts and notifications', '/supply-chain/alerts'),
        _NavCard('Supplier Rankings', Icons.leaderboard,
            'Supplier performance scorecards', '/supply-chain/supplier-rankings'),
        _NavCard('Inventory Turnover', Icons.rotate_right,
            'Inventory analytics and ABC analysis', '/supply-chain/turnover'),
      ],
    );
  }
}

class _NavCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String subtitle;
  final String route;
  const _NavCard(this.title, this.icon, this.subtitle, this.route);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        leading: Icon(icon, color: KColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(route),
      ),
    );
  }
}
