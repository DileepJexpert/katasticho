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
import '../data/payment_terms_repository.dart';

class PaymentTermsScreen extends ConsumerWidget {
  const PaymentTermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const KListPageHeader(
              title: 'Payment Terms & Dunning Automation',
            ),
            TabBar(
              tabs: const [
                Tab(text: 'Payment Terms (Instalments)'),
                Tab(text: 'Dunning Rules & Reminder Logs'),
              ],
              labelColor: KColors.primary,
              indicatorColor: KColors.primary,
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _PaymentTermsTab(),
                  _DunningRulesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTermsTab extends ConsumerWidget {
  const _PaymentTermsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(paymentTermsListProvider);

    return Scaffold(
      body: termsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(paymentTermsListProvider),
        ),
        data: (terms) {
          if (terms.isEmpty) {
            return const KEmptyState(
              icon: Icons.schedule_outlined,
              title: 'No payment terms configured',
              subtitle: 'Create instalment schedules (e.g. 30% Advance, 70% Net 30) for your customer invoices.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(paymentTermsListProvider),
            child: ListView.builder(
              padding: KSpacing.pagePadding,
              itemCount: terms.length,
              itemBuilder: (ctx, i) => _PaymentTermCard(
                term: terms[i],
                onEdit: () => _openTermDialog(ctx, ref, initial: terms[i]),
                onDelete: () => _deleteTerm(ctx, ref, terms[i]['id']?.toString() ?? ''),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTermDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Payment Term'),
      ),
    );
  }

  Future<void> _openTermDialog(BuildContext context, WidgetRef ref, {Map<String, dynamic>? initial}) async {
    final isEdit = initial != null;
    final nameCtl = TextEditingController(text: initial?['name']?.toString() ?? '');
    final descCtl = TextEditingController(text: initial?['description']?.toString() ?? '');
    bool isDefault = initial?['isDefault'] == true;
    bool active = initial?['active'] != false;

    List<Map<String, dynamic>> lines = [];
    if (initial != null && initial['lines'] is List) {
      lines = (initial['lines'] as List)
          .map((l) => {
                'seq': l['seq'] ?? 1,
                'valueType': l['valueType']?.toString() ?? 'PERCENT',
                'value': (l['value'] as num?)?.toDouble() ?? 100,
                'daysOffset': (l['daysOffset'] as num?)?.toInt() ?? 0,
              })
          .toList();
    } else {
      lines = [
        {'seq': 1, 'valueType': 'PERCENT', 'value': 100.0, 'daysOffset': 30},
      ];
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Payment Term' : 'New Payment Term'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Term Name *',
                      hintText: 'e.g. 30% Advance, 70% Net 30',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  KSpacing.vGapSm,
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Optional notes for sales quotes & invoices',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Checkbox(
                        value: isDefault,
                        onChanged: (v) => setDialogState(() => isDefault = v ?? false),
                      ),
                      const Text('Set as Default Term for Invoices'),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: active,
                        onChanged: (v) => setDialogState(() => active = v ?? true),
                      ),
                      const Text('Active'),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Instalment Schedule Lines', style: KTypography.h4),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Line'),
                        onPressed: () {
                          setDialogState(() {
                            lines.add({
                              'seq': lines.length + 1,
                              'valueType': 'PERCENT',
                              'value': 0.0,
                              'daysOffset': 30,
                            });
                          });
                        },
                      ),
                    ],
                  ),
                  KSpacing.vGapXs,
                  ...lines.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final line = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text('#${idx + 1}', style: KTypography.mono(weight: FontWeight.bold)),
                          KSpacing.hGapSm,
                          DropdownButton<String>(
                            value: line['valueType'],
                            items: const [
                              DropdownMenuItem(value: 'PERCENT', child: Text('% Percent')),
                              DropdownMenuItem(value: 'BALANCE', child: Text('Balance')),
                            ],
                            onChanged: (v) {
                              setDialogState(() => line['valueType'] = v ?? 'PERCENT');
                            },
                          ),
                          KSpacing.hGapSm,
                          if (line['valueType'] == 'PERCENT')
                            SizedBox(
                              width: 80,
                              child: TextFormField(
                                initialValue: '${line['value']}',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '%',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) => line['value'] = double.tryParse(v) ?? 0,
                              ),
                            ),
                          KSpacing.hGapSm,
                          Expanded(
                            child: TextFormField(
                              initialValue: '${line['daysOffset']}',
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Due in (Days)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (v) => line['daysOffset'] = int.tryParse(v) ?? 0,
                            ),
                          ),
                          if (lines.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: KColors.error),
                              onPressed: () {
                                setDialogState(() => lines.removeAt(idx));
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            KButton(
              label: isEdit ? 'Update Term' : 'Create Term',
              variant: KButtonVariant.primary,
              onPressed: () {
                if (nameCtl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
            ),
          ],
        ),
      ),
    );

    if (result != true || !context.mounted) return;

    final payload = {
      'name': nameCtl.text.trim(),
      'description': descCtl.text.trim().isEmpty ? null : descCtl.text.trim(),
      'isDefault': isDefault,
      'active': active,
      'lines': lines.asMap().entries.map((e) => {
            'seq': e.key + 1,
            'valueType': e.value['valueType'],
            'value': e.value['valueType'] == 'PERCENT' ? e.value['value'] : null,
            'daysOffset': e.value['daysOffset'],
          }).toList(),
    };

    try {
      final repo = ref.read(paymentTermsRepositoryProvider);
      if (isEdit) {
        await repo.updatePaymentTerm(initial['id'].toString(), payload);
      } else {
        await repo.createPaymentTerm(payload);
      }
      ref.invalidate(paymentTermsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Payment term updated' : 'Payment term created'),
            backgroundColor: KColors.success,
          ),
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

  Future<void> _deleteTerm(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment Term'),
        content: const Text('Are you sure you want to delete this payment term?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          KButton(
            label: 'Delete',
            variant: KButtonVariant.danger,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      await ref.read(paymentTermsRepositoryProvider).deletePaymentTerm(id);
      ref.invalidate(paymentTermsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment term deleted'), backgroundColor: KColors.success),
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

class _PaymentTermCard extends StatelessWidget {
  const _PaymentTermCard({required this.term, required this.onEdit, required this.onDelete});
  final Map<String, dynamic> term;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final name = term['name']?.toString() ?? 'Unnamed';
    final desc = term['description']?.toString();
    final isDefault = term['isDefault'] == true;
    final active = term['active'] != false;
    final lines = (term['lines'] as List?)
            ?.whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList() ??
        [];

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        statusAccent: active ? (isDefault ? KColors.primary : KColors.success) : KColors.textHint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(name, style: KTypography.h4.copyWith(fontWeight: FontWeight.w600)),
                      if (isDefault) ...[
                        KSpacing.hGapSm,
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: KColors.primarySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('DEFAULT', style: KTypography.labelSmall.copyWith(color: KColors.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                ),
                KStatusChip(status: active ? 'ACTIVE' : 'INACTIVE'),
              ],
            ),
            if (desc != null && desc.isNotEmpty) ...[
              KSpacing.vGapXxs,
              Text(desc, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
            ],
            KSpacing.vGapSm,
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: lines.map((l) {
                final type = l['valueType']?.toString() ?? 'PERCENT';
                final val = l['value'];
                final days = l['daysOffset'] ?? 0;
                final text = type == 'BALANCE' ? 'Balance on Day $days' : '$val% on Day $days';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: KColors.bgApp,
                    borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                    border: Border.all(color: KColors.divider),
                  ),
                  child: Text(text, style: KTypography.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                );
              }).toList(),
            ),
            KSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KButton(
                  label: 'Edit',
                  icon: Icons.edit_outlined,
                  size: KButtonSize.small,
                  variant: KButtonVariant.outlined,
                  onPressed: onEdit,
                ),
                KSpacing.hGapSm,
                KButton(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  size: KButtonSize.small,
                  variant: KButtonVariant.outlined,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DunningRulesTab extends ConsumerWidget {
  const _DunningRulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelsAsync = ref.watch(dunningLevelsProvider);
    final previewAsync = ref.watch(dunningPreviewProvider);

    return Scaffold(
      body: ListView(
        padding: KSpacing.pagePadding,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Escalation Dunning Levels', style: KTypography.h4),
              Row(
                children: [
                  KButton(
                    label: 'Run Dunning Sweep Now',
                    icon: Icons.play_arrow_outlined,
                    variant: KButtonVariant.primary,
                    size: KButtonSize.small,
                    onPressed: () => _runSweep(context, ref),
                  ),
                ],
              ),
            ],
          ),
          KSpacing.vGapSm,
          levelsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => KErrorView(message: e.toString()),
            data: (levels) {
              if (levels.isEmpty) {
                return const KCard(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No dunning levels configured. Create levels to automate overdue reminder notices.'),
                  ),
                );
              }
              return Column(
                children: levels.map((lvl) {
                  final name = lvl['name']?.toString() ?? 'Level';
                  final days = lvl['daysOverdue'] ?? 0;
                  final channel = lvl['channel']?.toString() ?? 'EMAIL';
                  final active = lvl['active'] != false;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: KCard(
                      statusAccent: active ? KColors.warning : KColors.textHint,
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: KColors.warningLight,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text('${lvl['seq'] ?? 1}', style: KTypography.mono(weight: FontWeight.bold, color: KColors.warning)),
                            ),
                          ),
                          KSpacing.hGapMd,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: KTypography.h4.copyWith(fontWeight: FontWeight.w600)),
                                Text('Triggers at $days days overdue • Channel: $channel',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                              ],
                            ),
                          ),
                          KStatusChip(status: active ? 'ACTIVE' : 'INACTIVE'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          KSpacing.vGapLg,

          // Live Preview Candidates
          Text('Overdue Invoices Qualifying for Dunning Notice', style: KTypography.h4),
          KSpacing.vGapSm,
          previewAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => KErrorView(message: e.toString()),
            data: (candidates) {
              if (candidates.isEmpty) {
                return const KCard(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No overdue invoices currently pending dunning notices.'),
                  ),
                );
              }
              return Column(
                children: candidates.map((c) {
                  final invNo = c['invoiceNumber']?.toString() ?? 'INV';
                  final days = c['daysOverdue'] ?? 0;
                  final amt = (c['amount'] as num?)?.toDouble() ?? 0;
                  final lvl = c['levelName']?.toString() ?? 'Level';
                  final channel = c['channel']?.toString() ?? 'EMAIL';
                  final alreadySent = c['alreadySent'] == true;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: KCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(invNo, style: KTypography.mono(weight: FontWeight.bold)),
                                Text('$days days overdue • Target Level: $lvl ($channel)',
                                    style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                              ],
                            ),
                          ),
                          KMoney(amt, size: KMoneySize.small, style: const TextStyle(fontWeight: FontWeight.w700)),
                          KSpacing.hGapSm,
                          KStatusChip(status: alreadySent ? 'SENT' : 'PENDING'),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _runSweep(BuildContext context, WidgetRef ref) async {
    try {
      final res = await ref.read(paymentTermsRepositoryProvider).runDunningSweep();
      ref.invalidate(dunningPreviewProvider);
      if (context.mounted) {
        final sent = res['sent'] ?? 0;
        final skipped = res['skipped'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dunning sweep complete: $sent sent, $skipped skipped'),
            backgroundColor: KColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sweep failed: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }
}
