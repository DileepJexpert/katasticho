import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/expense_repository.dart';

const List<String> kExpenseCategories = [
  'Travel',
  'Meals',
  'Office',
  'Utilities',
  'Rent',
  'Software',
  'Marketing',
  'Fuel',
  'Repairs',
  'Other',
];

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  DateTime? _from;
  DateTime? _to;
  String? _category;

  @override
  Widget build(BuildContext context) {
    final filters = ExpenseFilters(
      from: _from,
      to: _to,
      category: _category,
    );
    final asyncExpenses = ref.watch(expenseListProvider(filters));

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Expenses',
            searchHint: 'Search expenses…',
            actions: [
              IconButton(
                icon: const Icon(Icons.filter_alt_outlined, size: 20),
                tooltip: 'Filter',
                visualDensity: VisualDensity.compact,
                onPressed: _openFilterSheet,
              ),
            ],
          ),
          if (_from != null || _to != null || _category != null)
            _FilterChipsBar(
              from: _from,
              to: _to,
              category: _category,
              onClearDate: () => setState(() {
                _from = null;
                _to = null;
              }),
              onClearCategory: () => setState(() => _category = null),
              onClearAll: () => setState(() {
                _from = null;
                _to = null;
                _category = null;
              }),
            ),
          Expanded(
            child: asyncExpenses.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load expenses',
                onRetry: () => ref.invalidate(expenseListProvider(filters)),
              ),
              data: (data) {
                final content = data['data'];
                final expenses = content is List
                    ? content
                    : (content is Map
                        ? (content['content'] as List?) ?? []
                        : []);

                if (expenses.isEmpty) {
                  return KEmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses yet',
                    subtitle: 'Record your first business expense',
                    actionLabel: 'Add Expense',
                    onAction: () => context.push('/expenses/create'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(expenseListProvider(filters)),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: expenses.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, i) => _ExpenseCard(
                      expense: expenses[i] as Map<String, dynamic>,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/create'),
        icon: const Icon(Icons.add),
        label: const Text('Record Expense'),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _FilterSheet(
        initialFrom: _from,
        initialTo: _to,
        initialCategory: _category,
        onApply: (from, to, category) {
          setState(() {
            _from = from;
            _to = to;
            _category = category;
          });
        },
      ),
    );
  }
}

class _FilterChipsBar extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final String? category;
  final VoidCallback onClearDate;
  final VoidCallback onClearCategory;
  final VoidCallback onClearAll;

  const _FilterChipsBar({
    required this.from,
    required this.to,
    required this.category,
    required this.onClearDate,
    required this.onClearCategory,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = (from != null && to != null)
        ? '${_fmt(from!)} → ${_fmt(to!)}'
        : (from != null
            ? 'From ${_fmt(from!)}'
            : (to != null ? 'Until ${_fmt(to!)}' : null));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          KSpacing.md, KSpacing.sm, KSpacing.md, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (dateLabel != null)
            InputChip(
              label: Text(dateLabel),
              avatar: const Icon(Icons.date_range, size: 16),
              onDeleted: onClearDate,
            ),
          if (category != null)
            InputChip(
              label: Text(category!),
              avatar: const Icon(Icons.category_outlined, size: 16),
              onDeleted: onClearCategory,
            ),
          ActionChip(
            label: const Text('Clear all'),
            avatar: const Icon(Icons.close, size: 16),
            onPressed: onClearAll,
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _FilterSheet extends StatefulWidget {
  final DateTime? initialFrom;
  final DateTime? initialTo;
  final String? initialCategory;
  final void Function(DateTime? from, DateTime? to, String? category) onApply;

  const _FilterSheet({
    required this.initialFrom,
    required this.initialTo,
    required this.initialCategory,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? _from;
  DateTime? _to;
  String? _category;

  @override
  void initState() {
    super.initState();
    _from = widget.initialFrom;
    _to = widget.initialTo;
    _category = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: KSpacing.md,
        right: KSpacing.md,
        top: KSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + KSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filter Expenses', style: KTypography.h3),
            KSpacing.vGapMd,
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'From',
                    value: _from,
                    onChanged: (d) => setState(() => _from = d),
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: _DateField(
                    label: 'To',
                    value: _to,
                    onChanged: (d) => setState(() => _to = d),
                  ),
                ),
              ],
            ),
            KSpacing.vGapMd,
            Text('Category', style: KTypography.labelLarge),
            KSpacing.vGapSm,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Any'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ...kExpenseCategories.map((c) => FilterChip(
                      label: Text(c),
                      selected: _category == c,
                      onSelected: (_) =>
                          setState(() => _category = _category == c ? null : c),
                    )),
              ],
            ),
            KSpacing.vGapLg,
            KButton(
              label: 'Apply filters',
              fullWidth: true,
              onPressed: () {
                widget.onApply(_from, _to, _category);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 1),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value == null
              ? 'Any'
              : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
        ),
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final Map<String, dynamic> expense;

  const _ExpenseCard({required this.expense});

  @override
  Widget build(BuildContext context) {
    final id = expense['id']?.toString();
    final number = expense['expenseNumber'] as String? ?? '';
    final date = expense['expenseDate'] as String? ?? '';
    final category = expense['category'] as String?;
    final description = expense['description'] as String?;
    final total = (expense['total'] as num?)?.toDouble() ?? 0;
    final status = expense['status'] as String? ?? 'RECORDED';
    final contactName = expense['contactName'] as String?;
    final paymentMode = expense['paymentMode'] as String? ?? 'CASH';

    final statusColor = switch (status) {
      'VOID' => KColors.error,
      'INVOICED' => KColors.info,
      'BILLABLE' => KColors.warning,
      _ => KColors.success,
    };

    return KCard(
      onTap: id != null ? () => context.push('/expenses/$id') : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconFor(category),
                color: statusColor, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category ?? description ?? number,
                        style: KTypography.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: KTypography.labelLarge),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          _formatDate(date),
                          if (contactName != null && contactName.isNotEmpty)
                            contactName,
                          paymentMode,
                        ].join(' • '),
                        style: KTypography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    KSpacing.hGapSm,
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: KTypography.labelSmall
                            .copyWith(color: statusColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String? category) {
    if (category == null) return Icons.receipt_long_outlined;
    final c = category.toLowerCase();
    if (c.contains('travel')) return Icons.flight_outlined;
    if (c.contains('meal') || c.contains('food')) return Icons.restaurant_outlined;
    if (c.contains('office')) return Icons.chair_outlined;
    if (c.contains('util')) return Icons.bolt_outlined;
    if (c.contains('rent')) return Icons.home_outlined;
    if (c.contains('software')) return Icons.cloud_outlined;
    if (c.contains('market')) return Icons.campaign_outlined;
    if (c.contains('fuel')) return Icons.local_gas_station_outlined;
    if (c.contains('repair')) return Icons.build_outlined;
    return Icons.receipt_long_outlined;
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
