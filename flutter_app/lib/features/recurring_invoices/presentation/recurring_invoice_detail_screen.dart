import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/recurring_invoice_repository.dart';

class RecurringInvoiceDetailScreen extends ConsumerWidget {
  final String templateId;

  const RecurringInvoiceDetailScreen({super.key, required this.templateId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTemplate =
        ref.watch(recurringInvoiceDetailProvider(templateId));

    return asyncTemplate.when(
      loading: () => const Scaffold(body: KLoading()),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: const Text('Recurring invoice')),
        body: KErrorView(
          message: 'Failed to load template',
          onRetry: () =>
              ref.invalidate(recurringInvoiceDetailProvider(templateId)),
        ),
      ),
      data: (data) {
        final raw = data['data'] ?? data;
        final template = raw as Map<String, dynamic>;
        final name = template['profileName'] as String? ?? 'Template';
        final status = template['status'] as String? ?? 'ACTIVE';

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Template'),
                  Tab(text: 'Generated'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _DetailsTab(template: template),
                _GeneratedTab(templateId: templateId),
              ],
            ),
            bottomNavigationBar: _ActionBar(
              templateId: templateId,
              status: status,
            ),
          ),
        );
      },
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final Map<String, dynamic> template;

  const _DetailsTab({required this.template});

  @override
  Widget build(BuildContext context) {
    final status = template['status'] as String? ?? 'ACTIVE';
    final total = (template['templateTotal'] as num?)?.toDouble() ?? 0;
    final contactName = template['contactName'] as String?;
    final frequency = template['frequency'] as String? ?? '';
    final startDate = template['startDate'] as String? ?? '';
    final endDate = template['endDate'] as String?;
    final nextDate = template['nextInvoiceDate'] as String? ?? '';
    final paymentTerms = (template['paymentTermsDays'] as num?)?.toInt() ?? 0;
    final autoSend = template['autoSend'] as bool? ?? false;
    final notes = template['notes'] as String?;
    final terms = template['terms'] as String?;
    final totalGenerated = (template['totalGenerated'] as num?)?.toInt() ?? 0;
    final lastGeneratedAt = template['lastGeneratedAt'] as String?;
    final lines = (template['lineItems'] as List?) ?? const [];

    final statusColor = _statusColor(status);

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Center(
            child: Column(
              children: [
                Text('₹${total.toStringAsFixed(2)}',
                    style: KTypography.displayLarge),
                KSpacing.vGapXs,
                Text(
                  'per ${_prettyFrequency(frequency)} invoice',
                  style: KTypography.bodyMedium,
                ),
                KSpacing.vGapSm,
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status,
                      style: KTypography.labelMedium
                          .copyWith(color: statusColor)),
                ),
              ],
            ),
          ),
          KSpacing.vGapLg,

          _SectionHeader('Schedule'),
          _Row('Customer', contactName ?? '—'),
          _Row('Frequency', _prettyFrequency(frequency)),
          _Row('Starts on', _formatDate(startDate)),
          if (endDate != null) _Row('Ends on', _formatDate(endDate)),
          _Row('Next invoice', _formatDate(nextDate)),
          _Row('Payment terms',
              paymentTerms == 0 ? 'Due on receipt' : 'Net $paymentTerms days'),
          _Row('Auto-send', autoSend ? 'Yes' : 'No'),
          KSpacing.vGapMd,

          _SectionHeader('Line items'),
          for (final l in lines) _LineTile(line: l as Map<String, dynamic>),
          KSpacing.vGapMd,

          if ((notes != null && notes.isNotEmpty) ||
              (terms != null && terms.isNotEmpty)) ...[
            _SectionHeader('Notes & terms'),
            if (notes != null && notes.isNotEmpty) _Row('Notes', notes),
            if (terms != null && terms.isNotEmpty) _Row('Terms', terms),
            KSpacing.vGapMd,
          ],

          _SectionHeader('Lifecycle'),
          _Row('Invoices generated', '$totalGenerated'),
          if (lastGeneratedAt != null)
            _Row('Last generated', _formatDateTime(lastGeneratedAt)),
          KSpacing.vGapXl,
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
      'WEEKLY' => 'weekly',
      'MONTHLY' => 'monthly',
      'QUARTERLY' => 'quarterly',
      'HALF_YEARLY' => 'half-yearly',
      'YEARLY' => 'yearly',
      _ => f.toLowerCase(),
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

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _LineTile extends StatelessWidget {
  final Map<String, dynamic> line;

  const _LineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final description = line['description'] as String? ?? '';
    final quantity = (line['quantity'] as num?)?.toDouble() ?? 0;
    final rate = (line['rate'] as num?)?.toDouble() ?? 0;
    final amount = (line['amount'] as num?)?.toDouble() ?? 0;
    final taxRate = (line['taxRate'] as num?)?.toDouble() ?? 0;
    final discountPct = (line['discountPct'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(description, style: KTypography.labelLarge),
                ),
                Text('₹${amount.toStringAsFixed(2)}',
                    style: KTypography.labelLarge),
              ],
            ),
            KSpacing.vGapXs,
            Text(
              '${quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2)}'
              ' × ₹${rate.toStringAsFixed(2)}'
              '${discountPct > 0 ? ' • ${discountPct.toInt()}% off' : ''}'
              ' • GST ${taxRate.toInt()}%',
              style: KTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedTab extends ConsumerWidget {
  final String templateId;

  const _GeneratedTab({required this.templateId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncGenerated = ref.watch(recurringGeneratedProvider(templateId));

    return asyncGenerated.when(
      loading: () => const KLoading(),
      error: (_, __) => KErrorView(
        message: 'Failed to load generated invoices',
        onRetry: () => ref.invalidate(recurringGeneratedProvider(templateId)),
      ),
      data: (invoices) {
        if (invoices.isEmpty) {
          return const KEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No invoices generated yet',
            subtitle:
                'The scheduler fires at 06:00 each day — or use "Run now" from the bottom bar',
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(recurringGeneratedProvider(templateId)),
          child: ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: invoices.length,
            separatorBuilder: (_, __) => KSpacing.vGapSm,
            itemBuilder: (context, i) =>
                _GeneratedInvoiceCard(invoice: invoices[i]),
          ),
        );
      },
    );
  }
}

class _GeneratedInvoiceCard extends StatelessWidget {
  final Map<String, dynamic> invoice;

  const _GeneratedInvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final id = invoice['invoiceId']?.toString();
    final number = invoice['invoiceNumber'] as String? ?? '—';
    final status = invoice['status'] as String? ?? '';
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final date = invoice['invoiceDate'] as String? ?? '';
    final autoSent = invoice['autoSent'] as bool? ?? false;

    final statusColor = _invoiceStatusColor(status);

    return KCard(
      onTap: id != null ? () => context.push('/invoices/$id') : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.receipt_long, color: statusColor, size: 20),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(number,
                          style: KTypography.labelLarge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: KTypography.labelLarge),
                  ],
                ),
                KSpacing.vGapXs,
                Row(
                  children: [
                    Expanded(
                      child: Text(_formatDate(date),
                          style: KTypography.labelSmall),
                    ),
                    if (autoSent)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: KColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('AUTO-SENT',
                              style: KTypography.labelSmall
                                  .copyWith(color: KColors.info)),
                        ),
                      ),
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

  Color _invoiceStatusColor(String status) {
    return switch (status) {
      'DRAFT' => KColors.textHint,
      'SENT' => KColors.info,
      'PAID' => KColors.success,
      'OVERDUE' => KColors.error,
      'CANCELLED' => KColors.error,
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

class _ActionBar extends ConsumerWidget {
  final String templateId;
  final String status;

  const _ActionBar({required this.templateId, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (status == 'EXPIRED') return const SizedBox.shrink();

    final actions = <Widget>[];

    if (status == 'ACTIVE') {
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _runNow(context, ref),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Run now'),
          ),
        ),
      );
      actions.add(KSpacing.hGapSm);
      actions.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _runStop(context, ref),
            icon: const Icon(Icons.stop_circle_outlined,
                size: 18, color: KColors.error),
            label: const Text('Stop'),
          ),
        ),
      );
    }

    if (status == 'PAUSED' || status == 'STOPPED') {
      actions.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _runResume(context, ref),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Resume'),
          ),
        ),
      );
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            KSpacing.md, KSpacing.sm, KSpacing.md, KSpacing.md),
        child: Row(children: actions),
      ),
    );
  }

  Future<void> _runStop(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop template?'),
        content: const Text(
            'The scheduler will stop generating invoices from this template. '
            'You can resume it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Stop',
                style: TextStyle(color: KColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _invoke(
      context,
      ref,
      label: 'stopped',
      action: (repo) => repo.stopTemplate(templateId),
    );
  }

  Future<void> _runResume(BuildContext context, WidgetRef ref) =>
      _invoke(
        context,
        ref,
        label: 'resumed',
        action: (repo) => repo.resumeTemplate(templateId),
      );

  Future<void> _runNow(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate invoice now?'),
        content: const Text(
            'This creates a new DRAFT invoice from the template and advances '
            'the schedule by one cycle. If auto-send is enabled, it will be '
            'emailed immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final resp = await ref
          .read(recurringInvoiceRepositoryProvider)
          .generateNow(templateId);
      ref.invalidate(recurringInvoiceDetailProvider(templateId));
      ref.invalidate(recurringGeneratedProvider(templateId));
      ref.invalidate(recurringInvoiceListProvider);
      if (!context.mounted) return;
      final invoiceData = resp['data'] as Map<String, dynamic>?;
      final invoiceId = invoiceData?['id']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice generated')),
      );
      if (invoiceId != null) {
        context.push('/invoices/$invoiceId');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate: $e')),
        );
      }
    }
  }

  Future<void> _invoke(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required Future<void> Function(RecurringInvoiceRepository repo) action,
  }) async {
    try {
      await action(ref.read(recurringInvoiceRepositoryProvider));
      ref.invalidate(recurringInvoiceDetailProvider(templateId));
      ref.invalidate(recurringInvoiceListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Template $label')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: KSpacing.sm),
        child: Text(title, style: KTypography.h3),
      );
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _Row(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: KTypography.bodyMedium),
          KSpacing.hGapMd,
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: bold
                  ? KTypography.labelLarge
                  : KTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
