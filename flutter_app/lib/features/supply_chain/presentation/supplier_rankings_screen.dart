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

final _rankingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).getSupplierRankings();
});

class SupplierRankingsScreen extends ConsumerWidget {
  const SupplierRankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(_rankingsProvider);
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => rankingsAsync.valueOrNull?.length ?? 0,
      onRefresh: () => ref.invalidate(_rankingsProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Supplier Rankings & Scorecards'),
          bottom: scmBreadcrumb(context, 'Supplier Rankings'),
        ),
        body: rankingsAsync.when(
          loading: () => const KLoading(message: 'Calculating supplier performance rankings...'),
          error: (e, _) => Center(
            child: Padding(
              padding: KSpacing.pagePadding,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 48, color: KColors.error),
                  KSpacing.vGapMd,
                  Text(ApiErrorParser.message(e), style: KTypography.bodyMedium, textAlign: TextAlign.center),
                  KSpacing.vGapMd,
                  KButton.outlined(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    onPressed: () => ref.invalidate(_rankingsProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (rankings) {
            if (rankings.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(_rankingsProvider),
                child: ListView(
                  padding: KSpacing.pagePadding,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Supplier Performance Rankings',
                          style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'OTIF delivery, quality acceptance rates, and overall vendor scorecards.',
                          style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    KSpacing.vGapLg,
                    const KEmptyState(
                      icon: Icons.leaderboard_outlined,
                      title: 'No supplier performance data yet',
                      subtitle: 'Scorecard metrics are computed automatically from purchase receipts and QC inspection logs.',
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_rankingsProvider),
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supplier Performance Rankings',
                        style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OTIF delivery, quality acceptance rates, and overall vendor scorecards.',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  ...List.generate(rankings.length, (index) {
                    final r = rankings[index] as Map<String, dynamic>;
                    return _SupplierRankCard(rank: index + 1, data: r);
                  }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SupplierRankCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;

  const _SupplierRankCard({required this.rank, required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final score = (data['overallScore'] as num?)?.toDouble() ?? 0.0;
    final qualityRate = (data['qualityRate'] as num?)?.toDouble() ?? 0.0;
    final totalOrders = data['totalOrders'] ?? 0;
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final supplierName = (data['supplierName'] as String?) ?? 'Supplier';

    final scoreColor = score >= 80
        ? KColors.success
        : score >= 50
            ? KColors.warning
            : KColors.error;

    final rankColor = rank == 1
        ? const Color(0xFFD4AF37) // Gold
        : rank == 2
            ? const Color(0xFF9E9E9E) // Silver
            : rank == 3
                ? const Color(0xFFCD7F32) // Bronze
                : cs.onSurfaceVariant;

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: rank <= 3 ? rankColor.withValues(alpha: 0.15) : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                  border: rank <= 3 ? Border.all(color: rankColor, width: 1.5) : null,
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: KTypography.labelSmall.copyWith(
                      color: rank <= 3 ? rankColor : cs.onSurface,
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
                      supplierName,
                      style: KTypography.titleSmall.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$totalOrders Purchase Orders completed',
                      style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${score.toStringAsFixed(1)}%',
                    style: KTypography.h3.copyWith(
                      color: scoreColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Overall Score',
                    style: KTypography.labelSmall.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          KSpacing.vGapSm,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 6,
              color: scoreColor,
              backgroundColor: scoreColor.withValues(alpha: 0.15),
            ),
          ),
          KSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_outlined, size: 14, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Quality Rate: ${qualityRate.toStringAsFixed(1)}%',
                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Spend: ',
                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                  ),
                  KMoney(totalAmount, style: KTypography.titleSmall),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
