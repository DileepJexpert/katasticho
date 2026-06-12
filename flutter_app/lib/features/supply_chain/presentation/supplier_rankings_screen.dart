import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/supply_chain_repository.dart';

final _rankingsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).getSupplierRankings();
});

class SupplierRankingsScreen extends ConsumerWidget {
  const SupplierRankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rankingsAsync = ref.watch(_rankingsProvider);

    return KKeyboardListWrapper(
      itemCount: () => rankingsAsync.valueOrNull?.length ?? 0,
      onRefresh: () => ref.invalidate(_rankingsProvider),
      child: Scaffold(
        appBar: AppBar(title: const Text('Supplier Rankings')),
        body: rankingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
          data: (rankings) {
            if (rankings.isEmpty) {
              return const Center(child: Text('No supplier performance data yet.\nCalculate performance from a supplier\'s scorecard.'));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_rankingsProvider),
              child: ListView.builder(
                padding: KSpacing.screenPadding,
                itemCount: rankings.length,
                itemBuilder: (context, index) {
                  final r = rankings[index] as Map<String, dynamic>;
                  final score = (r['overallScore'] as num?)?.toDouble() ?? 0;
                  final color = score >= 80 ? KColors.success
                      : score >= 50 ? KColors.warning
                      : KColors.error;

                  return Card(
                    margin: const EdgeInsets.only(bottom: KSpacing.sm),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Text('${index + 1}', style: TextStyle(color: color)),
                      ),
                      title: Text('Supplier', style: KTypography.titleSmall),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Score: ${score.toStringAsFixed(1)}%'),
                          Text('Quality: ${r['qualityRate']}% | Orders: ${r['totalOrders']}',
                              style: KTypography.bodySmall),
                          Text('Amount: ${CurrencyFormatter.format(r['totalAmount'])}',
                              style: KTypography.bodySmall),
                        ],
                      ),
                      trailing: LinearProgressIndicator(
                        value: score / 100,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.2),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
