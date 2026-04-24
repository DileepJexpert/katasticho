import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../data/journal_repository.dart';

class JournalDetailScreen extends ConsumerWidget {
  final String journalId;

  const JournalDetailScreen({super.key, required this.journalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalAsync = ref.watch(journalDetailProvider(journalId));

    return Scaffold(
      appBar: AppBar(
        title: journalAsync.whenOrNull(
              data: (data) {
                final je = (data['data'] ?? data) as Map<String, dynamic>;
                return Text(je['entryNumber']?.toString() ?? 'Journal Entry');
              },
            ) ??
            const Text('Journal Entry'),
        actions: [
          journalAsync.whenOrNull(
                data: (data) {
                  final je = (data['data'] ?? data) as Map<String, dynamic>;
                  final sourceModule =
                      je['sourceModule']?.toString() ?? '';
                  if (sourceModule == 'MANUAL') {
                    return IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: KColors.error,
                      tooltip: 'Delete',
                      onPressed: () =>
                          _showDeleteConfirmation(context, ref),
                    );
                  }
                  return null;
                },
              ) ??
              const SizedBox.shrink(),
        ],
      ),
      body: journalAsync.when(
        loading: () => const KLoading(message: 'Loading journal entry...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load journal entry',
          onRetry: () => ref.invalidate(journalDetailProvider(journalId)),
        ),
        data: (data) {
          final je = (data['data'] ?? data) as Map<String, dynamic>;
          return _JournalDetailBody(journal: je);
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Journal Entry?'),
        content: const Text(
          'This will permanently delete this manual journal entry. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(journalRepositoryProvider);
                await repo.deleteJournal(journalId);
                ref.invalidate(journalListProvider);
                if (context.mounted) {
                  context.go('/accounting/journal-entries');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Journal entry deleted')),
                  );
                }
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Failed to delete journal entry')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _JournalDetailBody extends StatelessWidget {
  final Map<String, dynamic> journal;

  const _JournalDetailBody({required this.journal});

  @override
  Widget build(BuildContext context) {
    final entryNumber = journal['entryNumber']?.toString() ?? '';
    final description = journal['description']?.toString() ?? '';
    final effectiveDate = journal['effectiveDate']?.toString() ?? '';
    final sourceModule = journal['sourceModule']?.toString() ?? '';
    final sourceId = journal['sourceId']?.toString() ?? '';
    final status = journal['status']?.toString() ?? '';
    final isReversal = journal['isReversal'] as bool? ?? false;
    final isReversed = journal['isReversed'] as bool? ?? false;
    final periodYear =
        (journal['periodYear'] as num?)?.toInt();
    final periodMonth =
        (journal['periodMonth'] as num?)?.toInt();
    final totalDebit =
        (journal['totalDebit'] as num?)?.toDouble() ?? 0.0;
    final lines =
        (journal['lines'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Calculate total credit from lines
    double totalCredit = 0;
    for (final line in lines) {
      totalCredit += (line['credit'] as num?)?.toDouble() ?? 0.0;
    }

    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: KSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          KCard(
            child: Column(
              children: [
                KDetailRow(
                  label: 'Entry Number',
                  value: entryNumber,
                  valueStyle: KTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                KDetailRow(
                  label: 'Effective Date',
                  value: effectiveDate.isNotEmpty
                      ? DateFormatter.display(DateTime.parse(effectiveDate))
                      : '--',
                ),
                KDetailRow(
                  label: 'Description',
                  value: description.isEmpty ? '--' : description,
                ),
                KDetailRow(
                  label: 'Source',
                  value: _sourceLabel(sourceModule),
                ),
                KDetailRow(
                  label: 'Status',
                  value: '',
                  trailing: KStatusChip(status: status),
                ),
                if (periodYear != null && periodMonth != null)
                  KDetailRow(
                    label: 'Period',
                    value: '$periodMonth / $periodYear',
                  ),
                if (isReversal)
                  const KDetailRow(
                    label: 'Reversal',
                    value: 'Yes — this entry reverses another',
                  ),
                if (isReversed)
                  const KDetailRow(
                    label: 'Reversed',
                    value: 'Yes — this entry has been reversed',
                  ),
              ],
            ),
          ),

          // Source navigation button
          if (sourceModule != 'MANUAL' && sourceId.isNotEmpty) ...[
            KSpacing.vGapMd,
            _SourceNavigationButton(
              sourceModule: sourceModule,
              sourceId: sourceId,
            ),
          ],

          // Line items
          KSpacing.vGapMd,
          Text('Line Items', style: KTypography.h3.copyWith(color: cs.onSurface)),
          KSpacing.vGapSm,

          // Table header
          KCard(
            padding: const EdgeInsets.symmetric(
              horizontal: KSpacing.md,
              vertical: KSpacing.sm,
            ),
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Account',
                      style: KTypography.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Debit',
                      textAlign: TextAlign.right,
                      style: KTypography.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Credit',
                      textAlign: TextAlign.right,
                      style: KTypography.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),

          // Line rows
          ...lines.map((line) => _LineRow(line: line)),

          // Totals footer
          KSpacing.vGapSm,
          KCard(
            borderColor: cs.primary.withValues(alpha: 0.3),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Total',
                      style: KTypography.labelLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      )),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    CurrencyFormatter.formatIndian(totalDebit),
                    textAlign: TextAlign.right,
                    style: KTypography.amountSmall.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    CurrencyFormatter.formatIndian(totalCredit),
                    textAlign: TextAlign.right,
                    style: KTypography.amountSmall.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          KSpacing.vGapXl,
        ],
      ),
    );
  }

  String _sourceLabel(String sourceModule) {
    return switch (sourceModule.toUpperCase()) {
      'MANUAL' => 'Manual Entry',
      'SALES' => 'Invoice (Auto)',
      'PURCHASE' => 'Bill (Auto)',
      'POS' => 'POS Receipt (Auto)',
      'PAYMENT' => 'Payment (Auto)',
      'EXPENSE' => 'Expense (Auto)',
      _ => sourceModule,
    };
  }
}

class _LineRow extends StatelessWidget {
  final Map<String, dynamic> line;

  const _LineRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final accountCode = line['accountCode']?.toString() ?? '';
    final accountName = line['accountName']?.toString() ?? '';
    final lineDescription = line['description']?.toString() ?? '';
    final debit = (line['debit'] as num?)?.toDouble() ?? 0.0;
    final credit = (line['credit'] as num?)?.toDouble() ?? 0.0;

    final cs = Theme.of(context).colorScheme;

    return KCard(
      margin: const EdgeInsets.only(top: 1),
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.sm + 2,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$accountCode — $accountName',
                  style: KTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
                if (lineDescription.isNotEmpty)
                  Text(
                    lineDescription,
                    style: KTypography.bodySmall.copyWith(
                      color: KColors.textHint,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              debit > 0 ? CurrencyFormatter.formatIndian(debit) : '--',
              textAlign: TextAlign.right,
              style: KTypography.amountSmall.copyWith(
                color: debit > 0 ? cs.onSurface : KColors.textHint,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              credit > 0 ? CurrencyFormatter.formatIndian(credit) : '--',
              textAlign: TextAlign.right,
              style: KTypography.amountSmall.copyWith(
                color: credit > 0 ? cs.onSurface : KColors.textHint,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceNavigationButton extends StatelessWidget {
  final String sourceModule;
  final String sourceId;

  const _SourceNavigationButton({
    required this.sourceModule,
    required this.sourceId,
  });

  @override
  Widget build(BuildContext context) {
    final (label, icon, route) = switch (sourceModule.toUpperCase()) {
      'SALES' => (
          'View Invoice',
          Icons.receipt_long_outlined,
          '/invoices/$sourceId',
        ),
      'PURCHASE' => (
          'View Bill',
          Icons.receipt_outlined,
          '/bills/$sourceId',
        ),
      'POS' => (
          'View Sales Receipt',
          Icons.point_of_sale_outlined,
          '/sales-receipts/$sourceId',
        ),
      _ => (null, null, null),
    };

    if (label == null || route == null) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: KButton(
        label: label,
        icon: icon,
        variant: KButtonVariant.outlined,
        onPressed: () => context.push(route),
      ),
    );
  }
}
