import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/api_error_parser.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../data/bank_rule_repository.dart';

final _bankRulesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) {
  return ref.watch(bankRuleRepositoryProvider).list();
});

const _directionFilters = ['ANY', 'CREDIT', 'DEBIT'];
const _narrationOps = ['ANY', 'CONTAINS', 'EQUALS', 'STARTS_WITH', 'REGEX'];
const _amountOps = ['ANY', 'EQ', 'GT', 'LT', 'GTE', 'LTE'];

/// User-defined bank matching rules (H4). Categorise non-document bank
/// transactions — charges, interest, utilities, salaries — to a GL account so
/// reconciliation can auto-post them instead of leaving them UNMATCHED.
class BankRulesScreen extends ConsumerWidget {
  const BankRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(_bankRulesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bank Rules')),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'New rule (N)',
        onPressed: () => _showRuleDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New rule'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(ApiErrorParser.message(e))),
        data: (rules) {
          if (rules.isEmpty) {
            return _empty(context, ref);
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_bankRulesProvider),
            child: ListView.builder(
              padding: KSpacing.pagePadding,
              itemCount: rules.length,
              itemBuilder: (_, i) {
                final r = rules[i] as Map<String, dynamic>;
                return _RuleCard(
                  rule: r,
                  onEdit: () => _showRuleDialog(context, ref, existing: r),
                  onDelete: () => _confirmDelete(context, ref, r),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rule_folder_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: KSpacing.sm),
          Text('No bank rules yet', style: KTypography.titleSmall),
          const SizedBox(height: KSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: KSpacing.xl),
            child: Text(
              'Rules categorise recurring non-invoice bank lines '
              '(charges, interest, utilities) to a GL account during reconciliation.',
              textAlign: TextAlign.center,
              style: KTypography.bodySmall
                  .copyWith(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          const SizedBox(height: KSpacing.md),
          FilledButton.icon(
            onPressed: () => _showRuleDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add your first rule'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Map<String, dynamic> rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete rule?'),
        content: Text('Remove "${rule['name'] ?? 'rule'}"? '
            'Existing matches are unaffected.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: KColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(bankRuleRepositoryProvider).delete(rule['id'] as String);
      ref.invalidate(_bankRulesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiErrorParser.message(e)),
            backgroundColor: KColors.error));
      }
    }
  }

  Future<void> _showRuleDialog(BuildContext context, WidgetRef ref,
      {Map<String, dynamic>? existing}) async {
    await showDialog(
      context: context,
      builder: (_) => _RuleDialog(ref: ref, existing: existing),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final Map<String, dynamic> rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _RuleCard(
      {required this.rule, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final active = rule['active'] as bool? ?? true;
    final autoApply = rule['autoApply'] as bool? ?? false;
    final accountCode = rule['accountCode'] as String? ?? '';
    final accountName = rule['accountName'] as String? ?? '';
    final priority = (rule['priority'] as num?)?.toInt() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text('$priority',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(rule['name'] as String? ?? '(unnamed)',
                    style: KTypography.titleSmall,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: KSpacing.sm),
            KStatusChip(status: active ? 'ACTIVE' : 'INACTIVE', dense: true),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(_conditionSummary(rule),
                style: KTypography.bodySmall
                    .copyWith(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 2),
            Row(
              children: [
                Text('→ ', style: KTypography.bodySmall),
                Text(accountCode.isEmpty ? '—' : accountCode,
                    style: KTypography.mono(size: 12)),
                if (accountName.isNotEmpty)
                  Expanded(
                    child: Text('  $accountName',
                        overflow: TextOverflow.ellipsis,
                        style: KTypography.bodySmall.copyWith(
                            color: Theme.of(context).colorScheme.outline)),
                  ),
                if (autoApply)
                  const Padding(
                    padding: EdgeInsets.only(left: KSpacing.xs),
                    child: KStatusChip(status: 'AUTO', dense: true),
                  ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: onDelete,
        ),
        isThreeLine: true,
      ),
    );
  }

  String _conditionSummary(Map<String, dynamic> r) {
    final parts = <String>[];
    final dir = r['directionFilter'] as String? ?? 'ANY';
    if (dir != 'ANY') parts.add(dir);
    final nop = r['narrationOp'] as String? ?? 'ANY';
    if (nop != 'ANY') {
      final val = r['narrationValue'] as String? ?? '';
      parts.add('narration ${nop.toLowerCase().replaceAll('_', ' ')} "$val"');
    }
    final aop = r['amountOp'] as String? ?? 'ANY';
    if (aop != 'ANY') {
      final av = r['amountValue']?.toString() ?? '';
      parts.add('amount ${_amountOpSymbol(aop)} $av');
    }
    return parts.isEmpty ? 'Matches any transaction' : parts.join(' · ');
  }

  String _amountOpSymbol(String op) => switch (op) {
        'EQ' => '=',
        'GT' => '>',
        'LT' => '<',
        'GTE' => '≥',
        'LTE' => '≤',
        _ => op,
      };
}

class _RuleDialog extends StatefulWidget {
  final WidgetRef ref;
  final Map<String, dynamic>? existing;
  const _RuleDialog({required this.ref, this.existing});

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late final TextEditingController _name;
  late final TextEditingController _priority;
  late final TextEditingController _narrationValue;
  late final TextEditingController _amountValue;
  late final TextEditingController _accountCode;
  late final TextEditingController _memo;

  late String _directionFilter;
  late String _narrationOp;
  late String _amountOp;
  late bool _active;
  late bool _autoApply;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?['name'] as String? ?? '');
    _priority =
        TextEditingController(text: (e?['priority']?.toString()) ?? '100');
    _narrationValue =
        TextEditingController(text: e?['narrationValue'] as String? ?? '');
    _amountValue =
        TextEditingController(text: e?['amountValue']?.toString() ?? '');
    _accountCode =
        TextEditingController(text: e?['accountCode'] as String? ?? '');
    _memo = TextEditingController(text: e?['memo'] as String? ?? '');
    _directionFilter = e?['directionFilter'] as String? ?? 'ANY';
    _narrationOp = e?['narrationOp'] as String? ?? 'CONTAINS';
    _amountOp = e?['amountOp'] as String? ?? 'ANY';
    _active = e?['active'] as bool? ?? true;
    _autoApply = e?['autoApply'] as bool? ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _priority.dispose();
    _narrationValue.dispose();
    _amountValue.dispose();
    _accountCode.dispose();
    _memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit rule' : 'New bank rule'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Rule name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: KSpacing.sm),
              TextField(
                controller: _priority,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Priority (lower runs first)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: KSpacing.md),
              _dropdown('Direction', _directionFilter, _directionFilters,
                  (v) => setState(() => _directionFilter = v)),
              const SizedBox(height: KSpacing.sm),
              _dropdown('Narration match', _narrationOp, _narrationOps,
                  (v) => setState(() => _narrationOp = v)),
              if (_narrationOp != 'ANY') ...[
                const SizedBox(height: KSpacing.sm),
                TextField(
                  controller: _narrationValue,
                  decoration: InputDecoration(
                      labelText: _narrationOp == 'REGEX'
                          ? 'Narration regex'
                          : 'Narration text',
                      border: const OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: KSpacing.sm),
              _dropdown('Amount match', _amountOp, _amountOps,
                  (v) => setState(() => _amountOp = v)),
              if (_amountOp != 'ANY') ...[
                const SizedBox(height: KSpacing.sm),
                TextField(
                  controller: _amountValue,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount', border: OutlineInputBorder()),
                ),
              ],
              const SizedBox(height: KSpacing.md),
              TextField(
                controller: _accountCode,
                decoration: const InputDecoration(
                    labelText: 'Target GL account code (e.g. 5200)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: KSpacing.sm),
              TextField(
                controller: _memo,
                decoration: const InputDecoration(
                    labelText: 'Memo (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: KSpacing.xs),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Auto-apply on import'),
                subtitle: const Text('Post the journal automatically when a '
                    'referenced transaction matches'),
                value: _autoApply,
                onChanged: (v) => setState(() => _autoApply = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> options,
      ValueChanged<String> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: (v) => onChanged(v ?? value),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'priority': int.tryParse(_priority.text.trim()) ?? 100,
      'active': _active,
      'directionFilter': _directionFilter,
      'narrationOp': _narrationOp,
      'narrationValue':
          _narrationOp == 'ANY' ? null : _narrationValue.text.trim(),
      'amountOp': _amountOp,
      'amountValue': _amountOp == 'ANY'
          ? null
          : double.tryParse(_amountValue.text.trim()),
      'accountCode': _accountCode.text.trim(),
      'memo': _memo.text.trim().isEmpty ? null : _memo.text.trim(),
      'autoApply': _autoApply,
    };
    try {
      final repo = widget.ref.read(bankRuleRepositoryProvider);
      if (widget.existing != null) {
        await repo.update(widget.existing!['id'] as String, body);
      } else {
        await repo.create(body);
      }
      widget.ref.invalidate(_bankRulesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(ApiErrorParser.message(e)),
            backgroundColor: KColors.error));
      }
    }
  }
}
