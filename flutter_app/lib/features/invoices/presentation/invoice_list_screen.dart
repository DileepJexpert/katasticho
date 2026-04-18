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

/// Filter tabs for invoice status.
const _statusFilters = [
  (null, 'All'),
  ('DRAFT', 'Draft'),
  ('SENT', 'Sent'),
  ('PARTIALLY_PAID', 'Partial'),
  ('PAID', 'Paid'),
  ('OVERDUE', 'Overdue'),
];

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(invoiceFilterProvider);
    final invoicesAsync = ref.watch(invoiceListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status filter tabs
          Container(
            color: KColors.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.md,
                vertical: KSpacing.sm,
              ),
              child: Row(
                children: _statusFilters.map((f) {
                  final isActive = filter.status == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.$2),
                      selected: isActive,
                      onSelected: (_) {
                        ref.read(invoiceFilterProvider.notifier).state =
                            filter.copyWith(status: f.$1, page: 0);
                      },
                      selectedColor:
                          KColors.primary.withValues(alpha: 0.12),
                      checkmarkColor: KColors.primary,
                      labelStyle: TextStyle(
                        color: isActive
                            ? KColors.primary
                            : KColors.textSecondary,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Invoice list
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
                        ? 'No ${filter.status} invoices'
                        : 'Create your first invoice',
                    actionLabel: 'Create Invoice',
                    onAction: () => context.go(Routes.invoiceCreate),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(invoiceListProvider),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final inv = invoices[index] as Map<String, dynamic>;
                      return _InvoiceCard(invoice: inv);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.invoiceCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
    );
  }

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(
      context: context,
      delegate: _InvoiceSearchDelegate(ref),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;

  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final status = invoice['status'] as String? ?? 'DRAFT';
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final balanceDue = (invoice['balanceDue'] as num?)?.toDouble() ?? total;
    final customerName = invoice['contactName'] as String? ?? 'Unknown';
    final invoiceNumber = invoice['invoiceNumber'] as String? ?? '--';
    final dueDate = invoice['dueDate'] as String?;

    return KCard(
      onTap: () {
        final id = invoice['id']?.toString();
        if (id != null) {
          context.go('/invoices/$id');
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(invoiceNumber, style: KTypography.labelLarge),
                    KSpacing.hGapSm,
                    KStatusChip(status: status),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  customerName,
                  style: KTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                if (dueDate != null) ...[
                  KSpacing.vGapXs,
                  Text(
                    DateFormatter.dueStatus(DateTime.parse(dueDate)),
                    style: KTypography.bodySmall.copyWith(
                      color: status == 'OVERDUE'
                          ? KColors.error
                          : KColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatIndian(total),
                style: KTypography.amountMedium,
              ),
              if (balanceDue < total && balanceDue > 0) ...[
                KSpacing.vGapXs,
                Text(
                  'Due: ${CurrencyFormatter.formatIndian(balanceDue)}',
                  style: KTypography.bodySmall.copyWith(
                    color: KColors.warning,
                  ),
                ),
              ],
            ],
          ),
          KSpacing.hGapSm,
          const Icon(Icons.chevron_right, color: KColors.textHint),
        ],
      ),
    );
  }
}

class _InvoiceSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;

  _InvoiceSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    ref.read(invoiceFilterProvider.notifier).state =
        InvoiceListFilter(search: query);
    close(context, query);
    return const SizedBox();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Type to search invoices...'),
    );
  }
}
