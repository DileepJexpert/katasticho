import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../procurement/presentation/supplier_picker_sheet.dart';
import '../../recurring_documents/data/recurring_documents_repository.dart';

class RecurringBillsScreen extends ConsumerWidget {
  const RecurringBillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(recurringBillsProvider);

    return Scaffold(
      body: Column(
        children: [
          const KListPageHeader(
            title: 'Recurring Purchase Bills',
          ),
          Expanded(
            child: billsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => KErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(recurringBillsProvider),
              ),
              data: (bills) {
                if (bills.isEmpty) {
                  return const KEmptyState(
                    icon: Icons.repeat_outlined,
                    title: 'No recurring bills',
                    subtitle: 'Automate periodic vendor invoices such as rent, software subscriptions, or retainers.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(recurringBillsProvider),
                  child: ListView.builder(
                    padding: KSpacing.pagePadding,
                    itemCount: bills.length,
                    itemBuilder: (ctx, i) => _RecurringBillCard(
                      bill: bills[i],
                      onGenerateNow: () => _generateNow(ctx, ref, bills[i]['id']?.toString() ?? ''),
                      onStop: () => _stopBill(ctx, ref, bills[i]['id']?.toString() ?? ''),
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
        label: const Text('New Recurring Bill'),
      ),
    );
  }

  Future<void> _generateNow(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(recurringDocumentsRepositoryProvider).generateRecurringBillNow(id);
      ref.invalidate(recurringBillsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill generated successfully'), backgroundColor: KColors.success),
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

  Future<void> _stopBill(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(recurringDocumentsRepositoryProvider).stopRecurringBill(id);
      ref.invalidate(recurringBillsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring bill stopped'), backgroundColor: KColors.success),
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
    Map<String, dynamic>? selectedVendor;
    final notesCtl = TextEditingController();
    final amountCtl = TextEditingController();
    String frequency = 'MONTHLY';
    bool autoPost = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create Recurring Bill Template'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KTextField(
                    label: 'Profile Name *',
                    hint: 'e.g. Monthly Office Rent / Cloud Server',
                    controller: profileNameCtl,
                  ),
                  KSpacing.vGapSm,
                  KCard(
                    onTap: () async {
                      final picked = await showSupplierPicker(ctx);
                      if (picked != null) {
                        setState(() => selectedVendor = picked);
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: KColors.primary, size: 20),
                        KSpacing.hGapSm,
                        Expanded(
                          child: Text(
                            selectedVendor?['name']?.toString() ?? 'Tap to select vendor / supplier *',
                            style: KTypography.bodyMedium.copyWith(
                              color: selectedVendor == null ? KColors.primary : null,
                              fontWeight: selectedVendor != null ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: KColors.textHint),
                      ],
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
                      DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                      DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                      DropdownMenuItem(value: 'QUARTERLY', child: Text('Quarterly')),
                      DropdownMenuItem(value: 'ANNUALLY', child: Text('Annually')),
                    ],
                    onChanged: (v) => setState(() => frequency = v ?? 'MONTHLY'),
                  ),
                  KSpacing.vGapSm,
                  KTextField.amount(
                    label: 'Estimated Amount *',
                    controller: amountCtl,
                  ),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Checkbox(
                        value: autoPost,
                        onChanged: (v) => setState(() => autoPost = v ?? true),
                      ),
                      const Text('Auto-post Bill to Ledger'),
                    ],
                  ),
                  KSpacing.vGapSm,
                  KTextField(
                    label: 'Internal Notes',
                    controller: notesCtl,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            KButton.outlined(
              label: 'Cancel',
              size: KButtonSize.small,
              onPressed: () => Navigator.pop(ctx, false),
            ),
            KSpacing.hGapSm,
            KButton.primary(
              label: 'Create Template',
              size: KButtonSize.small,
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
      'vendorId': selectedVendor?['id']?.toString(),
      'frequency': frequency,
      'startDate': DateTime.now().toIso8601String().split('T')[0],
      'autoPost': autoPost,
      'notes': notesCtl.text.trim().isEmpty ? null : notesCtl.text.trim(),
      'lines': [
        {
          'description': profileNameCtl.text.trim(),
          'quantity': 1,
          'unitPrice': amt,
          'amount': amt,
        }
      ],
    };

    try {
      await ref.read(recurringDocumentsRepositoryProvider).createRecurringBill(payload);
      ref.invalidate(recurringBillsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring bill template created'), backgroundColor: KColors.success),
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

class _RecurringBillCard extends StatelessWidget {
  const _RecurringBillCard({required this.bill, required this.onGenerateNow, required this.onStop});
  final Map<String, dynamic> bill;
  final VoidCallback onGenerateNow;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final profileName = bill['profileName']?.toString() ?? 'Recurring Bill';
    final vendorName = bill['vendorName']?.toString() ?? bill['vendorId']?.toString() ?? 'Vendor';
    final frequency = bill['frequency']?.toString() ?? 'MONTHLY';
    final nextRunDate = bill['nextRunDate']?.toString() ?? '--';
    final status = bill['status']?.toString() ?? 'ACTIVE';
    final totalAmount = (bill['totalAmount'] as num?)?.toDouble() ?? 0;
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
                      Text('Vendor: $vendorName • Frequency: $frequency',
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
                  label: 'Generate Now',
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
