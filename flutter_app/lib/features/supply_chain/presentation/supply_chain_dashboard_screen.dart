import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
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
            padding: KSpacing.pagePadding,
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
        _MetricCard('Class C', '${abc['C'] ?? 0}', KColors.draft),
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
              Text(value, style: KTypography.h2.copyWith(color: color)),
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

  // All six tools that live under the Supply Chain module — surfaced here so the
  // dashboard reads as a hub, not a dead-end (the sidebar group hides these
  // behind one tap).
  static const _tools = [
    _Tool('Requisitions', Icons.receipt_long,
        'Raise & approve purchase requests', '/supply-chain/requisitions'),
    _Tool('Shipments', Icons.local_shipping,
        'Track inbound & outbound shipments', '/supply-chain/shipments'),
    _Tool('Return Orders', Icons.assignment_return,
        'Purchase & sales returns', '/supply-chain/returns'),
    _Tool('Alerts', Icons.notifications_active,
        'Stockout risk & low-stock alerts', '/supply-chain/alerts'),
    _Tool('Supplier Rankings', Icons.leaderboard,
        'Supplier performance scorecards', '/supply-chain/supplier-rankings'),
    _Tool('Inventory Analytics', Icons.rotate_right,
        'Turnover, days-on-hand & ABC', '/supply-chain/turnover'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Supply Chain Tools', style: KTypography.titleMedium),
        const SizedBox(height: KSpacing.xs),
        Text('Six tools live here — jump to any one.',
            style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
        const SizedBox(height: KSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = KSpacing.md;
            final cols = (constraints.maxWidth / 260).floor().clamp(1, 4);
            final tileW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: _tools
                  .map((t) => SizedBox(width: tileW, child: _NavCard(t)))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _Tool {
  final String title;
  final IconData icon;
  final String subtitle;
  final String route;
  const _Tool(this.title, this.icon, this.subtitle, this.route);
}

class _NavCard extends StatelessWidget {
  final _Tool tool;
  const _NavCard(this.tool);

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(tool.route),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                ),
                child: Icon(tool.icon, color: KColors.primary, size: 22),
              ),
              const SizedBox(width: KSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tool.title,
                        style: KTypography.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(tool.subtitle,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: KColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
