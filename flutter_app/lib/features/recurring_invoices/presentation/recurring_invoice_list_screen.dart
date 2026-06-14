import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
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
  List<Map<String, dynamic>> _currentTemplates = const [];

  void _openAtIndex(int index) {
    if (index < 0 || index >= _currentTemplates.length) return;
    final id = _currentTemplates[index]['id']?.toString();
    if (id != null) context.push('/recurring-invoices/$id');
  }

  @override
  Widget build(BuildContext context) {
    final filters = RecurringInvoiceFilters(status: _status);
    final asyncTemplates = ref.watch(recurringInvoiceListProvider(filters));

    return KKeyboardListWrapper(
      itemCount: () => _currentTemplates.length,
      onNew: () => context.push('/recurring-invoices/create'),
      onRefresh: () => ref.invalidate(recurringInvoiceListProvider(filters)),
      onOpen: _openAtIndex,
      child: Scaffold(
      body: Column(
        children: [
          KListPageHeader(
            title: 'Recurring Invoices',
            searchHint: 'Search recurring invoices…',
            tabs: _statusTabs,
            selectedTab: _status,
            onTabChanged: (v) => setState(() => _status = v),
          ),
          Expanded(
            child: asyncTemplates.when(
              loading: () => const KShimmerList(),
              error: (err, _) => KErrorView(
                message: 'Failed to load recurring invoices',
                onRetry: () =>
                    ref.invalidate(recurringInvoiceListProvider(filters)),
              ),
              data: (data) {
                final content = data['data'];
                final templates = content is List
                    ? content
                    : (content is Map
                        ? (content['content'] as List?) ?? []
                        : []);

                if (templates.isEmpty) {
                  return KEmptyState(
                    icon: Icons.autorenew_outlined,
                    title: 'No recurring invoices yet',
                    subtitle:
                        'Set up a template to auto-generate invoices on a schedule',
                    actionLabel: 'New Recurring Invoice',
                    onAction: () =>
                        context.push('/recurring-invoices/create'),
                  );
                }

                final templateMaps = templates
                    .whereType<Map>()
                    .map((template) => template.cast<String, dynamic>())
                    .toList();
                _currentTemplates = templateMaps;

                return KResponsiveEntityList<Map<String, dynamic>>(
                  items: templateMaps,
                  onRefresh: () async =>
                      ref.invalidate(recurringInvoiceListProvider(filters)),
                  mobileItemBuilder: (context, template) =>
                      _TemplateCard(template: template),
                  tableBuilder: (context) =>
                      _TemplateTable(templates: templateMaps),
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
        tooltip: 'New Template (N)',
      ),
    ));
  }
}

class _TemplateTable extends StatelessWidget {
  final List<Map<String, dynamic>> templates;

  const _TemplateTable({required this.templates});

  @override
  Widget build(BuildContext context) {
    return KEntityDataTable(
      columnSpacing: 20,
      horizontalMargin: 14,
      columns: const [
        DataColumn(label: Text('Template')),
        DataColumn(label: Text('Customer')),
        DataColumn(label: Text('Frequency')),
        DataColumn(label: Text('Next Invoice')),
        DataColumn(label: Text('Auto')),
        DataColumn(label: Text('Generated')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Total'), numeric: true),
        DataColumn(label: SizedBox(width: 32, child: Text(''))),
      ],
      rows: templates.map((template) {
        final id = template['id']?.toString() ?? '';
        final name = template['profileName']?.toString() ?? 'Template';
        final contactName = template['contactName']?.toString() ?? '--';
        final frequency = template['frequency']?.toString() ?? '';
        final status = template['status']?.toString() ?? 'ACTIVE';
        final total = (template['templateTotal'] as num?)?.toDouble() ?? 0;
        final nextDate = template['nextInvoiceDate']?.toString();
        final autoSend = template['autoSend'] == true;
        final generated = (template['totalGenerated'] as num?)?.toInt() ?? 0;

        return DataRow(
          color: kEntityRowColor(context),
          onSelectChanged: (_) {
            if (id.isNotEmpty) context.push('/recurring-invoices/$id');
          },
          cells: [
            DataCell(KTablePrimaryTextCell(value: name, width: 190)),
            DataCell(KTableTextCell(value: contactName, width: 190)),
            DataCell(KTableTextCell(
              value: _recurringFrequencyLabel(frequency),
              width: 115,
            )),
            DataCell(KTableDateCell(value: nextDate)),
            DataCell(Icon(
              autoSend
                  ? Icons.check_circle_rounded
                  : Icons.remove_circle_outline,
              color: autoSend ? KColors.success : KColors.textHint,
              size: 18,
            )),
            DataCell(Text('$generated')),
            DataCell(KTableStatusCell(status: status)),
            DataCell(KTableAmountCell(value: total)),
            DataCell(KTableOpenActionCell(
              tooltip: 'Open recurring invoice',
              onPressed: id.isEmpty
                  ? null
                  : () => context.push('/recurring-invoices/$id'),
            )),
          ],
        );
      }).toList(),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> template;

  const _TemplateCard({required this.template});

  @override
  Widget build(BuildContext context) {
    final id = template['id']?.toString();
    final name = template['profileName'] as String? ?? 'Template';
    final contactName = template['contactName'] as String? ?? '—';
    final frequency = template['frequency'] as String? ?? '';
    final status = template['status'] as String? ?? 'ACTIVE';
    final total = (template['templateTotal'] as num?)?.toDouble() ?? 0;
    final nextDate = template['nextInvoiceDate'] as String? ?? '';
    final autoSend = template['autoSend'] as bool? ?? false;
    final generated = (template['totalGenerated'] as num?)?.toInt() ?? 0;

    final statusColor = _statusColor(status);

    return KCard(
      onTap: id != null
          ? () => context.push('/recurring-invoices/$id')
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.autorenew_rounded,
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
                        name,
                        style: KTypography.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(CurrencyFormatter.formatIndian(total),
                        style: KTypography.labelLarge),
                  ],
                ),
                KSpacing.vGapXs,
                Text(
                  contactName,
                  style: KTypography.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Icon(Icons.repeat, size: 12, color: KColors.textHint),
                    const SizedBox(width: 4),
                    Text(_recurringFrequencyLabel(frequency),
                        style: KTypography.labelSmall),
                    const SizedBox(width: 10),
                    Icon(Icons.event, size: 12, color: KColors.textHint),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'next ${_formatDate(nextDate)}',
                        style: KTypography.labelSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
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
                    const SizedBox(width: 6),
                    if (autoSend)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: KColors.info.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'AUTO-SEND',
                          style: KTypography.labelSmall
                              .copyWith(color: KColors.info),
                        ),
                      ),
                    const Spacer(),
                    Text('$generated generated',
                        style: KTypography.labelSmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'ACTIVE' => KColors.success,
      'PAUSED' => KColors.warning,
      'STOPPED' => KColors.error,
      'EXPIRED' => KColors.textHint,
      _ => KColors.textHint,
    };
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

String _recurringFrequencyLabel(String f) => switch (f) {
      'WEEKLY' => 'Weekly',
      'MONTHLY' => 'Monthly',
      'QUARTERLY' => 'Quarterly',
      'HALF_YEARLY' => 'Half-yearly',
      'YEARLY' => 'Yearly',
      _ => f,
    };
