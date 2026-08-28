import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../data/supply_chain_repository.dart';
import 'widgets/scm_breadcrumb.dart';

final _turnoverProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).getInventoryTurnover();
});

final _policiesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).getReorderPolicies();
});

class InventoryTurnoverScreen extends ConsumerStatefulWidget {
  const InventoryTurnoverScreen({super.key});

  @override
  ConsumerState<InventoryTurnoverScreen> createState() => _InventoryTurnoverScreenState();
}

class _InventoryTurnoverScreenState extends ConsumerState<InventoryTurnoverScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _runningAbc = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turnoverAsync = ref.watch(_turnoverProvider);
    final policiesAsync = ref.watch(_policiesProvider);
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => (turnoverAsync.valueOrNull?.length ?? 0) + (policiesAsync.valueOrNull?.length ?? 0),
      onRefresh: () {
        ref.invalidate(_turnoverProvider);
        ref.invalidate(_policiesProvider);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Inventory Analytics & ABC'),
          bottom: scmBreadcrumb(context, 'Analytics'),
        ),
        body: ListView(
          padding: KSpacing.pagePadding,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory Velocity & ABC Analysis',
                        style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track annual inventory turnover ratio, days on hand (DOH), and safety reorder parameters.',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                KButton.primary(
                  label: 'Run ABC Classification',
                  icon: Icons.analytics_outlined,
                  isLoading: _runningAbc,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _runningAbc = true);
                    try {
                      await ref.read(supplyChainRepositoryProvider).runAbcClassification();
                      ref.invalidate(_policiesProvider);
                      ref.invalidate(_turnoverProvider);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('ABC classification analysis updated successfully')),
                      );
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
              ],
            ),
            KSpacing.vGapMd,
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Turnover & Days on Hand'),
                Tab(text: 'ABC Classification & ROP'),
              ],
            ),
            KSpacing.vGapMd,
            SizedBox(
              height: 600,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _TurnoverTab(turnoverAsync: turnoverAsync),
                  _AbcPoliciesTab(policiesAsync: policiesAsync),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnoverTab extends StatelessWidget {
  final AsyncValue<List<dynamic>> turnoverAsync;
  const _TurnoverTab({required this.turnoverAsync});

  @override
  Widget build(BuildContext context) {
    return turnoverAsync.when(
      loading: () => const KLoading(message: 'Calculating turnover velocity...'),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (items) {
        if (items.isEmpty) {
          return const KEmptyState(
            icon: Icons.rotate_right_rounded,
            title: 'No sales velocity data yet',
            subtitle: 'Inventory turnover ratios are computed from sales transactions against average stock levels.',
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final m = items[index] as Map<String, dynamic>;
            final turnover = (m['turnoverRatio'] as num?)?.toDouble() ?? 0.0;
            final doh = (m['daysOnHand'] as num?)?.toInt() ?? 0;
            final cogs = (m['cogs'] as num?)?.toDouble() ?? 0.0;
            final avgVal = (m['avgInventoryValue'] as num?)?.toDouble() ?? 0.0;
            final itemName = (m['itemName'] as String?) ?? 'Item';

            final velocityColor = turnover >= 6
                ? KColors.success
                : turnover >= 2
                    ? KColors.warning
                    : KColors.error;

            return KCard(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              padding: const EdgeInsets.all(KSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: velocityColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(KSpacing.radiusMd),
                    ),
                    child: Center(
                      child: Text(
                        '${turnover.toStringAsFixed(1)}x',
                        style: KTypography.titleSmall.copyWith(
                          color: velocityColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'COGS: ',
                              style: KTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            KMoney(cogs, style: KTypography.bodySmall),
                            const SizedBox(width: 8),
                            Text(
                              '• Avg Stock: ',
                              style: KTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                            KMoney(avgVal, style: KTypography.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$doh days',
                        style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Days on Hand',
                        style: KTypography.labelSmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _AbcPoliciesTab extends StatelessWidget {
  final AsyncValue<List<dynamic>> policiesAsync;
  const _AbcPoliciesTab({required this.policiesAsync});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return policiesAsync.when(
      loading: () => const KLoading(message: 'Loading ABC classification...'),
      error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
      data: (policies) {
        if (policies.isEmpty) {
          return const KEmptyState(
            icon: Icons.category_outlined,
            title: 'No ABC classification policies yet',
            subtitle: 'Click "Run ABC Classification" above to categorize items into Class A, B, and C tiers.',
          );
        }

        return ListView.builder(
          itemCount: policies.length,
          itemBuilder: (context, index) {
            final m = policies[index] as Map<String, dynamic>;
            final cls = (m['abcClass'] as String? ?? 'C').toUpperCase();
            final itemName = (m['itemName'] as String?) ??
                'Item ${m['itemId']?.toString().substring(0, 8) ?? ''}…';
            final safetyStock = m['safetyStock'] ?? 0;
            final rop = m['reorderPoint'] ?? 0;
            final eoq = m['eoq'] ?? 0;

            final classColor = switch (cls) {
              'A' => KColors.primary,
              'B' => KColors.info,
              'C' => KColors.draft,
              _ => cs.onSurfaceVariant,
            };

            return KCard(
              margin: const EdgeInsets.only(bottom: KSpacing.sm),
              padding: const EdgeInsets.all(KSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: classColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: classColor.withValues(alpha: 0.4)),
                    ),
                    child: Center(
                      child: Text(
                        cls,
                        style: TextStyle(
                          color: classColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName,
                          style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 12,
                          children: [
                            Text('Safety: $safetyStock', style: KTypography.bodySmall),
                            Text('ROP: $rop', style: KTypography.bodySmall),
                            Text('EOQ: $eoq', style: KTypography.bodySmall),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
