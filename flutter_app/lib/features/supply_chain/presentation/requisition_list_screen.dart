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

final _requisitionListProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(supplyChainRepositoryProvider).listRequisitions();
});

class RequisitionListScreen extends ConsumerStatefulWidget {
  const RequisitionListScreen({super.key});

  @override
  ConsumerState<RequisitionListScreen> createState() => _RequisitionListScreenState();
}

class _RequisitionListScreenState extends ConsumerState<RequisitionListScreen> {
  bool _creatingPr = false;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(_requisitionListProvider);
    final cs = Theme.of(context).colorScheme;

    return KKeyboardListWrapper(
      itemCount: () => (listAsync.valueOrNull?['content'] as List?)?.length ?? 0,
      onRefresh: () => ref.invalidate(_requisitionListProvider),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Purchase Requisitions'),
          bottom: scmBreadcrumb(context, 'Requisitions'),
        ),
        body: listAsync.when(
          loading: () => const KLoading(message: 'Loading requisitions...'),
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
                    onPressed: () => ref.invalidate(_requisitionListProvider),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            final rawItems = (data['content'] as List?) ?? [];
            final items = rawItems.where((item) {
              if (_searchQuery.isEmpty) return true;
              final pr = item as Map<String, dynamic>;
              final reqNo = (pr['requisitionNumber'] ?? '').toString().toLowerCase();
              final notes = (pr['notes'] ?? '').toString().toLowerCase();
              return reqNo.contains(_searchQuery.toLowerCase()) || notes.contains(_searchQuery.toLowerCase());
            }).toList();

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(_requisitionListProvider),
              child: ListView(
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
                              'Purchase Requisitions',
                              style: KTypography.h2.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Create and approve purchase requests before converting to POs.',
                              style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      KButton.primary(
                        label: 'Auto PR from Low Stock',
                        icon: Icons.add_rounded,
                        isLoading: _creatingPr,
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          setState(() => _creatingPr = true);
                          try {
                            await ref.read(supplyChainRepositoryProvider).autoCreateRequisition();
                            ref.invalidate(_requisitionListProvider);
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Requisition generated from low stock items')),
                            );
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
                    ],
                  ),
                  KSpacing.vGapMd,
                  TextFormField(
                    decoration: InputDecoration(
                      hintText: 'Search by requisition number or notes...',
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
                      icon: Icons.receipt_long_outlined,
                      title: 'No purchase requisitions found',
                      subtitle: _searchQuery.isNotEmpty
                          ? 'No requisitions match "$_searchQuery".'
                          : 'Create an automatic requisition from low stock items.',
                      actionLabel: _searchQuery.isEmpty ? 'Generate Auto PR' : null,
                      onAction: _searchQuery.isEmpty
                          ? () async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _creatingPr = true);
                              try {
                                await ref.read(supplyChainRepositoryProvider).autoCreateRequisition();
                                ref.invalidate(_requisitionListProvider);
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
                                );
                              } finally {
                                if (mounted) setState(() => _creatingPr = false);
                              }
                            }
                          : null,
                    )
                  else
                    ...items.map((item) {
                      final pr = item as Map<String, dynamic>;
                      return _RequisitionCard(pr: pr, ref: ref);
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

class _RequisitionCard extends StatelessWidget {
  final Map<String, dynamic> pr;
  final WidgetRef ref;
  const _RequisitionCard({required this.pr, required this.ref});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = pr['status'] as String? ?? 'DRAFT';
    final amount = (pr['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final reqNo = pr['requisitionNumber'] ?? 'PR-???';
    final notes = pr['notes'] as String?;

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
            child: Icon(Icons.receipt_long_rounded, color: cs.primary, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reqNo,
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
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    notes,
                    style: KTypography.bodySmall.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      'Total Est: ',
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
                  value: 'submit',
                  child: Row(
                    children: [
                      Icon(Icons.send_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Submit for Approval'),
                    ],
                  ),
                ),
              if (status == 'SUBMITTED') ...[
                const PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Approve Requisition'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reject',
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Reject Requisition'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action) async {
    final messenger = ScaffoldMessenger.of(context);
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
      messenger.showSnackBar(
        SnackBar(content: Text('Requisition $action completed')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiErrorParser.message(e)), backgroundColor: KColors.error),
      );
    }
  }
}
