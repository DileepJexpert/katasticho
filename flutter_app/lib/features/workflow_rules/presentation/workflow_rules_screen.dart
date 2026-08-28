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
import '../../../core/widgets/k_status_chip.dart';
import '../data/workflow_rules_repository.dart';

class WorkflowRulesScreen extends ConsumerWidget {
  const WorkflowRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(workflowRulesListProvider);

    return Scaffold(
      body: Column(
        children: [
          const KListPageHeader(
            title: 'Custom Workflow Automation Rules',
          ),
          Expanded(
            child: rulesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => KErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(workflowRulesListProvider),
              ),
              data: (rules) {
                if (rules.isEmpty) {
                  return const KEmptyState(
                    icon: Icons.account_tree_outlined,
                    title: 'No workflow rules configured',
                    subtitle: 'Create event-driven automation rules to trigger webhooks, emails, AI suggestions, or auto field updates.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(workflowRulesListProvider),
                  child: ListView.builder(
                    padding: KSpacing.pagePadding,
                    itemCount: rules.length,
                    itemBuilder: (ctx, i) => _WorkflowRuleCard(
                      rule: rules[i],
                      onToggle: (active) => _toggleRule(ctx, ref, rules[i]['id']?.toString() ?? '', active),
                      onDelete: () => _deleteRule(ctx, ref, rules[i]['id']?.toString() ?? ''),
                      onViewExecutions: () => _viewExecutions(ctx, ref, rules[i]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRuleBuilder(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Workflow Rule'),
      ),
    );
  }

  Future<void> _toggleRule(BuildContext context, WidgetRef ref, String id, bool active) async {
    try {
      await ref.read(workflowRulesRepositoryProvider).toggleWorkflowRule(id, active);
      ref.invalidate(workflowRulesListProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: KColors.error),
        );
      }
    }
  }

  Future<void> _deleteRule(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Workflow Rule'),
        content: const Text('Are you sure you want to delete this automation rule?'),
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
      await ref.read(workflowRulesRepositoryProvider).deleteWorkflowRule(id);
      ref.invalidate(workflowRulesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workflow rule deleted'), backgroundColor: KColors.success),
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

  Future<void> _openRuleBuilder(BuildContext context, WidgetRef ref) async {
    final nameCtl = TextEditingController();
    final descCtl = TextEditingController();
    final actionPayloadCtl = TextEditingController();
    String triggerEvent = 'INVOICE_POSTED';
    String actionType = 'WEBHOOK';
    String fieldKey = 'totalAmount';
    String operator = 'GT';
    final fieldValueCtl = TextEditingController(text: '50000');
    bool active = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Create Workflow Automation Rule'),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtl,
                    decoration: const InputDecoration(
                      labelText: 'Rule Name *',
                      hintText: 'e.g. Notify Slack on Large Invoices > ₹50,000',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  KSpacing.vGapSm,
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  KSpacing.vGapMd,
                  Text('1. Trigger Event', style: KTypography.h4),
                  KSpacing.vGapXs,
                  DropdownButtonFormField<String>(
                    initialValue: triggerEvent,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'INVOICE_POSTED', child: Text('Sales Invoice Posted (INVOICE_POSTED)')),
                      DropdownMenuItem(value: 'BILL_POSTED', child: Text('Purchase Bill Posted (BILL_POSTED)')),
                      DropdownMenuItem(value: 'PAYMENT_RECORDED', child: Text('Customer Payment Received (PAYMENT_RECORDED)')),
                      DropdownMenuItem(value: 'STOCK_MOVEMENT_RECORDED', child: Text('Stock Movement Dispatched/Received')),
                    ],
                    onChanged: (v) => setState(() => triggerEvent = v ?? 'INVOICE_POSTED'),
                  ),
                  KSpacing.vGapMd,
                  Text('2. Criteria Filter', style: KTypography.h4),
                  KSpacing.vGapXs,
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: fieldKey,
                          decoration: const InputDecoration(labelText: 'Field', border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'totalAmount', child: Text('Total Amount')),
                            DropdownMenuItem(value: 'balanceDue', child: Text('Balance Due')),
                            DropdownMenuItem(value: 'customerType', child: Text('Customer Type')),
                            DropdownMenuItem(value: 'paymentMode', child: Text('Payment Mode')),
                          ],
                          onChanged: (v) => setState(() => fieldKey = v ?? 'totalAmount'),
                        ),
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          initialValue: operator,
                          decoration: const InputDecoration(labelText: 'Condition', border: OutlineInputBorder(), isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'GT', child: Text('> (Greater Than)')),
                            DropdownMenuItem(value: 'GTE', child: Text('>= (At least)')),
                            DropdownMenuItem(value: 'LT', child: Text('< (Less Than)')),
                            DropdownMenuItem(value: 'EQ', child: Text('== (Equals)')),
                            DropdownMenuItem(value: 'CONTAINS', child: Text('Contains')),
                          ],
                          onChanged: (v) => setState(() => operator = v ?? 'GT'),
                        ),
                      ),
                      KSpacing.hGapSm,
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: fieldValueCtl,
                          decoration: const InputDecoration(labelText: 'Value', border: OutlineInputBorder(), isDense: true),
                        ),
                      ),
                    ],
                  ),
                  KSpacing.vGapMd,
                  Text('3. Action to Execute', style: KTypography.h4),
                  KSpacing.vGapXs,
                  DropdownButtonFormField<String>(
                    initialValue: actionType,
                    decoration: const InputDecoration(labelText: 'Action Type', border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'WEBHOOK', child: Text('Send Webhook HTTP POST')),
                      DropdownMenuItem(value: 'EMAIL', child: Text('Send Email Notification')),
                      DropdownMenuItem(value: 'AI_SUGGESTION', child: Text('Draft AI Optimization Suggestion')),
                      DropdownMenuItem(value: 'FIELD_UPDATE', child: Text('Update Entity Field')),
                    ],
                    onChanged: (v) => setState(() => actionType = v ?? 'WEBHOOK'),
                  ),
                  KSpacing.vGapSm,
                  TextField(
                    controller: actionPayloadCtl,
                    decoration: InputDecoration(
                      labelText: actionType == 'WEBHOOK'
                          ? 'Webhook URL *'
                          : (actionType == 'EMAIL' ? 'Recipient Email / Template' : 'Action Parameter Payload'),
                      hintText: actionType == 'WEBHOOK'
                          ? 'https://hooks.slack.com/services/...'
                          : 'finance@company.com',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  KSpacing.vGapSm,
                  Row(
                    children: [
                      Checkbox(
                        value: active,
                        onChanged: (v) => setState(() => active = v ?? true),
                      ),
                      const Text('Activate rule immediately'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            KButton(
              label: 'Save Rule',
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
      'triggerEvent': triggerEvent,
      'active': active,
      'criteria': [
        {
          'field': fieldKey,
          'operator': operator,
          'value': fieldValueCtl.text.trim(),
        }
      ],
      'actionType': actionType,
      'actionConfig': {
        'target': actionPayloadCtl.text.trim(),
      },
    };

    try {
      await ref.read(workflowRulesRepositoryProvider).createWorkflowRule(payload);
      ref.invalidate(workflowRulesListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workflow rule created successfully'), backgroundColor: KColors.success),
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

  void _viewExecutions(BuildContext context, WidgetRef ref, Map<String, dynamic> rule) {
    final ruleId = rule['id']?.toString() ?? '';
    final ruleName = rule['name']?.toString() ?? 'Rule';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: 480,
        child: Padding(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Execution History: $ruleName', style: KTypography.h4),
              KSpacing.vGapSm,
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: ref.read(workflowRulesRepositoryProvider).getExecutions(ruleId),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return KErrorView(message: snap.error.toString());
                    }
                    final list = snap.data ?? [];
                    if (list.isEmpty) {
                      return const Center(child: Text('No trigger executions recorded yet.'));
                    }
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (ctx, i) {
                        final exec = list[i];
                        final outcome = exec['outcome']?.toString() ?? 'SUCCESS';
                        final time = exec['executedAt']?.toString() ?? '';
                        return ListTile(
                          leading: Icon(
                            outcome == 'SUCCESS' ? Icons.check_circle : Icons.error,
                            color: outcome == 'SUCCESS' ? KColors.success : KColors.error,
                          ),
                          title: Text('Triggered by Entity: ${exec['entityId'] ?? 'Event'}'),
                          subtitle: Text('At $time • Outcome: $outcome'),
                          trailing: KStatusChip(status: outcome),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkflowRuleCard extends StatelessWidget {
  const _WorkflowRuleCard({
    required this.rule,
    required this.onToggle,
    required this.onDelete,
    required this.onViewExecutions,
  });

  final Map<String, dynamic> rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onViewExecutions;

  @override
  Widget build(BuildContext context) {
    final name = rule['name']?.toString() ?? 'Workflow Rule';
    final desc = rule['description']?.toString();
    final triggerEvent = rule['triggerEvent']?.toString() ?? 'EVENT';
    final actionType = rule['actionType']?.toString() ?? 'ACTION';
    final active = rule['active'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: KSpacing.sm),
      child: KCard(
        statusAccent: active ? KColors.primary : KColors.textHint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: KTypography.h4.copyWith(fontWeight: FontWeight.w600)),
                      if (desc != null && desc.isNotEmpty) ...[
                        KSpacing.vGapXxs,
                        Text(desc, style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
                Switch(
                  value: active,
                  activeThumbColor: KColors.primary,
                  onChanged: onToggle,
                ),
              ],
            ),
            KSpacing.vGapSm,
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: KColors.infoLight,
                    borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                  ),
                  child: Text('On: $triggerEvent', style: KTypography.bodySmall.copyWith(color: KColors.info, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: KColors.primarySoft,
                    borderRadius: BorderRadius.circular(KSpacing.radiusSm),
                  ),
                  child: Text('Action: $actionType', style: KTypography.bodySmall.copyWith(color: KColors.brandSeed, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            KSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                KButton(
                  label: 'Execution History',
                  icon: Icons.history,
                  variant: KButtonVariant.outlined,
                  size: KButtonSize.small,
                  onPressed: onViewExecutions,
                ),
                KSpacing.hGapSm,
                KButton(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  variant: KButtonVariant.outlined,
                  size: KButtonSize.small,
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
