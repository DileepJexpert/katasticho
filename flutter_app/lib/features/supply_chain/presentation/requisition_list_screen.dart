import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/currency_formatter.dart';
import '../data/supply_chain_repository.dart';

final _requisitionListProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).listRequisitions();
});

class RequisitionListScreen extends ConsumerWidget {
  const RequisitionListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_requisitionListProvider);

    return KKeyboardListWrapper(
      itemCount: () => (listAsync.valueOrNull?['content'] as List?)?.length ?? 0,
      onRefresh: () => ref.invalidate(_requisitionListProvider),
      child: Scaffold(
        appBar: AppBar(title: const Text('Purchase Requisitions')),
        floatingActionButton: FloatingActionButton(
          tooltip: 'Auto-PR from Low Stock (N)',
          onPressed: () async {
            try {
              await ref.read(supplyChainRepositoryProvider).autoCreateRequisition();
              ref.invalidate(_requisitionListProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Requisition created from low stock')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                );
              }
            }
          },
          child: const Icon(Icons.add),
        ),
        body: listAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
          data: (data) {
            final items = (data['content'] as List?) ?? [];
            if (items.isEmpty) {
              return const Center(child: Text('No purchase requisitions'));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_requisitionListProvider),
              child: ListView.builder(
                padding: KSpacing.screenPadding,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final pr = items[index] as Map<String, dynamic>;
                  return _RequisitionCard(pr: pr, ref: ref);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequisitionCard extends StatelessWidget {
  final Map<String, dynamic> pr;
  final WidgetRef ref;
  const _RequisitionCard({required this.pr, required this.ref});

  @override
  Widget build(BuildContext context) {
    final status = pr['status'] as String? ?? 'DRAFT';
    final color = switch (status) {
      'DRAFT' => KColors.neutral,
      'SUBMITTED' => KColors.info,
      'APPROVED' => KColors.success,
      'REJECTED' => KColors.error,
      _ => KColors.neutral,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        title: Row(
          children: [
            Text(pr['requisitionNumber'] ?? '', style: KTypography.titleSmall),
            const SizedBox(width: KSpacing.sm),
            KStatusChip(label: status, color: color),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (pr['notes'] != null) Text(pr['notes'], maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('Total: ${CurrencyFormatter.format(pr['totalAmount'])}',
                style: KTypography.bodySmall),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (_) => [
            if (status == 'DRAFT')
              const PopupMenuItem(value: 'submit', child: Text('Submit')),
            if (status == 'SUBMITTED') ...[
              const PopupMenuItem(value: 'approve', child: Text('Approve')),
              const PopupMenuItem(value: 'reject', child: Text('Reject')),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final repo = ref.read(supplyChainRepositoryProvider);
    final id = pr['id'] as String;
    try {
      switch (action) {
        case 'submit':
          await repo.submitRequisition(id);
        case 'approve':
          await repo.approveRequisition(id);
        case 'reject':
          await repo.rejectRequisition(id);
      }
      ref.invalidate(_requisitionListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
        );
      }
    }
  }
}
