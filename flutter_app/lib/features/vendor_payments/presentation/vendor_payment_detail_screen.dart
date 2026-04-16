import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/vendor_payment_dto.dart';
import '../data/vendor_payment_providers.dart';
import '../data/vendor_payment_repository.dart';

class VendorPaymentDetailScreen extends ConsumerWidget {
  final String paymentId;

  const VendorPaymentDetailScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(vendorPaymentDetailProvider(paymentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Details'),
        actions: [
          paymentAsync.whenOrNull(
                data: (data) {
                  return PopupMenuButton<String>(
                    onSelected: (value) =>
                        _handleAction(context, ref, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'void',
                        child: Text('Void Payment',
                            style: TextStyle(color: KColors.error)),
                      ),
                    ],
                  );
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: paymentAsync.when(
        loading: () => const KLoading(message: 'Loading payment...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load payment',
          onRetry: () =>
              ref.invalidate(vendorPaymentDetailProvider(paymentId)),
        ),
        data: (data) {
          final raw = (data['data'] ?? data) as Map<String, dynamic>;
          final p = VendorPaymentDto(raw);
          return _PaymentDetailBody(payment: p);
        },
      ),
    );
  }

  void _handleAction(
      BuildContext context, WidgetRef ref, String action) {
    if (action == 'void') {
      _showVoidConfirmation(context, ref);
    }
  }

  void _showVoidConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void Payment?'),
        content: const Text(
          'This will reverse the journal entry and restore bill balances. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(vendorPaymentRepositoryProvider);
                await repo.voidPayment(paymentId);
                ref.invalidate(vendorPaymentDetailProvider(paymentId));
                ref.invalidate(vendorPaymentListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Payment voided — journal reversed')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to void payment')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Void Payment'),
          ),
        ],
      ),
    );
  }
}

class _PaymentDetailBody extends StatelessWidget {
  final VendorPaymentDto payment;

  const _PaymentDetailBody({required this.payment});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(KSpacing.md),
            color: KColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(payment.paymentNumber, style: KTypography.h2),
                KSpacing.vGapSm,
                Text(payment.vendorName, style: KTypography.bodyLarge),
                KSpacing.vGapMd,
                Text(
                  CurrencyFormatter.formatIndian(payment.amount),
                  style: KTypography.amountLarge.copyWith(
                    color: KColors.success,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          const TabBar(
            tabs: [
              Tab(text: 'Details'),
              Tab(text: 'Allocations'),
            ],
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              children: [
                // Details tab
                SingleChildScrollView(
                  padding: KSpacing.pagePadding,
                  child: KCard(
                    child: Column(
                      children: [
                        KDetailRow(
                          label: 'Payment #',
                          value: payment.paymentNumber,
                        ),
                        KDetailRow(
                          label: 'Vendor',
                          value: payment.vendorName,
                        ),
                        KDetailRow(
                          label: 'Payment Date',
                          value: payment.paymentDate.isNotEmpty
                              ? DateFormatter.display(
                                  DateTime.parse(payment.paymentDate))
                              : '--',
                        ),
                        KDetailRow(
                          label: 'Mode',
                          value: payment.paymentModeLabel,
                        ),
                        if (payment.referenceNumber.isNotEmpty)
                          KDetailRow(
                            label: 'Reference #',
                            value: payment.referenceNumber,
                          ),
                        KDetailRow(
                          label: 'Currency',
                          value: payment.currency,
                        ),
                        const Divider(),
                        KDetailRow(
                          label: 'Amount',
                          value:
                              CurrencyFormatter.formatIndian(payment.amount),
                          valueStyle: KTypography.amountMedium,
                        ),
                        if (payment.tdsAmount > 0)
                          KDetailRow(
                            label: 'TDS Deducted',
                            value: CurrencyFormatter.formatIndian(
                                payment.tdsAmount),
                            valueStyle: KTypography.amountSmall.copyWith(
                              color: KColors.warning,
                            ),
                          ),
                        if (payment.notes.isNotEmpty) ...[
                          const Divider(),
                          KDetailRow(
                              label: 'Notes', value: payment.notes),
                        ],
                      ],
                    ),
                  ),
                ),

                // Allocations tab — which bills this payment was applied to
                _AllocationsTab(allocations: payment.allocations),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AllocationsTab extends StatelessWidget {
  final List<PaymentAllocationDto> allocations;

  const _AllocationsTab({required this.allocations});

  @override
  Widget build(BuildContext context) {
    if (allocations.isEmpty) {
      return const KEmptyState(
        icon: Icons.receipt_outlined,
        title: 'No allocations',
        subtitle: 'This payment has not been allocated to any bills',
      );
    }

    return ListView.builder(
      padding: KSpacing.pagePadding,
      itemCount: allocations.length,
      itemBuilder: (context, index) {
        final alloc = allocations[index];
        return KCard(
          margin: const EdgeInsets.only(bottom: KSpacing.sm),
          onTap: () {
            if (alloc.billId.isNotEmpty) {
              context.go('/bills/${alloc.billId}');
            }
          },
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: KColors.primary.withValues(alpha: 0.1),
                  borderRadius: KSpacing.borderRadiusMd,
                ),
                child: const Icon(
                  Icons.receipt_outlined,
                  color: KColors.primary,
                  size: 20,
                ),
              ),
              KSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alloc.billNumber,
                        style: KTypography.labelLarge),
                    Text(
                      'Tap to view bill',
                      style: KTypography.bodySmall.copyWith(
                        color: KColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                CurrencyFormatter.formatIndian(alloc.amountApplied),
                style: KTypography.amountSmall,
              ),
              KSpacing.hGapSm,
              const Icon(Icons.chevron_right, color: KColors.textHint),
            ],
          ),
        );
      },
    );
  }
}
