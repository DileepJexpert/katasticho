import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/vendor_credit_providers.dart';
import 'widgets/vendor_credit_card.dart';

/// Filter tabs for vendor credit status.
const _statusFilters = [
  (null, 'All'),
  ('DRAFT', 'Draft'),
  ('OPEN', 'Open'),
  ('APPLIED', 'Applied'),
  ('VOID', 'Void'),
];

class VendorCreditListScreen extends ConsumerWidget {
  const VendorCreditListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(vendorCreditFilterProvider);
    final creditsAsync = ref.watch(vendorCreditListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Credits'),
      ),
      body: Column(
        children: [
          // Status filter chips
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
                        ref
                            .read(vendorCreditFilterProvider.notifier)
                            .state = VendorCreditListFilter(
                          status: f.$1,
                          contactId: filter.contactId,
                          page: 0,
                        );
                      },
                      selectedColor:
                          KColors.primary.withValues(alpha: 0.12),
                      checkmarkColor: KColors.primary,
                      labelStyle: TextStyle(
                        color: isActive
                            ? KColors.primary
                            : KColors.textSecondary,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1),

          // Credit list
          Expanded(
            child: creditsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load vendor credits',
                onRetry: () => ref.invalidate(vendorCreditListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return KEmptyState(
                    icon: Icons.note_alt_outlined,
                    title: 'No vendor credits yet',
                    subtitle:
                        'Create your first vendor credit to get started',
                    actionLabel: 'Create Credit',
                    onAction: () => context.go(Routes.vendorCreditCreate),
                  );
                }

                final credits = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (credits.isEmpty) {
                  return KEmptyState(
                    icon: Icons.note_alt_outlined,
                    title: 'No vendor credits found',
                    subtitle: filter.status != null
                        ? 'No ${filter.status} credits'
                        : 'Create your first vendor credit',
                    actionLabel: 'Create Credit',
                    onAction: () => context.go(Routes.vendorCreditCreate),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(vendorCreditListProvider),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: credits.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final credit =
                          credits[index] as Map<String, dynamic>;
                      return VendorCreditCard(credit: credit);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.vendorCreditCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Credit'),
      ),
    );
  }
}
