import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/customer_receipt_repository.dart';
import 'record_customer_receipt_screen.dart';

/// Customer receipts: lump-sum collections allocated across many invoices,
/// with any excess parked as a customer advance.
class CustomerReceiptListScreen extends ConsumerWidget {
  const CustomerReceiptListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncReceipts = ref.watch(customerReceiptListProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Receipts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(customerReceiptListProvider(null)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRecord(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Record receipt'),
        tooltip: 'Record customer receipt (N)',
      ),
      body: asyncReceipts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(customerReceiptListProvider(null)),
        ),
        data: (body) {
          final content =
              ((body['data'] as Map?)?['content'] as List?) ?? const [];
          if (content.isEmpty) {
            return KEmptyState(
              icon: Icons.payments_outlined,
              title: 'No receipts yet',
              subtitle:
                  'Record a customer payment and allocate it across invoices.',
              actionLabel: 'Record receipt',
              onAction: () => _openRecord(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(customerReceiptListProvider(null)),
            child: ListView.separated(
              padding: const EdgeInsets.all(KSpacing.md),
              itemCount: content.length,
              separatorBuilder: (_, __) => const SizedBox(height: KSpacing.sm),
              itemBuilder: (_, i) =>
                  _receiptCard(context, ref, content[i] as Map<String, dynamic>),
            ),
          );
        },
      ),
    );
  }

  Widget _receiptCard(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) {
    final amount = (r['amount'] as num?)?.toDouble() ?? 0;
    final advance = (r['advanceAmount'] as num?)?.toDouble() ?? 0;
    final allocations = (r['allocations'] as List?)?.length ?? 0;
    return KCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(r['receiptNumber']?.toString() ?? '—',
                      style: KTypography.labelLarge),
                  const SizedBox(width: KSpacing.sm),
                  Text(r['receiptDate']?.toString() ?? '',
                      style: KTypography.bodySmall
                          .copyWith(color: KColors.textHint)),
                ]),
                const SizedBox(height: 2),
                Text(r['contactName']?.toString() ?? 'Customer',
                    style: KTypography.bodyMedium
                        .copyWith(color: KColors.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  '$allocations invoice${allocations == 1 ? '' : 's'}'
                  '${advance > 0 ? ' · ${CurrencyFormatter.format(advance)} advance' : ''}',
                  style: KTypography.bodySmall.copyWith(
                      color: advance > 0
                          ? KColors.warning
                          : KColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyFormatter.format(amount),
                  style: KTypography.labelLarge),
              TextButton(
                onPressed: () => _confirmVoid(context, ref, r),
                style: TextButton.styleFrom(
                    foregroundColor: KColors.error,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 28)),
                child: const Text('Void'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openRecord(BuildContext context, WidgetRef ref) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const RecordCustomerReceiptScreen(),
    ));
    if (saved == true) ref.invalidate(customerReceiptListProvider(null));
  }

  Future<void> _confirmVoid(
      BuildContext context, WidgetRef ref, Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void receipt?'),
        content: Text(
            'This reverses the journal entry and restores each invoice balance for '
            '${r['receiptNumber']}.'),
        actions: [
          TextButton(
              onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true),
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref
          .read(customerReceiptRepositoryProvider)
          .voidReceipt(r['id'] as String, reason: 'Voided from receipts list');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt voided — journal reversed')));
      }
      ref.invalidate(customerReceiptListProvider(null));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to void: $e')));
      }
    }
  }
}
