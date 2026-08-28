import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_loading.dart';
import '../data/supply_chain_repository.dart';

final _dashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).getDashboard();
});

class SupplyChainDashboardScreen extends ConsumerWidget {
  const SupplyChainDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_dashboardProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supply Planning & SCM'),
        actions: [
          IconButton(
            tooltip: 'Refresh Dashboard',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_dashboardProvider),
          ),
        ],
      ),
      body: dashAsync.when(
        loading: () => const KLoading(message: 'Loading supply chain metrics...'),
        error: (e, _) => Center(
          child: Padding(
            padding: KSpacing.pagePadding,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: KColors.error),
                KSpacing.vGapMd,
                Text(
                  ApiErrorParser.message(e),
                  style: KTypography.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                KSpacing.vGapMd,
                KButton.outlined(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.invalidate(_dashboardProvider),
                ),
              ],
            ),
          ),
        ),
        data: (dash) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_dashboardProvider),
          child: ListView(
            padding: KSpacing.pagePadding,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Supply Chain Command Center',
                    style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Overview of stock health, alerts, requisitions, and inventory turnover.',
                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              KSpacing.vGapMd,
              _MetricsGrid(dash),
              KSpacing.vGapLg,
              _QuickActionsSection(ref: ref),
              KSpacing.vGapLg,
              const _NavigationToolsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MetricsGrid(this.data);

  @override
  Widget build(BuildContext context) {
    final abc = data['abcClassification'] as Map<String, dynamic>? ?? {};

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = (constraints.maxWidth / 200).floor().clamp(2, 6);
        const spacing = KSpacing.sm;
        final itemW = (constraints.maxWidth - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: itemW,
              child: _MetricTile(
                label: 'Open Alerts',
                value: '${data['openAlerts'] ?? 0}',
                icon: Icons.notifications_active_outlined,
                color: (data['openAlerts'] ?? 0) > 0 ? KColors.error : KColors.success,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _MetricTile(
                label: 'Low Stock Items',
                value: '${data['lowStockCount'] ?? 0}',
                icon: Icons.warning_amber_rounded,
                color: (data['lowStockCount'] ?? 0) > 0 ? KColors.warning : KColors.success,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _MetricTile(
                label: 'Class A (High Value)',
                value: '${abc['A'] ?? 0}',
                icon: Icons.star_outline_rounded,
                color: KColors.primary,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _MetricTile(
                label: 'Class B (Medium)',
                value: '${abc['B'] ?? 0}',
                icon: Icons.category_outlined,
                color: KColors.info,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _MetricTile(
                label: 'Class C (Bulk)',
                value: '${abc['C'] ?? 0}',
                icon: Icons.inventory_2_outlined,
                color: KColors.draft,
              ),
            ),
            SizedBox(
              width: itemW,
              child: _MetricTile(
                label: 'Auto-Reorder Rules',
                value: '${data['autoReorderItems'] ?? 0}',
                icon: Icons.autorenew_rounded,
                color: KColors.success,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return KCard(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Text(
                value,
                style: KTypography.h2.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          Text(
            label,
            style: KTypography.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _QuickActionsSection extends StatefulWidget {
  final WidgetRef ref;
  const _QuickActionsSection({required this.ref});

  @override
  State<_QuickActionsSection> createState() => _QuickActionsSectionState();
}

class _QuickActionsSectionState extends State<_QuickActionsSection> {
  bool _runningAbc = false;
  bool _scanningAlerts = false;
  bool _creatingPr = false;
  bool _generatingForecast = false;

  @override
  Widget build(BuildContext context) {
    return KCard(
      title: 'Automated Operations',
      subtitle: 'Run demand forecasting, alert scan, ABC classification, or low-stock requisition generation.',
      child: Wrap(
        spacing: KSpacing.sm,
        runSpacing: KSpacing.sm,
        children: [
          KButton.primary(
            label: 'Scan Alerts',
            icon: Icons.radar_rounded,
            isLoading: _scanningAlerts,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _scanningAlerts = true);
              try {
                await widget.ref.read(supplyChainRepositoryProvider).runAlertScan();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Supply chain alert scan completed successfully')),
                );
                widget.ref.invalidate(_dashboardProvider);
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                );
              } finally {
                if (mounted) setState(() => _scanningAlerts = false);
              }
            },
          ),
          KButton.secondary(
            label: 'Run ABC Classification',
            icon: Icons.analytics_outlined,
            isLoading: _runningAbc,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _runningAbc = true);
              try {
                await widget.ref.read(supplyChainRepositoryProvider).runAbcClassification();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('ABC inventory classification updated')),
                );
                widget.ref.invalidate(_dashboardProvider);
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                );
              } finally {
                if (mounted) setState(() => _runningAbc = false);
              }
            },
          ),
          KButton.secondary(
            label: 'Auto PR from Low Stock',
            icon: Icons.shopping_cart_checkout_rounded,
            isLoading: _creatingPr,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _creatingPr = true);
              try {
                await widget.ref.read(supplyChainRepositoryProvider).autoCreateRequisition();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Auto-requisition created from deficit items')),
                );
                widget.ref.invalidate(_dashboardProvider);
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                );
              } finally {
                if (mounted) setState(() => _creatingPr = false);
              }
            },
          ),
          KButton.outlined(
            label: 'Generate Forecast',
            icon: Icons.trending_up_rounded,
            isLoading: _generatingForecast,
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _generatingForecast = true);
              try {
                await widget.ref.read(supplyChainRepositoryProvider).generateForecast();
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Demand forecast generated')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                );
              } finally {
                if (mounted) setState(() => _generatingForecast = false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _NavigationToolsSection extends StatelessWidget {
  const _NavigationToolsSection();

  static const _tools = [
    _Tool(
      title: 'Purchase Requisitions',
      icon: Icons.receipt_long_rounded,
      subtitle: 'Raise & approve internal purchase requests',
      route: '/supply-chain/requisitions',
    ),
    _Tool(
      title: 'Shipments',
      icon: Icons.local_shipping_rounded,
      subtitle: 'Track inbound & outbound dispatch logistics',
      route: '/supply-chain/shipments',
    ),
    _Tool(
      title: 'Return Orders (RMA)',
      icon: Icons.assignment_return_rounded,
      subtitle: 'Manage supplier and customer return orders',
      route: '/supply-chain/returns',
    ),
    _Tool(
      title: 'Alerts & Shortages',
      icon: Icons.notifications_active_rounded,
      subtitle: 'Stockout risk, reorder alerts & expiry flags',
      route: '/supply-chain/alerts',
    ),
    _Tool(
      title: 'Supplier Rankings',
      icon: Icons.leaderboard_rounded,
      subtitle: 'Supplier performance scorecards and quality rate',
      route: '/supply-chain/supplier-rankings',
    ),
    _Tool(
      title: 'Inventory Analytics',
      icon: Icons.rotate_right_rounded,
      subtitle: 'Turnover ratio, days on hand & ABC categorization',
      route: '/supply-chain/turnover',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Supply Chain Tools',
          style: KTypography.h3,
        ),
        const SizedBox(height: 2),
        Text(
          'Direct access to planning, tracking, returns, and analytics tools.',
          style: KTypography.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        KSpacing.vGapMd,
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = KSpacing.md;
            final cols = (constraints.maxWidth / 280).floor().clamp(1, 3);
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
  const _Tool({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.route,
  });
}

class _NavCard extends StatelessWidget {
  final _Tool tool;
  const _NavCard(this.tool);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return KCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        onTap: () => context.go(tool.route),
        child: Padding(
          padding: const EdgeInsets.all(KSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                ),
                child: Icon(tool.icon, color: cs.primary, size: 22),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tool.title,
                      style: KTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tool.subtitle,
                      style: KTypography.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
