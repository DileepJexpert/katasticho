import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/recurring_invoice_repository.dart';

const _statusTabs = [
  KListTab(label: 'All'),
  KListTab(label: 'Active', value: 'ACTIVE'),
  KListTab(label: 'Paused', value: 'PAUSED'),
  KListTab(label: 'Stopped', value: 'STOPPED'),
  KListTab(label: 'Expired', value: 'EXPIRED'),
];

class RecurringInvoiceListScreen extends ConsumerStatefulWidget {
  const RecurringInvoiceListScreen({super.key});

  @override
  ConsumerState<RecurringInvoiceListScreen> createState() =>
      _RecurringInvoiceListScreenState();
}

class _RecurringInvoiceListScreenState
    extends ConsumerState<RecurringInvoiceListScreen> {
  String? _status;
  List<Map<String, dynamic>> _templates = const [];

  void _openAtIndex(int index) {
    if (index < 0 || index >= _templates.length) return;
    final id = _templates[index]['id']?.toString();
    if (id != null) context.push('/recurring-invoices/$id');
  }

  @override
  Widget build(BuildContext context) {
    final filters = RecurringInvoiceFilters(status: _status);
    final templates = ref.watch(recurringInvoiceListProvider(filters));
    return KKeyboardListWrapper(
      itemCount: () => _templates.length,
      onNew: () => context.push('/recurring-invoices/create'),
      onRefresh: () => ref.invalidate(recurringInvoiceListProvider(filters)),
      onOpen: _openAtIndex,
      child: Scaffold(
        body: Column(
          children: [
            KListPageHeader(
              title: 'Recurring Invoices',
              searchHint: 'Search recurring invoices',
              tabs: _statusTabs,
              selectedTab: _status,
              onTabChanged: (value) => setState(() => _status = value),
            ),
            Expanded(
              child: templates.when(
                loading: () => const KShimmerList(),
                error: (_, __) => KErrorView(
                  message: 'Failed to load recurring invoices',
                  onRetry: () =>
                      ref.invalidate(recurringInvoiceListProvider(filters)),
                ),
                data: (response) {
                  final data = response['data'];
                  final rows = data is List
                      ? data
                      : (data is Map ? (data['content'] as List?) ?? [] : []);
                  _templates = rows
                      .whereType<Map>()
                      .map((row) => row.cast<String, dynamic>())
                      .toList();
                  if (_templates.isEmpty) {
                    return KEmptyState(
                      icon: Icons.autorenew_outlined,
                      title: 'No recurring invoices yet',
                      subtitle: 'Create a template to generate invoices on a schedule.',
                      actionLabel: 'New Recurring Invoice',
                      onAction: () => context.push('/recurring-invoices/create'),
                    );
                  }
                  return KResponsiveEntityList<Map<String, dynamic>>(
                    items: _templates,
                    onRefresh: () async =>
                        ref.invalidate(recurringInvoiceListProvider(filters)),
                    mobileItemBuilder: (_, row) => _TemplateCard(template: row),
                    tableBuilder: (_) => _TemplateTable(templates: _templates),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/recurring-invoices/create'),
          icon: const Icon(Icons.add),
          label: const Text('New Template'),
        ),
      ),
    );
  }
}

class _TemplateTable extends StatelessWidget {
  const _TemplateTable({required this.templates});
  final List<Map<String, dynamic>> templates;

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columns: const [
        DataColumn(label: Text('Template')),
        DataColumn(label: Text('Customer')),
        DataColumn(label: Text('Frequency')),
        DataColumn(label: Text('Next Invoice')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Total'), numeric: true),
      ],
      rows: templates.map((template) {
        final id = template['id']?.toString() ?? '';
        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) {
            if (id.isNotEmpty) context.push('/recurring-invoices/$id');
          },
          cells: [
            DataCell(KTablePrimaryTextCell(value: template['profileName']?.toString() ?? 'Template')),
            DataCell(KTableTextCell(value: template['contactName']?.toString() ?? '--')),
            DataCell(KTableTextCell(value: _frequency(template['frequency']?.toString() ?? ''))),
            DataCell(KTableDateCell(value: template['nextInvoiceDate']?.toString())),
            DataCell(KTableStatusCell(status: template['status']?.toString() ?? 'ACTIVE')),
            DataCell(KTableAmountCell(value: (template['templateTotal'] as num?)?.toDouble() ?? 0)),
          ],
        );
      }).toList(),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template});
  final Map<String, dynamic> template;

  @override
  Widget build(BuildContext context) {
    final id = template['id']?.toString();
    final total = (template['templateTotal'] as num?)?.toDouble() ?? 0;
    return KCard(
      onTap: id == null ? null : () => context.push('/recurring-invoices/$id'),
      child: Row(
        children: [
          const Icon(Icons.autorenew_outlined, color: KColors.primary),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template['profileName']?.toString() ?? 'Template', style: KTypography.labelLarge),
                KSpacing.vGapXs,
                Text(template['contactName']?.toString() ?? '--', style: KTypography.bodySmall),
                KSpacing.vGapXs,
                Text('Next: ${template['nextInvoiceDate'] ?? '--'} | ${_frequency(template['frequency']?.toString() ?? '')}',
                    style: KTypography.labelSmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              KStatusChip(status: template['status']?.toString() ?? 'ACTIVE'),
              KSpacing.vGapSm,
              KMoney(total, size: KMoneySize.small),
            ],
          ),
        ],
      ),
    );
  }
}

String _frequency(String value) => switch (value) {
      'WEEKLY' => 'Weekly',
      'MONTHLY' => 'Monthly',
      'QUARTERLY' => 'Quarterly',
      'HALF_YEARLY' => 'Half-yearly',
      'YEARLY' => 'Yearly',
      _ => value,
    };
