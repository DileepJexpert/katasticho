import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/supply_chain_repository.dart';

final _turnoverProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).getInventoryTurnover();
});

final _policiesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).getReorderPolicies();
});

class InventoryTurnoverScreen extends ConsumerWidget {
  const InventoryTurnoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turnoverAsync = ref.watch(_turnoverProvider);
    final policiesAsync = ref.watch(_policiesProvider);

    return KKeyboardListWrapper(
      itemCount: () => (turnoverAsync.valueOrNull?.length ?? 0) + (policiesAsync.valueOrNull?.length ?? 0),
      onRefresh: () {
        ref.invalidate(_turnoverProvider);
        ref.invalidate(_policiesProvider);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Inventory Analytics')),
        body: ListView(
          padding: KSpacing.pagePadding,
          children: [
            Text('Inventory Turnover', style: KTypography.titleMedium),
            const SizedBox(height: KSpacing.sm),
            turnoverAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(ApiErrorParser.message(e)),
              data: (items) {
                if (items.isEmpty) return const Text('No sales data for turnover analysis');
                return Column(
                  children: items.map((item) {
                    final m = item as Map<String, dynamic>;
                    final turnover = (m['turnoverRatio'] as num?)?.toDouble() ?? 0;
                    final doh = (m['daysOnHand'] as num?)?.toInt() ?? 999;
                    final color = turnover >= 6 ? KColors.success
                        : turnover >= 2 ? KColors.warning
                        : KColors.error;

                    return Card(
                      margin: const EdgeInsets.only(bottom: KSpacing.xs),
                      child: ListTile(
                        title: Text(m['itemName'] ?? '', style: KTypography.titleSmall),
                        subtitle: Text(
                          'COGS: ${CurrencyFormatter.formatIndian((m['cogs'] as num?)?.toDouble() ?? 0)} | '
                          'Avg Inventory: ${CurrencyFormatter.formatIndian((m['avgInventoryValue'] as num?)?.toDouble() ?? 0)}',
                          style: KTypography.bodySmall,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${turnover.toStringAsFixed(1)}x',
                                style: KTypography.titleSmall.copyWith(color: color)),
                            Text('$doh days', style: KTypography.bodySmall),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: KSpacing.lg),
            Row(
              children: [
                Text('ABC Classification', style: KTypography.titleMedium),
                const Spacer(),
                FilledButton.tonal(
                  onPressed: () async {
                    try {
                      await ref.read(supplyChainRepositoryProvider).runAbcClassification();
                      ref.invalidate(_policiesProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ABC classification updated')),
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
                  child: const Text('Run ABC'),
                ),
              ],
            ),
            const SizedBox(height: KSpacing.sm),
            policiesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(ApiErrorParser.message(e)),
              data: (policies) {
                if (policies.isEmpty) return const Text('Run ABC classification to categorize items');
                return Column(
                  children: policies.map((p) {
                    final m = p as Map<String, dynamic>;
                    final cls = m['abcClass'] as String? ?? '?';
                    final color = switch (cls) {
                      'A' => KColors.error,
                      'B' => KColors.warning,
                      'C' => KColors.success,
                      _ => KColors.draft,
                    };

                    return Card(
                      margin: const EdgeInsets.only(bottom: KSpacing.xs),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: 0.2),
                          child: Text(cls, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                        ),
                        title: Text('Item: ${m['itemId']?.toString().substring(0, 8) ?? ''}...',
                            style: KTypography.titleSmall),
                        subtitle: Text(
                          'Safety: ${m['safetyStock']} | ROP: ${m['reorderPoint']} | EOQ: ${m['eoq']}',
                          style: KTypography.bodySmall,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
