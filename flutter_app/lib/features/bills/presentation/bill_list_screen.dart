import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/bill_providers.dart';
import 'widgets/bill_card.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Draft', value: 'DRAFT'),
  KListTab(label: 'Open', value: 'OPEN'),
  KListTab(label: 'Overdue', value: 'OVERDUE'),
  KListTab(label: 'Partial', value: 'PARTIALLY_PAID'),
  KListTab(label: 'Paid', value: 'PAID'),
  KListTab(label: 'Void', value: 'VOID'),
];

class BillListScreen extends ConsumerWidget {
  const BillListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(billFilterProvider);
    final billsAsync = ref.watch(billListProvider);

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Bills',
            searchHint: 'Search bills…',
            tabs: _statusTabs,
            selectedTab: filter.status,
            onTabChanged: (v) => ref
                .read(billFilterProvider.notifier)
                .state = filter.copyWith(status: v, page: 0),
            onSearchChanged: (q) => ref
                .read(billFilterProvider.notifier)
                .state = filter.copyWith(
                    search: q.isEmpty ? null : q, page: 0),
          ),
          Expanded(
            child: billsAsync.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load bills',
                onRetry: () => ref.invalidate(billListProvider),
              ),
              data: (data) {
                final content = data['data'];
                if (content == null) {
                  return KEmptyState(
                    icon: Icons.receipt_outlined,
                    title: 'No bills yet',
                    subtitle: 'Create your first purchase bill to get started',
                    actionLabel: 'Create Bill',
                    onAction: () => context.go(Routes.billCreate),
                  );
                }

                final bills = (content is List)
                    ? content
                    : (content['content'] as List?) ?? [];

                if (bills.isEmpty) {
                  return KEmptyState(
                    icon: Icons.receipt_outlined,
                    title: 'No bills found',
                    subtitle: filter.status != null
                        ? 'No ${filter.status!.toLowerCase()} bills'
                        : 'Create your first purchase bill',
                    actionLabel: 'Create Bill',
                    onAction: () => context.go(Routes.billCreate),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(billListProvider),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: bills.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, index) {
                      final bill = bills[index] as Map<String, dynamic>;
                      return BillCard(bill: bill);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.billCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Bill'),
      ),
    );
  }
}
