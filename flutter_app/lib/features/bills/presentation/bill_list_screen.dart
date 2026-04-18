import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/bill_providers.dart';
import '../data/bill_repository.dart';
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

class BillListScreen extends ConsumerStatefulWidget {
  const BillListScreen({super.key});

  @override
  ConsumerState<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends ConsumerState<BillListScreen> {
  final Set<String> _selectedIds = {};

  void _toggleSelect(String id) => setState(() {
        _selectedIds.contains(id)
            ? _selectedIds.remove(id)
            : _selectedIds.add(id);
      });

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _bulkPost() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Post $count bill${count == 1 ? '' : 's'}?'),
        content: const Text(
            'This will post selected DRAFT bills, creating journal entries and updating inventory.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Post Bills'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(billRepositoryProvider);
    final ids = _selectedIds.toList();
    try {
      final result = await repo.bulkPost(ids);
      if (!mounted) return;
      setState(_selectedIds.clear);
      ref.invalidate(billListProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_bulkMsg(result, 'Posted'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
    }
  }

  Future<void> _bulkVoid() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Void $count bill${count == 1 ? '' : 's'}?'),
        content: const Text(
            'Bills with existing payments cannot be voided. This will reverse journal entries.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Go Back')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.error.withValues(alpha: 0.12),
              foregroundColor: KColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Void Bills'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(billRepositoryProvider);
    final ids = _selectedIds.toList();
    try {
      final result = await repo.bulkVoid(ids);
      if (!mounted) return;
      setState(_selectedIds.clear);
      ref.invalidate(billListProvider);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_bulkMsg(result, 'Voided'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error));
    }
  }

  Future<void> _bulkDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count bill${count == 1 ? '' : 's'}?'),
        content: const Text(
            'Only DRAFT bills can be deleted. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: KColors.error.withValues(alpha: 0.12),
              foregroundColor: KColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(billRepositoryProvider);
    final ids = _selectedIds.toList();
    int success = 0, failed = 0;
    for (final id in ids) {
      try {
        await repo.deleteBill(id);
        success++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
    ref.invalidate(billListProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(failed == 0
          ? 'Deleted $success bill${success == 1 ? '' : 's'}'
          : 'Deleted $success, $failed failed'),
    ));
  }

  String _bulkMsg(Map<String, dynamic> result, String verb) {
    final data = (result['data'] as Map?) ?? {};
    final success = (data['successCount'] as num?)?.toInt() ?? 0;
    final fail = (data['failCount'] as num?)?.toInt() ?? 0;
    if (fail == 0) return '$verb $success successfully';
    return '$verb $success, $fail failed';
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(billFilterProvider);
    final billsAsync = ref.watch(billListProvider);
    final inSelection = _selectedIds.isNotEmpty;

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
                .state = filter.copyWith(search: q.isEmpty ? null : q, page: 0),
            selectionCount: _selectedIds.length,
            onClearSelection: _clearSelection,
            selectionActions: [
              IconButton(
                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                tooltip: 'Post selected',
                visualDensity: VisualDensity.compact,
                onPressed: _bulkPost,
              ),
              IconButton(
                icon: const Icon(Icons.block_rounded, size: 20),
                tooltip: 'Void selected',
                color: KColors.warning,
                visualDensity: VisualDensity.compact,
                onPressed: _bulkVoid,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                tooltip: 'Delete selected',
                color: KColors.error,
                visualDensity: VisualDensity.compact,
                onPressed: _bulkDelete,
              ),
            ],
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
                      final id = bill['id']?.toString() ?? '';
                      return BillCard(
                        bill: bill,
                        selected: _selectedIds.contains(id),
                        inSelection: inSelection,
                        onToggleSelect: () => _toggleSelect(id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: inSelection
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.go(Routes.billCreate),
              icon: const Icon(Icons.add),
              label: const Text('New Bill'),
            ),
    );
  }
}
