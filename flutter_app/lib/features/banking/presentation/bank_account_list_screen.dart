import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/bank_account_repository.dart';

const _accountTypes = ['SAVINGS', 'CURRENT', 'OD', 'CC', 'OTHER'];

/// Bank-account master: a business's bank accounts, each posting to its own GL
/// ledger under Bank (1020). Distinct from the reconciliation screen.
class BankAccountListScreen extends ConsumerWidget {
  const BankAccountListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(bankAccountListProvider(false));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Accounts'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(bankAccountListProvider(false)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add bank account'),
        tooltip: 'Add bank account (N)',
      ),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => KErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(bankAccountListProvider(false)),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return KEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No bank accounts yet',
              subtitle:
                  'Add your HDFC / SBI / OD accounts — each gets its own ledger '
                  'so cash and reconciliation stay separated.',
              actionLabel: 'Add bank account',
              onAction: () => _openForm(context, ref, null),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(bankAccountListProvider(false)),
            child: ListView.separated(
              padding: const EdgeInsets.all(KSpacing.md),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: KSpacing.sm),
              itemBuilder: (_, i) => _card(context, ref, rows[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, Map<String, dynamic> a) {
    final isDefault = a['isDefault'] == true;
    final isActive = a['isActive'] == true;
    final acctNo = (a['accountNumber'] ?? '') as String;
    final glCode = (a['glAccountCode'] ?? '') as String;
    final ifsc = (a['ifsc'] ?? '') as String;
    return KCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(a['name']?.toString() ?? '—',
                        style: KTypography.labelLarge,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: KSpacing.sm),
                  if (isDefault) const KStatusChip(status: 'DEFAULT'),
                  if (!isActive) ...[
                    const SizedBox(width: 4),
                    const KStatusChip(status: 'INACTIVE'),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(
                  '${a['bankName'] ?? ''}'
                  '${a['accountType'] != null ? ' · ${a['accountType']}' : ''}',
                  style: KTypography.bodyMedium
                      .copyWith(color: KColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Wrap(spacing: KSpacing.md, runSpacing: 2, children: [
                  if (acctNo.isNotEmpty)
                    Text('A/c $acctNo',
                        style: KTypography.mono(
                            size: 12, color: KColors.textSecondary)),
                  if (ifsc.isNotEmpty)
                    Text(ifsc,
                        style: KTypography.mono(
                            size: 12, color: KColors.textSecondary)),
                  if (glCode.isNotEmpty)
                    Text('GL $glCode',
                        style: KTypography.mono(
                            size: 12, color: KColors.textHint)),
                ]),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => _onAction(context, ref, a, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              if (!isDefault)
                const PopupMenuItem(
                    value: 'default', child: Text('Set as default')),
              const PopupMenuItem(value: 'delete', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref,
      Map<String, dynamic> a, String action) async {
    final repo = ref.read(bankAccountRepositoryProvider);
    final id = a['id'] as String;
    try {
      switch (action) {
        case 'edit':
          await _openForm(context, ref, a);
          return;
        case 'default':
          await repo.setDefault(id);
          break;
        case 'delete':
          final ok = await _confirmRemove(context, a['name']?.toString() ?? '');
          if (ok != true) return;
          await repo.delete(id);
          break;
      }
      ref.invalidate(bankAccountListProvider(false));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<bool?> _confirmRemove(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove bank account?'),
        content: Text('"$name" will be hidden. Its GL ledger is kept.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: KColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      Map<String, dynamic>? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BankAccountFormSheet(existing: existing),
    );
    if (saved == true) ref.invalidate(bankAccountListProvider(false));
  }
}

class _BankAccountFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  const _BankAccountFormSheet({this.existing});

  @override
  ConsumerState<_BankAccountFormSheet> createState() =>
      _BankAccountFormSheetState();
}

class _BankAccountFormSheetState extends ConsumerState<_BankAccountFormSheet> {
  final _name = TextEditingController();
  final _bankName = TextEditingController();
  final _accountNumber = TextEditingController();
  final _ifsc = TextEditingController();
  final _branch = TextEditingController();
  final _glCode = TextEditingController();
  final _opening = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'CURRENT';
  bool _isDefault = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = (e['name'] ?? '').toString();
      _bankName.text = (e['bankName'] ?? '').toString();
      _accountNumber.text = (e['accountNumber'] ?? '').toString();
      _ifsc.text = (e['ifsc'] ?? '').toString();
      _branch.text = (e['branch'] ?? '').toString();
      _glCode.text = (e['glAccountCode'] ?? '').toString();
      _opening.text = ((e['openingBalance'] as num?)?.toString()) ?? '';
      _notes.text = (e['notes'] ?? '').toString();
      _type = (e['accountType'] ?? 'CURRENT').toString();
      _isDefault = e['isDefault'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _bankName,
      _accountNumber,
      _ifsc,
      _branch,
      _glCode,
      _opening,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    setState(() => _saving = true);
    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'bankName': _bankName.text.trim(),
      'accountNumber': _accountNumber.text.trim(),
      'ifsc': _ifsc.text.trim(),
      'branch': _branch.text.trim(),
      'accountType': _type,
      'glAccountCode': _glCode.text.trim(),
      'openingBalance': double.tryParse(_opening.text.trim()) ?? 0,
      'isDefault': _isDefault,
      'notes': _notes.text.trim(),
    };
    try {
      final repo = ref.read(bankAccountRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.existing!['id'] as String, body);
      } else {
        await repo.create(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          KSpacing.md, KSpacing.md, KSpacing.md, bottom + KSpacing.md),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? 'Edit bank account' : 'New bank account',
                style: KTypography.labelLarge),
            const SizedBox(height: KSpacing.md),
            KTextField(
                label: 'Name', controller: _name, hint: 'HDFC Current ••4521'),
            const SizedBox(height: KSpacing.sm),
            KTextField(
                label: 'Bank name', controller: _bankName, hint: 'HDFC Bank'),
            const SizedBox(height: KSpacing.sm),
            Row(children: [
              Expanded(
                child: KTextField(
                    label: 'Account number', controller: _accountNumber),
              ),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: _typeDropdown()),
            ]),
            const SizedBox(height: KSpacing.sm),
            Row(children: [
              Expanded(child: KTextField(label: 'IFSC', controller: _ifsc)),
              const SizedBox(width: KSpacing.sm),
              Expanded(child: KTextField(label: 'Branch', controller: _branch)),
            ]),
            const SizedBox(height: KSpacing.sm),
            KTextField(
              label: 'Opening balance',
              controller: _opening,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              prefixIcon: Icons.currency_rupee,
            ),
            const SizedBox(height: KSpacing.sm),
            KTextField(
              label: 'GL account code (optional)',
              controller: _glCode,
              hint: 'Blank → auto-create a ledger under 1020',
              enabled: !_isEdit,
            ),
            const SizedBox(height: KSpacing.sm),
            KTextField(label: 'Notes', controller: _notes, maxLines: 2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default account'),
              subtitle: Text('Used by reconciliation when none is picked',
                  style:
                      KTypography.bodySmall.copyWith(color: KColors.textHint)),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: KSpacing.sm),
            KButton(
              label: _isEdit ? 'Save' : 'Create',
              icon: Icons.check,
              isLoading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _type,
      decoration: const InputDecoration(
        labelText: 'Type',
        border: OutlineInputBorder(),
      ),
      items: _accountTypes
          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
          .toList(),
      onChanged: (v) => setState(() => _type = v ?? _type),
    );
  }
}
