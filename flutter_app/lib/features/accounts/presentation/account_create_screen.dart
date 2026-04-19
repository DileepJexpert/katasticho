import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/account_repository.dart';

const _accountTypes = [
  ('ASSET', 'Asset'),
  ('LIABILITY', 'Liability'),
  ('EQUITY', 'Equity'),
  ('REVENUE', 'Income / Revenue'),
  ('EXPENSE', 'Expense'),
];

const _subTypes = {
  'ASSET': [
    ('CURRENT_ASSET', 'Current Asset'),
    ('FIXED_ASSET', 'Fixed Asset'),
    ('OTHER_ASSET', 'Other Asset'),
  ],
  'LIABILITY': [
    ('CURRENT_LIABILITY', 'Current Liability'),
    ('LONG_TERM_LIABILITY', 'Long-term Liability'),
    ('OTHER_LIABILITY', 'Other Liability'),
  ],
  'EQUITY': [
    ('OWNERS_EQUITY', 'Owner\'s Equity'),
    ('RETAINED_EARNINGS', 'Retained Earnings'),
  ],
  'REVENUE': [
    ('OPERATING_INCOME', 'Operating Income'),
    ('OTHER_INCOME', 'Other Income'),
  ],
  'EXPENSE': [
    ('COST_OF_GOODS_SOLD', 'Cost of Goods Sold'),
    ('OPERATING_EXPENSE', 'Operating Expense'),
    ('OTHER_EXPENSE', 'Other Expense'),
  ],
};

class AccountCreateScreen extends ConsumerStatefulWidget {
  final String? accountId;

  const AccountCreateScreen({super.key, this.accountId});

  @override
  ConsumerState<AccountCreateScreen> createState() => _AccountCreateScreenState();
}

class _AccountCreateScreenState extends ConsumerState<AccountCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController(text: '0');
  final _parentCodeCtrl = TextEditingController();

  String _accountType = 'ASSET';
  String? _subType;

  bool _loading = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    if (widget.accountId != null) {
      _isEdit = true;
      _loadAccount();
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _openingBalanceCtrl.dispose();
    _parentCodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final repo = ref.read(accountRepositoryProvider);
    final result = await repo.getAccount(widget.accountId!);
    final a = (result['data'] ?? result) as Map<String, dynamic>;
    setState(() {
      _codeCtrl.text = a['code'] as String? ?? '';
      _nameCtrl.text = a['name'] as String? ?? '';
      _descriptionCtrl.text = a['description'] as String? ?? '';
      _openingBalanceCtrl.text =
          (a['openingBalance'] as num?)?.toString() ?? '0';
      _accountType = a['type'] as String? ?? 'ASSET';
      _subType = a['subType'] as String?;
    });
  }

  List<(String, String)> get _currentSubTypes =>
      _subTypes[_accountType] ?? const [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Account' : 'Add Account'),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: KSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionTitle('Account Type'),
              KSpacing.vGapSm,
              DropdownButtonFormField<String>(
                value: _accountType,
                decoration: const InputDecoration(
                  labelText: 'Type *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _accountTypes
                    .map((t) => DropdownMenuItem(
                          value: t.$1,
                          child: Text(t.$2),
                        ))
                    .toList(),
                onChanged: _isEdit
                    ? null
                    : (v) => setState(() {
                          _accountType = v ?? 'ASSET';
                          _subType = null;
                        }),
              ),
              if (_currentSubTypes.isNotEmpty) ...[
                KSpacing.vGapMd,
                DropdownButtonFormField<String?>(
                  value: _subType,
                  decoration: const InputDecoration(
                    labelText: 'Sub-type',
                    prefixIcon: Icon(Icons.subdirectory_arrow_right_outlined),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    ..._currentSubTypes.map((t) => DropdownMenuItem(
                          value: t.$1,
                          child: Text(t.$2),
                        )),
                  ],
                  onChanged: (v) => setState(() => _subType = v),
                ),
              ],
              KSpacing.vGapLg,

              _SectionTitle('Account Details'),
              KSpacing.vGapSm,
              KTextField(
                label: 'Account Code *',
                controller: _codeCtrl,
                prefixIcon: Icons.tag_outlined,
                enabled: !_isEdit,
                hint: 'e.g. 1010',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'Account Name *',
                controller: _nameCtrl,
                prefixIcon: Icons.drive_file_rename_outline,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              KSpacing.vGapMd,
              KTextField(
                label: 'Description',
                controller: _descriptionCtrl,
                prefixIcon: Icons.notes_outlined,
                maxLines: 3,
              ),
              KSpacing.vGapLg,

              _SectionTitle('Financial'),
              KSpacing.vGapSm,
              KTextField(
                label: 'Opening Balance (₹)',
                controller: _openingBalanceCtrl,
                prefixIcon: Icons.account_balance_wallet_outlined,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: !_isEdit,
              ),
              if (!_isEdit) ...[
                KSpacing.vGapMd,
                KTextField(
                  label: 'Parent Account Code',
                  controller: _parentCodeCtrl,
                  prefixIcon: Icons.account_tree_outlined,
                  hint: 'Leave blank for root account',
                ),
              ],
              KSpacing.vGapXl,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final repo = ref.read(accountRepositoryProvider);
    try {
      if (_isEdit) {
        final data = <String, dynamic>{
          'name': _nameCtrl.text.trim(),
          if (_subType != null) 'subType': _subType,
          if (_descriptionCtrl.text.isNotEmpty)
            'description': _descriptionCtrl.text.trim(),
        };
        await repo.updateAccount(widget.accountId!, data);
      } else {
        final data = <String, dynamic>{
          'code': _codeCtrl.text.trim(),
          'name': _nameCtrl.text.trim(),
          'type': _accountType,
          if (_subType != null) 'subType': _subType,
          if (_descriptionCtrl.text.isNotEmpty)
            'description': _descriptionCtrl.text.trim(),
          'openingBalance':
              double.tryParse(_openingBalanceCtrl.text) ?? 0.0,
          if (_parentCodeCtrl.text.isNotEmpty)
            'parentCode': _parentCodeCtrl.text.trim(),
        };
        await repo.createAccount(data);
      }
      ref.invalidate(accountListProvider);
      ref.invalidate(accountsProvider);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save account: $e')),
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: KTypography.h3);
}
