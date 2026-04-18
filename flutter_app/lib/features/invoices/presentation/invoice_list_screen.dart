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

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Sent', value: 'SENT'),
  KListTab(label: 'Partial', value: 'PARTIALLY_PAID'),
  KListTab(label: 'Paid', value: 'PAID'),
  KListTab(label: 'Overdue', value: 'OVERDUE'),
];

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(invoiceFilterProvider);
    final invoicesAsync = ref.watch(invoiceListProvider);

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
                .state = filter.copyWith(
                    search: q.isEmpty ? null : q, page: 0),
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
