import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/vendor_credit_providers.dart';
import 'widgets/vendor_credit_card.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Open', value: 'OPEN'),
  KListTab(label: 'Applied', value: 'APPLIED'),
  KListTab(label: 'Void', value: 'VOID'),
];

class VendorCreditListScreen extends ConsumerWidget {
  const VendorCreditListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(vendorCreditFilterProvider);
    final creditsAsync = ref.watch(vendorCreditListProvider);

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Vendor Credits',
            searchHint: 'Search vendor credits…',
            tabs: _statusTabs,
            selectedTab: filter.status,
            onTabChanged: (v) => ref
                .read(vendorCreditFilterProvider.notifier)
                .state = VendorCreditListFilter(
              status: v,
              contactId: filter.contactId,
              page: 0,
            ),
          ),
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
