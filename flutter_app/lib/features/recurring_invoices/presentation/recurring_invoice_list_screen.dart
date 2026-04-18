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

  @override
  Widget build(BuildContext context) {
    final filters = RecurringInvoiceFilters(status: _status);
    final asyncTemplates = ref.watch(recurringInvoiceListProvider(filters));

    return Scaffold(
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

                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(recurringInvoiceListProvider(filters)),
                  child: ListView.separated(
                    padding: KSpacing.pagePadding,
                    itemCount: templates.length,
                    separatorBuilder: (_, __) => KSpacing.vGapSm,
                    itemBuilder: (context, i) => _TemplateCard(
                      template: templates[i] as Map<String, dynamic>,
                    ),
                  ),
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
                    Text('₹${total.toStringAsFixed(0)}',
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
                    Text(_prettyFrequency(frequency),
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

  String _prettyFrequency(String f) {
    return switch (f) {
      'WEEKLY' => 'Weekly',
      'MONTHLY' => 'Monthly',
      'QUARTERLY' => 'Quarterly',
      'HALF_YEARLY' => 'Half-yearly',
      'YEARLY' => 'Yearly',
      _ => f,
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
