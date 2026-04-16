import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/bill_providers.dart';
import 'widgets/bill_card.dart';

/// Filter tabs for bill status.
const _statusFilters = [
  (null, 'All'),
  ('DRAFT', 'Draft'),
  ('OPEN', 'Open'),
  ('OVERDUE', 'Overdue'),
  ('PARTIALLY_PAID', 'Partial'),
  ('PAID', 'Paid'),
  ('VOID', 'Void'),
];

class BillListScreen extends ConsumerWidget {
  const BillListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(billFilterProvider);
    final billsAsync = ref.watch(billListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bills'),
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
                        ref.read(billFilterProvider.notifier).state =
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

          // Bill list
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
                        ? 'No ${filter.status} bills'
                        : 'Create your first purchase bill',
                    actionLabel: 'Create Bill',
                    onAction: () => context.go(Routes.billCreate),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(billListProvider),
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

  void _showSearch(BuildContext context, WidgetRef ref) {
    showSearch(
      context: context,
      delegate: _BillSearchDelegate(ref),
    );
  }
}

class _BillSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;

  _BillSearchDelegate(this.ref);

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
    close(context, query);
    return const SizedBox();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Type to search bills...'),
    );
  }
}
