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
import '../../../core/widgets/k_status_chip.dart';
import '../data/supply_chain_repository.dart';
import 'widgets/scm_breadcrumb.dart';

final _returnListProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).listReturnOrders();
});

class ReturnOrderListScreen extends ConsumerStatefulWidget {
  const ReturnOrderListScreen({super.key});

  @override
  ConsumerState<ReturnOrderListScreen> createState() => _ReturnOrderListScreenState();
}

class _ReturnOrderListScreenState extends ConsumerState<ReturnOrderListScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(_returnListProvider);
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => (listAsync.valueOrNull?['content'] as List?)?.length ?? 0,
      onRefresh: () => ref.invalidate(_returnListProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Return Orders (RMA)'),
          bottom: scmBreadcrumb(context, 'Returns'),
        ),
        body: listAsync.when(
          loading: () => const KLoading(message: 'Loading return orders...'),
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
                    onPressed: () => ref.invalidate(_returnListProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            final rawItems = (data['content'] as List?) ?? [];
            final items = rawItems.where((item) {
              if (_searchQuery.isEmpty) return true;
              final ro = item as Map<String, dynamic>;
              final retNo = (ro['returnNumber'] ?? '').toString().toLowerCase();
              final retType = (ro['returnType'] ?? '').toString().toLowerCase();
              final q = _searchQuery.toLowerCase();
              return retNo.contains(q) || retType.contains(q);
            }).toList();

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_returnListProvider),
              child: ListView(
                padding: KSpacing.pagePadding,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Return Merchandise Authorizations',
                        style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage supplier debit returns and customer replacement or credit returns.',
                        style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Search by return RMA # or type...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(KSpacing.radiusMd)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  KSpacing.vGapMd,
                  if (items.isEmpty)
                    KEmptyState(
                      icon: Icons.assignment_return_outlined,
                      title: 'No return orders found',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'No return orders match "$_searchQuery".'
                          : 'Return orders drafted from delivery challans or near-expiry batches will appear here.',
                    )
                  else
                    ...items.map((item) {
                      final ro = item as Map<String, dynamic>;
                      return _ReturnCard(ro: ro, ref: ref);
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

class _ReturnCard extends StatelessWidget {
  final Map<String, dynamic> ro;
  final WidgetRef ref;
  const _ReturnCard({required this.ro, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = ro['status'] as String? ?? 'DRAFT';
    final returnType = (ro['returnType'] as String? ?? 'RETURN').replaceAll('_', ' ');
    final amount = (ro['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final returnNo = ro['returnNumber'] ?? 'RMA-???';
    final reason = ro['reason'] as String?;

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      padding: const EdgeInsets.all(KSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(KSpacing.radiusMd),
            ),
            child: Icon(Icons.assignment_return_rounded, color: cs.primary, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      returnNo,
                      style: KTypography.mono(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    KStatusChip(status: status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  returnType,
                  style: KTypography.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    reason,
                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Value: ',
                      style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    ),
                    KMoney(amount, style: KTypography.titleSmall),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: cs.onSurfaceVariant),
            onSelected: (action) => _handleAction(context, action),
            itemBuilder: (_) => [
              if (status == 'DRAFT')
                const PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Approve Return'),
                    ],
                  ),
                ),
              if (status == 'APPROVED')
                const PopupMenuItem(
                  value: 'process',
                  child: Row(
                    children: [
                      Icon(Icons.autorenew_rounded, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Process Return'),
                    ],
                  ),
                ),
              if (status != 'PROCESSED' && status != 'CANCELLED')
                const PopupMenuItem(
                  value: 'cancel',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Cancel RMA'),
                    ],
                  ),
                ),
            ],
          ),
        ],
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Return order marked as $action')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
        );
      }
    }
  }
}
