import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_list_page_header.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../recurring_documents/data/recurring_documents_repository.dart';

class RecurringJournalsScreen extends ConsumerWidget {
  const RecurringJournalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalsAsync = ref.watch(recurringJournalsProvider);

    return Scaffold(
      body: Column(
        children: [
          const KListPageHeader(
            title: 'Recurring Journal Templates',
          ),
          Expanded(
            child: journalsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => KErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(recurringJournalsProvider),
              ),
              data: (journals) {
                if (journals.isEmpty) {
                  return const KEmptyState(
                    icon: Icons.auto_stories_outlined,
                    title: 'No recurring journals',
                    subtitle: 'Automate periodic accounting adjustments like monthly depreciation, salary provisions, or prepaid amortizations.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(recurringJournalsProvider),
                  child: ListView.builder(
                    padding: KSpacing.pagePadding,
                    itemCount: journals.length,
                    itemBuilder: (ctx, i) => _RecurringJournalCard(
                      journal: journals[i],
                      onGenerateNow: () => _generateNow(ctx, ref, journals[i]['id']?.toString() ?? ''),
                      onStop: () => _stopJournal(ctx, ref, journals[i]['id']?.toString() ?? ''),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Recurring Journal'),
      ),
    );
  }

  Future<void> _generateNow(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(recurringDocumentsRepositoryProvider).generateRecurringJournalNow(id);
      ref.invalidate(recurringJournalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry posted successfully'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<void> _stopJournal(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(recurringDocumentsRepositoryProvider).stopRecurringJournal(id);
      ref.invalidate(recurringJournalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring journal template stopped'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    final profileNameCtl = TextEditingController();
    final narrationCtl = TextEditingController();
    final debitAcctCtl = TextEditingController();
    final creditAcctCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String frequency = 'MONTHLY';
    bool autoPost = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create Recurring Journal Template'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: profileNameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Template Name *',
                      hintText: 'e.g. Monthly Asset Depreciation / Rent Accrual',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  KSpacing.vGapSm,
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: const InputDecoration(
                      labelText: 'Repeat Frequency',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                      DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
                      DropdownMenuItem(value: 'ANNUALLY', child: Text('Annually')),
                    ],
                    onChanged: (v) => setState(() => frequency = v ?? 'MONTHLY'),
                  ),
                  KSpacing.vGapSm,
                  TextField(
                    controller: amountCtl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Journal Amount (₹) *',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  KSpacing.vGapSm,
                  TextField(
                    controller: debitAcctCtl,
                    decoration: const InputDecoration(
                      labelText: 'Debit Account ID / Code *',
                      hintText: 'UUID of expense or asset account',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  KSpacing.vGapSm,
                  TextField(
                    controller: creditAcctCtl,
                    decoration: const InputDecoration(
                      labelText: 'Credit Account ID / Code *',
                      hintText: 'UUID of liability or accumulated depreciation account',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Checkbox(
                        value: autoPost,
                        onChanged: (v) => setState(() => autoPost = v ?? true),
                      ),
                      const Text('Auto-post directly to General Ledger'),
                    ],
                  ),
                  KSpacing.vGapSm,
                  TextField(
                    controller: narrationCtl,
                    decoration: const InputDecoration(
                      labelText: 'Default Narration',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            KButton(
              label: 'Save Template',
              variant: KButtonVariant.primary,
              onPressed: () {
                if (profileNameCtl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
      ),
    );

    if (result != true || !context.mounted) return;

    final amt = double.tryParse(amountCtl.text.trim()) ?? 0;
    final payload = {
      'profileName': profileNameCtl.text.trim(),
      'frequency': frequency,
      'startDate': DateTime.now().toIso8601String().split('T')[0],
      'autoPost': autoPost,
      'narration': narrationCtl.text.trim().isEmpty ? null : narrationCtl.text.trim(),
      'lines': [
        {
          'accountId': debitAcctCtl.text.trim(),
          'debitAmount': amt,
          'creditAmount': 0.0,
          'narration': profileNameCtl.text.trim(),
        },
        {
          'accountId': creditAcctCtl.text.trim(),
          'debitAmount': 0.0,
          'creditAmount': amt,
          'narration': profileNameCtl.text.trim(),
        }
      ],
    };

    try {
      await ref.read(recurringDocumentsRepositoryProvider).createRecurringJournal(payload);
      ref.invalidate(recurringJournalsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring journal template created'), backgroundColor: KColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }
}

class _RecurringJournalCard extends StatelessWidget {
  const _RecurringJournalCard({required this.journal, required this.onGenerateNow, required this.onStop});
  final Map<String, dynamic> journal;
  final VoidCallback onGenerateNow;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final profileName = journal['profileName']?.toString() ?? 'Recurring Journal';
    final frequency = journal['frequency']?.toString() ?? 'MONTHLY';
    final nextRunDate = journal['nextRunDate']?.toString() ?? '--';
    final status = journal['status']?.toString() ?? 'ACTIVE';
    final totalAmount = (journal['totalAmount'] as num?)?.toDouble() ?? 0;
    final autoPost = journal['autoPost'] == true;
    final isActive = status == 'ACTIVE';

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        statusAccent: KColors.statusColor(status),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profileName, style: KTypography.h4.copyWith(fontWeight: FontWeight.w600)),
                      KSpacing.vGapXxs,
                      Text('Frequency: $frequency • Mode: ${autoPost ? 'Auto-Post' : 'Draft Entry'}',
                          style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                    ],
                  ),
                ),
                KStatusChip(status: status),
              ],
            ),
            KSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Next Schedule: ', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                    Text(nextRunDate, style: KTypography.mono(weight: FontWeight.w600)),
                  ],
                ),
                KMoney(
                  totalAmount,
                  size: KMoneySize.small,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: KColors.primary),
                ),
              ],
            ),
            KSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isActive) ...[
                  KButton(
                    label: 'Stop Template',
                    icon: Icons.stop_circle_outlined,
                    variant: KButtonVariant.outlined,
                    size: KButtonSize.small,
                    onPressed: onStop,
                  ),
                  KSpacing.hGapSm,
                ],
                KButton(
                  label: 'Post Entry Now',
                  icon: Icons.play_arrow_outlined,
                  variant: KButtonVariant.primary,
                  size: KButtonSize.small,
                  onPressed: onGenerateNow,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
