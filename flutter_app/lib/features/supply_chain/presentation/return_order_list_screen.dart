import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/supply_chain_repository.dart';

final _returnListProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).listReturnOrders();
});

class ReturnOrderListScreen extends ConsumerWidget {
  const ReturnOrderListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_returnListProvider);

    return KKeyboardListWrapper(
      itemCount: () => (listAsync.valueOrNull?['content'] as List?)?.length ?? 0,
      onRefresh: () => ref.invalidate(_returnListProvider),
      child: Scaffold(
        appBar: AppBar(title: const Text('Return Orders')),
        body: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
          data: (data) {
            final items = (data['content'] as List?) ?? [];
            if (items.isEmpty) {
              return const Center(child: Text('No return orders'));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_returnListProvider),
              child: ListView.builder(
                padding: KSpacing.pagePadding,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final ro = items[index] as Map<String, dynamic>;
                  return _ReturnCard(ro: ro, ref: ref);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ReturnCard extends StatelessWidget {
  final Map<String, dynamic> ro;
  final WidgetRef ref;
  const _ReturnCard({required this.ro, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = ro['status'] as String? ?? 'DRAFT';
    final returnType = ro['returnType'] as String? ?? '';
    final color = switch (status) {
      'DRAFT' => KColors.draft,
      'APPROVED' => KColors.success,
      'PROCESSED' => KColors.info,
      'CANCELLED' => KColors.error,
      _ => KColors.draft,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        title: Row(
          children: [
            Text(ro['returnNumber'] ?? '', style: KTypography.titleSmall),
            const SizedBox(width: KSpacing.sm),
            KStatusChip(status: status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(returnType.replaceAll('_', ' '), style: KTypography.bodySmall),
            Text('Total: ${CurrencyFormatter.formatIndian((ro['totalAmount'] as num?)?.toDouble() ?? 0)}',
                style: KTypography.bodySmall),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (_) => [
            if (status == 'DRAFT')
              const PopupMenuItem(value: 'approve', child: Text('Approve')),
            if (status == 'APPROVED')
              const PopupMenuItem(value: 'process', child: Text('Process')),
            if (status != 'PROCESSED' && status != 'CANCELLED')
              const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final repo = ref.read(supplyChainRepositoryProvider);
    final id = ro['id'] as String;
    try {
      switch (action) {
        case 'approve':
          await repo.approveReturn(id);
        case 'process':
          await repo.processReturn(id);
        case 'cancel':
          await repo.cancelReturn(id);
      }
      ref.invalidate(_returnListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
        );
      }
    }
  }
}
