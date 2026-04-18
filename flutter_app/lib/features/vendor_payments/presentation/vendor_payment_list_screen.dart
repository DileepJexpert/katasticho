import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/vendor_payment_providers.dart';
import 'widgets/vendor_payment_card.dart';

class VendorPaymentListScreen extends ConsumerWidget {
  const VendorPaymentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(vendorPaymentFilterProvider);
    final paymentsAsync = ref.watch(vendorPaymentListProvider);

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Vendor Payments',
            searchHint: 'Search payments…',
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_list, size: 20),
                tooltip: 'Filter by date',
                visualDensity: VisualDensity.compact,
                onPressed: () => _showFilterSheet(context, ref),
              ),
            ],
          ),
          if (filter.dateFrom != null || filter.dateTo != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: KSpacing.md,
                vertical: KSpacing.sm,
              ),
              color: KColors.primary.withValues(alpha: 0.06),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt_outlined,
                      size: 16, color: KColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _filterSummary(filter),
                      style: KTypography.bodySmall.copyWith(
                        color: KColors.primary,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      ref.read(vendorPaymentFilterProvider.notifier).state =
                          const VendorPaymentListFilter();
                    },
                    child: Text(
                      'Clear',
                      style: KTypography.labelSmall.copyWith(
                        color: KColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: paymentsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load payments',
                onRetry: () => ref.invalidate(vendorPaymentListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return const KEmptyState(
                    icon: Icons.payments_outlined,
                    title: 'No vendor payments yet',
                    subtitle: 'Payments recorded from bills will appear here',
                  );
                }

                final payments = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (payments.isEmpty) {
                  return const KEmptyState(
                    icon: Icons.payments_outlined,
                    title: 'No payments found',
                    subtitle: 'Try adjusting your filters',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(vendorPaymentListProvider),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: payments.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final payment =
                          payments[index] as Map<String, dynamic>;
                      return VendorPaymentCard(payment: payment);
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

  String _filterSummary(VendorPaymentListFilter filter) {
    final parts = <String>[];
    if (filter.dateFrom != null) parts.add('From: ${filter.dateFrom}');
    if (filter.dateTo != null) parts.add('To: ${filter.dateTo}');
    return parts.join('  ·  ');
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    final filter = ref.read(vendorPaymentFilterProvider);
    DateTime? dateFrom =
        filter.dateFrom != null ? DateTime.tryParse(filter.dateFrom!) : null;
    DateTime? dateTo =
        filter.dateTo != null ? DateTime.tryParse(filter.dateTo!) : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: KSpacing.md,
          right: KSpacing.md,
          top: KSpacing.lg,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filter Payments', style: KTypography.h2),
              KSpacing.vGapMd,
              KDatePicker(
                label: 'From Date',
                value: dateFrom,
                onChanged: (d) => setSheetState(() => dateFrom = d),
              ),
              KSpacing.vGapMd,
              KDatePicker(
                label: 'To Date',
                value: dateTo,
                onChanged: (d) => setSheetState(() => dateTo = d),
                firstDate: dateFrom,
              ),
              KSpacing.vGapLg,
              Row(
                children: [
                  Expanded(
                    child: KButton(
                      label: 'Clear',
                      variant: KButtonVariant.outlined,
                      onPressed: () {
                        ref
                            .read(vendorPaymentFilterProvider.notifier)
                            .state = const VendorPaymentListFilter();
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                  KSpacing.hGapMd,
                  Expanded(
                    child: KButton(
                      label: 'Apply',
                      onPressed: () {
                        ref
                            .read(vendorPaymentFilterProvider.notifier)
                            .state = VendorPaymentListFilter(
                          dateFrom: dateFrom != null
                              ? DateFormatter.api(dateFrom!)
                              : null,
                          dateTo: dateTo != null
                              ? DateFormatter.api(dateTo!)
                              : null,
                        );
                        Navigator.pop(ctx);
                      },
                    ),
                  ),
                ],
              ),
              KSpacing.vGapMd,
            ],
          ),
        ),
      ),
    );
  }
}
