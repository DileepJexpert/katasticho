import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../routing/app_router.dart';
import '../data/invoice_providers.dart';
import '../data/invoice_repository.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Sent', value: 'SENT'),
  KListTab(label: 'Partial', value: 'PARTIALLY_PAID'),
  KListTab(label: 'Paid', value: 'PAID'),
  KListTab(label: 'Overdue', value: 'OVERDUE'),
];

class InvoiceListScreen extends ConsumerStatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  ConsumerState<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends ConsumerState<InvoiceListScreen> {
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id)
            ? _selectedIds.remove(id)
            : _selectedIds.add(id);
      });

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _bulkSend() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Send $count invoice${count == 1 ? '' : 's'}?'),
        content: const Text(
            'This will mark selected invoices as sent and post their journal entries.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send Invoices'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(invoiceRepositoryProvider);
    final ids = _selectedIds.toList();
    try {
      final result = await repo.bulkSend(ids);
      if (!mounted) return;
      setState(_selectedIds.clear);
      ref.invalidate(invoiceListProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_bulkMsg(result, 'Sent'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
    }
  }

  Future<void> _bulkCancel() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel $count invoice${count == 1 ? '' : 's'}?'),
        content: const Text(
            'Cancelled invoices cannot be sent or paid. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.error.withValues(alpha: 0.12),
              foregroundColor: KColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Invoices'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(invoiceRepositoryProvider);
    final ids = _selectedIds.toList();
    try {
      final result = await repo.bulkCancel(ids);
      if (!mounted) return;
      setState(_selectedIds.clear);
      ref.invalidate(invoiceListProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_bulkMsg(result, 'Cancelled'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
    }
  }

  String _bulkMsg(Map<String, dynamic> result, String verb) {
    final data = (result['data'] as Map?) ?? {};
    final success = (data['successCount'] as num?)?.toInt() ?? 0;
    final fail = (data['failCount'] as num?)?.toInt() ?? 0;
    if (fail == 0) return '$verb $success successfully';
    return '$verb $success, $fail failed';
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(invoiceFilterProvider);
    final invoicesAsync = ref.watch(invoiceListProvider);
    final inSelection = _selectedIds.isNotEmpty;

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Invoices',
            searchHint: 'Search invoices…',
            tabs: _statusTabs,
            selectedTab: filter.status,
            onTabChanged: (v) => ref
                .read(invoiceFilterProvider.notifier)
                .state = filter.copyWith(status: v, page: 0),
            onSearchChanged: (q) => ref
                .read(invoiceFilterProvider.notifier)
                .state = filter.copyWith(search: q.isEmpty ? null : q, page: 0),
            actions: [
              KSavedViewButton(
                entityType: 'invoices',
                currentFilters: {
                  'status': filter.status,
                  'search': filter.search,
                },
                onViewSelected: (filters) {
                  ref.read(invoiceFilterProvider.notifier).state =
                      filter.copyWith(
                    status: filters['status'],
                    search: filters['search'],
                    page: 0,
                  );
                },
              ),
            ],
            selectionCount: _selectedIds.length,
            onClearSelection: _clearSelection,
            selectionActions: [
              IconButton(
                icon: const Icon(Icons.send_outlined, size: 20),
                tooltip: 'Send selected',
                visualDensity: VisualDensity.compact,
                onPressed: _bulkSend,
              ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined, size: 20),
                tooltip: 'Cancel selected',
                color: KColors.error,
                visualDensity: VisualDensity.compact,
                onPressed: _bulkCancel,
              ),
            ],
          ),
          Expanded(
            child: invoicesAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load invoices',
                onRetry: () => ref.invalidate(invoiceListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return KEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices yet',
                    subtitle: 'Create your first invoice to get started',
                    actionLabel: 'Create Invoice',
                    onAction: () => context.go(Routes.invoiceCreate),
                  );
                }

                final invoices = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (invoices.isEmpty) {
                  return KEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No invoices found',
                    subtitle: filter.status != null
                        ? 'No ${filter.status!.toLowerCase()} invoices'
                        : 'Create your first invoice',
                    actionLabel: 'Create Invoice',
                    onAction: () => context.go(Routes.invoiceCreate),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(invoiceListProvider),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final inv = invoices[index] as Map<String, dynamic>;
                      final id = inv['id']?.toString() ?? '';
                      return _InvoiceCard(
                        invoice: inv,
                        selected: _selectedIds.contains(id),
                        inSelection: inSelection,
                        onToggleSelect: () => _toggleSelect(id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: inSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(Routes.invoiceCreate),
              icon: const Icon(Icons.add),
              label: const Text('New Invoice'),
            ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final bool selected;
  final bool inSelection;
  final VoidCallback onToggleSelect;

  const _InvoiceCard({
    required this.invoice,
    required this.selected,
    required this.inSelection,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = invoice['status'] as String? ?? 'DRAFT';
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final balanceDue = (invoice['balanceDue'] as num?)?.toDouble() ?? total;
    final customerName = invoice['contactName'] as String? ?? 'Unknown';
    final invoiceNumber = invoice['invoiceNumber'] as String? ?? '--';
    final invoiceDate = invoice['invoiceDate'] as String?;
    final dueDate = invoice['dueDate'] as String?;
    final isOverdue = status == 'OVERDUE';
    final hasBalance = balanceDue > 0 && balanceDue < total;
    final paidPct = total > 0 ? ((total - balanceDue) / total) : 0.0;

    return KCard(
      onTap: () {
        if (inSelection) {
          onToggleSelect();
          return;
        }
        final id = invoice['id']?.toString();
        if (id != null) context.go('/invoices/$id');
      },
      onLongPress: onToggleSelect,
      borderColor: selected ? cs.primary : null,
      backgroundColor: selected ? cs.primary.withValues(alpha: 0.06) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inSelection) ...[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? cs.primary : cs.onSurfaceVariant,
                size: 20,
              ),
            ),
            KSpacing.hGapSm,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: invoice# · status · total
                Row(
                  children: [
                    Text(invoiceNumber, style: KTypography.labelLarge),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                    const Spacer(),
                    Text(
                      CurrencyFormatter.formatIndian(total),
                      style: KTypography.amountMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Row 2: customer · date · due/balance info
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        customerName,
                        style: KTypography.bodyMedium
                            .copyWith(color: KColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (invoiceDate != null) ...[
                      Icon(Icons.event,
                          size: 12, color: KColors.textHint),
                      const SizedBox(width: 3),
                      Text(
                        DateFormatter.short(DateTime.parse(invoiceDate)),
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                    ],
                  ],
                ),
                // Row 3 (conditional): due-date / balance / payment progress
                if (hasBalance || isOverdue || dueDate != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (dueDate != null) ...[
                        Icon(
                          isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.schedule,
                          size: 12,
                          color: isOverdue
                              ? KColors.error
                              : KColors.textHint,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          DateFormatter.dueStatus(DateTime.parse(dueDate)),
                          style: KTypography.bodySmall.copyWith(
                            color: isOverdue
                                ? KColors.error
                                : KColors.textSecondary,
                            fontWeight: isOverdue ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (hasBalance)
                        Text(
                          'Due ${CurrencyFormatter.formatIndian(balanceDue)}',
                          style: KTypography.bodySmall.copyWith(
                            color: KColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (status == 'PAID')
                        Text(
                          'Paid in full',
                          style: KTypography.bodySmall.copyWith(
                            color: KColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  if (hasBalance) ...[
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: paidPct,
                        minHeight: 3,
                        backgroundColor:
                            KColors.divider.withValues(alpha: 0.5),
                        valueColor: AlwaysStoppedAnimation(
                          isOverdue ? KColors.error : KColors.warning,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (!inSelection) ...[
            KSpacing.hGapXs,
            const Icon(Icons.chevron_right,
                color: KColors.textHint, size: 18),
          ],
        ],
      ),
    );
  }
}
