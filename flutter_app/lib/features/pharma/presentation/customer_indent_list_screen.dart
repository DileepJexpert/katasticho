import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../../routing/app_router.dart';
import '../data/customer_indent_repository.dart';

const _indentTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Requested', value: 'REQUESTED'),
  KListTab(label: 'Received', value: 'RECEIVED'),
  KListTab(label: 'Notified', value: 'NOTIFIED'),
  KListTab(label: 'Fulfilled', value: 'FULFILLED'),
];

class CustomerIndentListScreen extends ConsumerStatefulWidget {
  const CustomerIndentListScreen({super.key});

  @override
  ConsumerState<CustomerIndentListScreen> createState() =>
      _CustomerIndentListScreenState();
}

class _CustomerIndentListScreenState
    extends ConsumerState<CustomerIndentListScreen> {
  String? _status;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final indentsAsync = ref.watch(customerIndentsProvider);

    return Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Customer Indents',
            searchHint: 'Search customer, item, phone...',
            tabs: _indentTabs,
            selectedTab: _status,
            onTabChanged: (value) => setState(() => _status = value),
            onSearchChanged: (value) =>
                setState(() => _search = value.trim().toLowerCase()),
          ),
          Expanded(
            child: indentsAsync.when(
              loading: () => const KShimmerList(),
              error: (_, __) => KErrorView(
                message: 'Failed to load customer indents',
                onRetry: () => ref.invalidate(customerIndentsProvider),
              ),
              data: (indents) {
                final filtered = indents.where((indent) {
                  final status = indent['status']?.toString();
                  if (_status != null && status != _status) return false;
                  if (_search.isEmpty) return true;
                  final haystack = [
                    indent['indentNumber'],
                    indent['customerName'],
                    indent['customerPhone'],
                    indent['itemName'],
                    indent['itemSku'],
                    indent['status'],
                  ].whereType<Object>().join(' ').toLowerCase();
                  return haystack.contains(_search);
                }).toList();

                if (indents.isEmpty) {
                  return KEmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No customer indents yet',
                    subtitle:
                        'Create an indent when a customer asks for an out-of-stock item.',
                    actionLabel: 'New Indent',
                    onAction: () => context.go(Routes.customerIndentCreate),
                  );
                }
                if (filtered.isEmpty) {
                  return KEmptyState(
                    icon: Icons.search_off,
                    title: 'No matching indents',
                    subtitle: 'Try another status or search term.',
                    actionLabel: 'Clear Filters',
                    onAction: () => setState(() {
                      _status = null;
                      _search = '';
                    }),
                  );
                }

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: filtered,
                  onRefresh: () async =>
                      ref.invalidate(customerIndentsProvider),
                  mobileItemBuilder: (context, indent) =>
                      _IndentCard(indent: indent, onChanged: _refresh),
                  tableBuilder: (context) => _IndentTable(
                    indents: filtered,
                    onChanged: _refresh,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.customerIndentCreate),
        icon: const Icon(Icons.add),
        label: const Text('New Indent'),
      ),
    );
  }

  void _refresh() => ref.invalidate(customerIndentsProvider);
}

class _IndentTable extends ConsumerWidget {
  final List<Map<String, dynamic>> indents;
  final VoidCallback onChanged;

  const _IndentTable({required this.indents, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KEntityDataTable(
      columnSpacing: 18,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('Indent')),
        DataColumn(label: Text('Customer')),
        DataColumn(label: Text('Item')),
        DataColumn(label: Text('Qty'), numeric: true),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Created')),
        DataColumn(label: SizedBox(width: 92, child: Text(''))),
      ],
      rows: indents.map((indent) {
        final id = indent['id']?.toString() ?? '';
        final number = indent['indentNumber']?.toString() ?? '--';
        final customer = indent['customerName']?.toString() ?? '--';
        final item = indent['itemName']?.toString() ?? '--';
        final sku = indent['itemSku']?.toString();
        final qty = (indent['quantity'] as num?)?.toDouble() ?? 0;
        final status = indent['status']?.toString() ?? 'REQUESTED';
        final created = indent['createdAt']?.toString();

        return DataRow(
          color: kEntityRowColor(context),
          cells: [
            DataCell(KTablePrimaryTextCell(value: number, width: 120)),
            DataCell(KTableTextCell(value: customer, width: 180)),
            DataCell(KTableTextCell(
              value: sku == null || sku.isEmpty ? item : '$item - $sku',
              width: 240,
            )),
            DataCell(Text(
                qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2))),
            DataCell(KTableStatusCell(status: status)),
            DataCell(KTableDateCell(value: created)),
            DataCell(
                _IndentActions(id: id, status: status, onChanged: onChanged)),
          ],
        );
      }).toList(),
    );
  }
}

class _IndentCard extends StatelessWidget {
  final Map<String, dynamic> indent;
  final VoidCallback onChanged;

  const _IndentCard({required this.indent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final number = indent['indentNumber']?.toString() ?? '--';
    final customer = indent['customerName']?.toString() ?? '--';
    final phone = indent['customerPhone']?.toString();
    final item = indent['itemName']?.toString() ?? '--';
    final sku = indent['itemSku']?.toString();
    final qty = (indent['quantity'] as num?)?.toDouble() ?? 0;
    final status = indent['status']?.toString() ?? 'REQUESTED';
    final created = indent['createdAt']?.toString();

    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(number, style: KTypography.labelLarge)),
              KStatusChip(status: status),
            ],
          ),
          KSpacing.vGapXs,
          Text(customer, style: KTypography.bodyMedium),
          if (phone != null && phone.isNotEmpty)
            Text(phone, style: KTypography.bodySmall),
          KSpacing.vGapSm,
          Text(
            sku == null || sku.isEmpty ? item : '$item - $sku',
            style: KTypography.labelMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          KSpacing.vGapXs,
          Text(
            'Qty ${qty.toStringAsFixed(qty.truncateToDouble() == qty ? 0 : 2)}'
            '${created == null ? '' : ' - ${DateFormatter.display(DateTime.parse(created))}'}',
            style: KTypography.bodySmall,
          ),
          KSpacing.vGapSm,
          Align(
            alignment: Alignment.centerRight,
            child: _IndentActions(
              id: indent['id']?.toString() ?? '',
              status: status,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _IndentActions extends ConsumerWidget {
  final String id;
  final String status;
  final VoidCallback onChanged;

  const _IndentActions({
    required this.id,
    required this.status,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (id.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      children: [
        if (status == 'RECEIVED')
          TextButton(
            onPressed: () => _setStatus(context, ref, 'NOTIFIED'),
            child: const Text('Notify'),
          ),
        if (status == 'NOTIFIED' || status == 'RECEIVED')
          TextButton(
            onPressed: () => _setStatus(context, ref, 'FULFILLED'),
            child: const Text('Fulfill'),
          ),
        if (status != 'FULFILLED' && status != 'CANCELLED')
          IconButton(
            tooltip: 'Cancel indent',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => _setStatus(context, ref, 'CANCELLED'),
          ),
      ],
    );
  }

  Future<void> _setStatus(
      BuildContext context, WidgetRef ref, String nextStatus) async {
    try {
      await ref
          .read(customerIndentRepositoryProvider)
          .updateStatus(id, nextStatus);
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Indent marked $nextStatus')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update indent')),
        );
      }
    }
  }
}
