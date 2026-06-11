import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_keyboard_list_wrapper.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../routing/app_router.dart';
import '../data/bill_dto.dart';
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
  List<Map<String, dynamic>> _currentBills = const [];
  final Set<String> _selectedIds = {};

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentBills.length) return;
    final id = _currentBills[index]['id']?.toString();
    if (id != null) context.go('/bills/$id');
  }

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

    var success = 0;
    final failures = <String>[];
    for (final id in ids) {
      try {
        await repo.postBill(id);
        success++;
      } catch (e) {
        failures.add(ApiErrorParser.message(e));
      }
    }

    if (!mounted) return;
    setState(_selectedIds.clear);
    ref.invalidate(billListProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures.isEmpty
              ? 'Posted $success bill${success == 1 ? '' : 's'}'
              : 'Posted $success, ${failures.length} failed: ${failures.first}',
        ),
        backgroundColor: failures.isEmpty ? null : KColors.error,
      ),
    );
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
        SnackBar(
          content: Text(ApiErrorParser.message(e)),
          backgroundColor: KColors.error,
        ),
      );
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

    return KKeyboardListWrapper(
      itemCount: () => _currentBills.length,
      onNew: () => context.go(Routes.billCreate),
      onRefresh: () => ref.invalidate(billListProvider),
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Bills',
            searchHint: 'Search bills...',
            tabs: _statusTabs,
            selectedTab: filter.status,
            onTabChanged: (v) => ref.read(billFilterProvider.notifier).state =
                filter.copyWith(status: v, page: 0),
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

                final billMaps = bills.cast<Map<String, dynamic>>();
                _currentBills = billMaps;

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: billMaps,
                  onRefresh: () async => ref.invalidate(billListProvider),
                  tableBuilder: (_) => _BillTable(
                    bills: billMaps,
                    selectedIds: _selectedIds,
                    onToggleSelect: _toggleSelect,
                  ),
                  mobileItemBuilder: (_, bill) {
                    final id = bill['id']?.toString() ?? '';
                    return BillCard(
                      bill: bill,
                      selected: _selectedIds.contains(id),
                      inSelection: inSelection,
                      onToggleSelect: () => _toggleSelect(id),
                    );
                  },
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
              tooltip: 'New Bill (N)',
            ),
    ),
    );
  }
}

class _BillTable extends StatelessWidget {
  final List<Map<String, dynamic>> bills;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;

  const _BillTable({
    required this.bills,
    required this.selectedIds,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context) {
    final inSelection = selectedIds.isNotEmpty;

    return KEntityDataTable(
      columnSpacing: 12,
      horizontalMargin: 8,
      dataRowMaxHeight: 64,
      columns: const [
        DataColumn(label: SizedBox(width: 24)),
        DataColumn(label: Text('Bill')),
        DataColumn(label: Text('Vendor')),
        DataColumn(label: Text('Vendor Ref')),
        DataColumn(label: Text('Dates')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Total'), numeric: true),
        DataColumn(label: Text('Settlement'), numeric: true),
        DataColumn(label: SizedBox(width: 28)),
      ],
      rows: bills.map((raw) {
        final b = BillDto(raw);
        final selected = selectedIds.contains(b.id);

        return DataRow(
          selected: selected,
          color: kEntityRowColor(context, selected: selected),
          onSelectChanged: (_) {
            if (b.id.isEmpty) return;
            if (inSelection) {
              onToggleSelect(b.id);
            } else {
              context.go('/bills/${b.id}');
            }
          },
          cells: [
            DataCell(KTableSelectionCell(
              selected: selected,
              onChanged: b.id.isEmpty ? null : (_) => onToggleSelect(b.id),
            )),
            DataCell(KTablePrimaryTextCell(value: b.billNumber, width: 124)),
            DataCell(KTableTextCell(value: b.vendorName, width: 148)),
            DataCell(KTableTextCell(
              value: b.vendorBillNumber.isEmpty ? '--' : b.vendorBillNumber,
              width: 96,
            )),
            DataCell(_BillDatesCell(
              billDate: b.billDate,
              dueDate: b.dueDate,
              overdue: b.isOverdue,
            )),
            DataCell(KTableStatusCell(status: b.status)),
            DataCell(KTableAmountCell(value: b.totalAmount)),
            DataCell(_BillSettlementCell(
              paid: b.amountPaid,
              balance: b.balanceDue,
              overdue: b.isOverdue,
            )),
            DataCell(_CompactOpenActionCell(
              onPressed:
                  b.id.isEmpty ? null : () => context.go('/bills/${b.id}'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _BillDatesCell extends StatelessWidget {
  final String? billDate;
  final String? dueDate;
  final bool overdue;

  const _BillDatesCell({
    required this.billDate,
    required this.dueDate,
    required this.overdue,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(billDate),
            style: KTypography.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          KSpacing.vGapXxs,
          Text(
            'Due ${_formatDate(dueDate)}',
            style: KTypography.bodySmall.copyWith(
              color: overdue ? KColors.error : KColors.textSecondary,
              fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) return '--';
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormatter.short(parsed);
  }
}

class _BillSettlementCell extends StatelessWidget {
  final double paid;
  final double balance;
  final bool overdue;

  const _BillSettlementCell({
    required this.paid,
    required this.balance,
    required this.overdue,
  });

  @override
  Widget build(BuildContext context) {
    final balanceColor = balance > 0
        ? (overdue ? KColors.error : KColors.warning)
        : KColors.success;

    return SizedBox(
      width: 118,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Paid ${CurrencyFormatter.formatIndian(paid)}',
            style: KTypography.bodySmall.copyWith(
              color: KColors.success,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          KSpacing.vGapXxs,
          Text(
            'Bal ${CurrencyFormatter.formatIndian(balance)}',
            style: KTypography.amountSmall.copyWith(color: balanceColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CompactOpenActionCell extends StatelessWidget {
  final VoidCallback? onPressed;

  const _CompactOpenActionCell({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 32,
      child: IconButton(
        tooltip: 'Open bill',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 32),
        icon: const Icon(Icons.chevron_right, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}
