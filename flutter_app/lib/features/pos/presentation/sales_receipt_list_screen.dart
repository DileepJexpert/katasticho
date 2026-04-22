import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/sales_receipt_providers.dart';

const _paymentTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Cash', value: 'CASH'),
  KListTab(label: 'UPI', value: 'UPI'),
  KListTab(label: 'Card', value: 'CARD'),
];

class SalesReceiptListScreen extends ConsumerWidget {
  const SalesReceiptListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(receiptFilterProvider);
    final receiptsAsync = ref.watch(receiptListProvider);

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Sales Receipts',
            searchHint: 'Search receipts...',
            tabs: _paymentTabs,
            selectedTab: filter.paymentMode,
            onTabChanged: (v) => ref.read(receiptFilterProvider.notifier).state =
                filter.copyWith(paymentMode: v, page: 0),
            onSearchChanged: (_) {},
          ),
          Expanded(
            child: receiptsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load receipts',
                onRetry: () => ref.invalidate(receiptListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return const KEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No receipts yet',
                    subtitle: 'Sales receipts from POS will appear here',
                  );
                }

                final receipts = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (receipts.isEmpty) {
                  return KEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No receipts found',
                    subtitle: filter.paymentMode != null
                        ? 'No ${filter.paymentMode!.toLowerCase()} receipts'
                        : 'Sales receipts from POS will appear here',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(receiptListProvider),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: receipts.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final r = receipts[index] as Map<String, dynamic>;
                      return _ReceiptCard(receipt: r);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;
  const _ReceiptCard({required this.receipt});

  IconData _paymentIcon(String? mode) => switch (mode?.toUpperCase()) {
        'CASH' => Icons.payments_outlined,
        'UPI' => Icons.qr_code,
        'CARD' => Icons.credit_card,
        _ => Icons.payment,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final id = receipt['id']?.toString() ?? '';
    final receiptNumber = receipt['receiptNumber']?.toString() ?? '';
    final date = receipt['receiptDate']?.toString() ?? '';
    final total = (receipt['total'] as num?)?.toDouble() ?? 0;
    final paymentMode = receipt['paymentMode']?.toString() ?? '';
    final contactName = receipt['contactName']?.toString();
    final lineCount = (receipt['lines'] as List?)?.length;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/sales-receipts/$id'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_paymentIcon(paymentMode),
                    color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(receiptNumber, style: KTypography.labelMedium),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            paymentMode,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: cs.onSecondaryContainer),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contactName ?? 'Walk-in Customer',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (lineCount != null)
                      Text(
                        '$lineCount item${lineCount == 1 ? '' : 's'} • $date',
                        style: KTypography.labelSmall
                            .copyWith(color: KColors.textSecondary, fontSize: 10),
                      ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatIndian(total),
                style: KTypography.amountMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
