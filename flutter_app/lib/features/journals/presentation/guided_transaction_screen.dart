import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../data/journal_repository.dart';

enum GuidedTransactionType {
  bankCharge,
  salaryPayment,
  ownerWithdrawal,
  loanReceived,
  loanEmi,
  depreciation,
  openingBalance,
}

class GuidedTransactionScreen extends ConsumerStatefulWidget {
  const GuidedTransactionScreen({super.key});

  @override
  ConsumerState<GuidedTransactionScreen> createState() =>
      _GuidedTransactionScreenState();
}

class _GuidedTransactionScreenState
    extends ConsumerState<GuidedTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _gstController = TextEditingController();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _cashOpeningController = TextEditingController();
  final _bankOpeningController = TextEditingController();
  final _inventoryOpeningController = TextEditingController();
  final _arOpeningController = TextEditingController();
  final _reasonController = TextEditingController();

  GuidedTransactionType _type = GuidedTransactionType.bankCharge;
  DateTime _date = DateTime.now();
  String _cashOrBankCode = '1010';
  String _loanAccountCode = '2500';
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _gstController.dispose();
    _principalController.dispose();
    _interestController.dispose();
    _cashOpeningController.dispose();
    _bankOpeningController.dispose();
    _inventoryOpeningController.dispose();
    _arOpeningController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/accounting/journal-entries'),
        ),
        title: const Text('Create Transaction'),
      ),
      body: accountsAsync.when(
        loading: () => const KLoading(),
        error: (error, _) => KErrorView(message: error.toString()),
        data: (accounts) {
          final lines = _buildLines(accounts);
          final totals = _totals(lines);

          return Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 980;
                final formPanel = _TransactionForm(
                  type: _type,
                  date: _date,
                  accounts: accounts,
                  cashOrBankCode: _cashOrBankCode,
                  loanAccountCode: _loanAccountCode,
                  amountController: _amountController,
                  gstController: _gstController,
                  principalController: _principalController,
                  interestController: _interestController,
                  cashOpeningController: _cashOpeningController,
                  bankOpeningController: _bankOpeningController,
                  inventoryOpeningController: _inventoryOpeningController,
                  arOpeningController: _arOpeningController,
                  reasonController: _reasonController,
                  onTypeChanged: (value) => setState(() => _type = value),
                  onDateChanged: (value) => setState(() => _date = value),
                  onCashOrBankChanged: (value) =>
                      setState(() => _cashOrBankCode = value),
                  onLoanAccountChanged: (value) =>
                      setState(() => _loanAccountCode = value),
                  onChanged: () => setState(() {}),
                );
                final previewPanel = _PreviewCard(
                  lines: lines,
                  debitTotal: totals.$1,
                  creditTotal: totals.$2,
                  warning: _warningForType(),
                  saving: _saving,
                  onSubmit: lines.isEmpty ? null : () => _submit(accounts),
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(KSpacing.lg),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: formPanel),
                            KSpacing.hGapLg,
                            Expanded(flex: 4, child: previewPanel),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            formPanel,
                            KSpacing.vGapLg,
                            previewPanel,
                          ],
                        ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String? _warningForType() {
    return switch (_type) {
      GuidedTransactionType.openingBalance =>
        'Use this only during first-time setup. Opening balances affect the starting Trial Balance.',
      _ => null,
    };
  }

  Future<void> _submit(List<AccountDto> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    final lines = _buildLines(accounts);
    final totals = _totals(lines);
    if (lines.isEmpty || (totals.$1 - totals.$2).abs() > 0.01) {
      _showSnack('Debit and credit totals must match.');
      return;
    }
    final validationError = _validateAccounts(accounts);
    if (validationError != null) {
      _showSnack(validationError);
      return;
    }
    if (_type == GuidedTransactionType.openingBalance) {
      final confirmed = await _confirmOpeningBalanceIfExisting();
      if (!confirmed) return;
    }

    setState(() => _saving = true);
    try {
      final title = _template(_type).title;
      await ref.read(journalRepositoryProvider).createJournal({
        'effectiveDate': _apiDate(_date),
        'description': '$title - ${_reasonController.text.trim()}',
        'sourceModule': _type == GuidedTransactionType.openingBalance
            ? 'OPENING_BALANCE'
            : 'GUIDED_TRANSACTION',
        'autoPost': true,
        'lines': lines
            .map((line) => {
                  'accountCode': line.account.code,
                  'description': line.description,
                  'debit': line.debit,
                  'credit': line.credit,
                })
            .toList(),
      });
      ref.invalidate(journalListProvider);
      if (mounted) context.go('/accounting/journal-entries');
    } catch (error) {
      _showSnack(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateAccounts(List<AccountDto> accounts) {
    AccountDto? account(String code) =>
        accounts.where((a) => a.code == code).firstOrNull;
    bool isType(String code, String type) =>
        account(code)?.type.toUpperCase() == type;
    bool selectedCashBankIsAsset() =>
        account(_cashOrBankCode)?.type.toUpperCase() == 'ASSET';
    bool selectedLoanIsLiability() =>
        account(_loanAccountCode)?.type.toUpperCase() == 'LIABILITY';

    if (_needsCashBank(_type) && !selectedCashBankIsAsset()) {
      return 'Paid from / received into account must be an asset account.';
    }
    if ((_type == GuidedTransactionType.loanReceived ||
            _type == GuidedTransactionType.loanEmi) &&
        !selectedLoanIsLiability()) {
      return 'Loan account must be a liability account.';
    }
    if (_type == GuidedTransactionType.ownerWithdrawal &&
        !isType('3030', 'EQUITY')) {
      return 'Owner withdrawal must post to an equity drawings account.';
    }
    if (_type == GuidedTransactionType.salaryPayment &&
        !isType('5100', 'EXPENSE')) {
      return 'Salary payment must post to a salary expense account.';
    }
    if (_type == GuidedTransactionType.bankCharge &&
        !isType('5280', 'EXPENSE')) {
      return 'Bank charge must post to a bank charges expense account.';
    }
    if (_type == GuidedTransactionType.depreciation &&
        (!isType('5270', 'EXPENSE') || !isType('1690', 'ASSET'))) {
      return 'Depreciation requires depreciation expense and accumulated depreciation accounts.';
    }
    return null;
  }

  Future<bool> _confirmOpeningBalanceIfExisting() async {
    try {
      final response = await ref.read(journalRepositoryProvider).listJournals(
            sourceModule: 'OPENING_BALANCE',
            size: 1,
          );
      final data = response['data'];
      final content = data is Map ? data['content'] : null;
      final existing = content is List && content.isNotEmpty;
      if (!existing || !mounted) return true;

      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Opening balances already exist'),
              content: const Text(
                'Posting opening balances again can duplicate your starting Trial Balance. Continue only if you are correcting setup intentionally.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Post Anyway'),
                ),
              ],
            ),
          ) ??
          false;
    } catch (_) {
      if (!mounted) return false;
      return await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Could not verify opening balances'),
              content: const Text(
                'The system could not check whether opening balances already exist. Continue only if you are sure this is first-time setup.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ) ??
          false;
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  List<_JournalPreviewLine> _buildLines(List<AccountDto> accounts) {
    AccountDto? account(String code) =>
        accounts.where((a) => a.code == code).firstOrNull;
    double amount(TextEditingController c) =>
        double.tryParse(c.text.trim()) ?? 0;

    _JournalPreviewLine? line(
      String code, {
      required double debit,
      required double credit,
      required String description,
    }) {
      final acc = account(code);
      if (acc == null || (debit <= 0 && credit <= 0)) return null;
      return _JournalPreviewLine(
        account: acc,
        debit: debit,
        credit: credit,
        description: description,
      );
    }

    final base = amount(_amountController);
    final gst = amount(_gstController);
    final principal = amount(_principalController);
    final interest = amount(_interestController);
    final reason = _reasonController.text.trim();
    final label = reason.isEmpty ? _template(_type).title : reason;

    final raw = switch (_type) {
      GuidedTransactionType.bankCharge => [
          line('5280', debit: base, credit: 0, description: label),
          line('1500', debit: gst, credit: 0, description: 'GST input credit'),
          line(
            _cashOrBankCode,
            debit: 0,
            credit: base + gst,
            description: 'Paid from cash/bank',
          ),
        ],
      GuidedTransactionType.salaryPayment => [
          line('5100', debit: base, credit: 0, description: label),
          line(
            _cashOrBankCode,
            debit: 0,
            credit: base,
            description: 'Paid from cash/bank',
          ),
        ],
      GuidedTransactionType.ownerWithdrawal => [
          line('3030', debit: base, credit: 0, description: label),
          line(
            _cashOrBankCode,
            debit: 0,
            credit: base,
            description: 'Owner withdrawal',
          ),
        ],
      GuidedTransactionType.loanReceived => [
          line(
            _cashOrBankCode,
            debit: base,
            credit: 0,
            description: 'Loan received',
          ),
          line(
            _loanAccountCode,
            debit: 0,
            credit: base,
            description: label,
          ),
        ],
      GuidedTransactionType.loanEmi => [
          line(
            _loanAccountCode,
            debit: principal,
            credit: 0,
            description: 'Loan principal repayment',
          ),
          line('5300',
              debit: interest, credit: 0, description: 'Loan interest'),
          line(
            _cashOrBankCode,
            debit: 0,
            credit: principal + interest,
            description: 'EMI paid',
          ),
        ],
      GuidedTransactionType.depreciation => [
          line('5270', debit: base, credit: 0, description: label),
          line(
            '1690',
            debit: 0,
            credit: base,
            description: 'Accumulated depreciation',
          ),
        ],
      GuidedTransactionType.openingBalance => [
          line(
            '1010',
            debit: amount(_cashOpeningController),
            credit: 0,
            description: 'Opening cash',
          ),
          line(
            '1020',
            debit: amount(_bankOpeningController),
            credit: 0,
            description: 'Opening bank',
          ),
          line(
            '1200',
            debit: amount(_inventoryOpeningController),
            credit: 0,
            description: 'Opening inventory',
          ),
          line(
            '1100',
            debit: amount(_arOpeningController),
            credit: 0,
            description: 'Opening receivables',
          ),
          line(
            '3010',
            debit: 0,
            credit: amount(_cashOpeningController) +
                amount(_bankOpeningController) +
                amount(_inventoryOpeningController) +
                amount(_arOpeningController),
            description: 'Opening balance equity',
          ),
        ],
    };

    return raw.whereType<_JournalPreviewLine>().toList();
  }

  (double, double) _totals(List<_JournalPreviewLine> lines) {
    return (
      lines.fold<double>(0, (sum, line) => sum + line.debit),
      lines.fold<double>(0, (sum, line) => sum + line.credit),
    );
  }
}

class _TransactionForm extends StatelessWidget {
  final GuidedTransactionType type;
  final DateTime date;
  final List<AccountDto> accounts;
  final String cashOrBankCode;
  final String loanAccountCode;
  final TextEditingController amountController;
  final TextEditingController gstController;
  final TextEditingController principalController;
  final TextEditingController interestController;
  final TextEditingController cashOpeningController;
  final TextEditingController bankOpeningController;
  final TextEditingController inventoryOpeningController;
  final TextEditingController arOpeningController;
  final TextEditingController reasonController;
  final ValueChanged<GuidedTransactionType> onTypeChanged;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onCashOrBankChanged;
  final ValueChanged<String> onLoanAccountChanged;
  final VoidCallback onChanged;

  const _TransactionForm({
    required this.type,
    required this.date,
    required this.accounts,
    required this.cashOrBankCode,
    required this.loanAccountCode,
    required this.amountController,
    required this.gstController,
    required this.principalController,
    required this.interestController,
    required this.cashOpeningController,
    required this.bankOpeningController,
    required this.inventoryOpeningController,
    required this.arOpeningController,
    required this.reasonController,
    required this.onTypeChanged,
    required this.onDateChanged,
    required this.onCashOrBankChanged,
    required this.onLoanAccountChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final template = _template(type);
    final cashBankAccounts = accounts
        .where((a) => ['1010', '1020'].contains(a.code))
        .toList(growable: false);
    final loanAccounts = accounts
        .where((a) => a.type.toUpperCase() == 'LIABILITY')
        .toList(growable: false);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What happened?', style: KTypography.h4),
          KSpacing.vGapMd,
          DropdownButtonFormField<GuidedTransactionType>(
            initialValue: type,
            decoration: const InputDecoration(labelText: 'Transaction type'),
            items: GuidedTransactionType.values
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(_template(value).title),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) onTypeChanged(value);
            },
          ),
          KSpacing.vGapSm,
          Text(template.description, style: KTypography.bodyMedium),
          KSpacing.vGapLg,
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(_apiDate(date)),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onDateChanged(picked);
            },
          ),
          KSpacing.vGapMd,
          if (type != GuidedTransactionType.openingBalance) ...[
            KTextField.amount(
              label: type == GuidedTransactionType.loanEmi
                  ? 'Total EMI amount'
                  : 'Amount',
              controller: amountController,
              onChanged: (_) => onChanged(),
              isRequired: type != GuidedTransactionType.loanEmi,
              validator: type == GuidedTransactionType.loanEmi
                  ? null
                  : _positiveValidator,
            ),
            if (type == GuidedTransactionType.bankCharge) ...[
              KSpacing.vGapMd,
              KTextField.amount(
                label: 'GST input credit, if any',
                controller: gstController,
                onChanged: (_) => onChanged(),
              ),
            ],
            if (type == GuidedTransactionType.loanEmi) ...[
              KSpacing.vGapMd,
              KTextField.amount(
                label: 'Principal paid',
                controller: principalController,
                onChanged: (_) => onChanged(),
                isRequired: true,
                validator: _positiveValidator,
              ),
              KSpacing.vGapMd,
              KTextField.amount(
                label: 'Interest paid',
                controller: interestController,
                onChanged: (_) => onChanged(),
                isRequired: true,
                validator: _positiveValidator,
              ),
            ],
          ] else ...[
            _MoneyField('Opening cash', cashOpeningController, onChanged),
            KSpacing.vGapMd,
            _MoneyField('Opening bank', bankOpeningController, onChanged),
            KSpacing.vGapMd,
            _MoneyField(
              'Opening inventory value',
              inventoryOpeningController,
              onChanged,
            ),
            KSpacing.vGapMd,
            _MoneyField(
              'Opening customer receivables',
              arOpeningController,
              onChanged,
            ),
          ],
          if (_needsCashBank(type)) ...[
            KSpacing.vGapMd,
            _AccountDropdown(
              label: type == GuidedTransactionType.loanReceived
                  ? 'Received into'
                  : 'Paid from',
              accounts: cashBankAccounts,
              value: cashOrBankCode,
              onChanged: onCashOrBankChanged,
            ),
          ],
          if (type == GuidedTransactionType.loanReceived ||
              type == GuidedTransactionType.loanEmi) ...[
            KSpacing.vGapMd,
            _AccountDropdown(
              label: 'Loan account',
              accounts: loanAccounts,
              value: loanAccountCode,
              onChanged: onLoanAccountChanged,
            ),
          ],
          KSpacing.vGapMd,
          KTextField(
            label: 'Reason / narration',
            controller: reasonController,
            maxLines: 3,
            isRequired: true,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Reason is required'
                : null,
            onChanged: (_) => onChanged(),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final List<_JournalPreviewLine> lines;
  final double debitTotal;
  final double creditTotal;
  final String? warning;
  final bool saving;
  final VoidCallback? onSubmit;

  const _PreviewCard({
    required this.lines,
    required this.debitTotal,
    required this.creditTotal,
    required this.warning,
    required this.saving,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final balanced = (debitTotal - creditTotal).abs() <= 0.01;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Accounting preview',
                  style: KTypography.h4,
                ),
              ),
              Chip(
                label: Text(balanced ? 'Balanced' : 'Check totals'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          KSpacing.vGapMd,
          if (warning != null) ...[
            _WarningBanner(message: warning!),
            KSpacing.vGapMd,
          ],
          if (lines.isEmpty)
            const Text('Enter amount to see debit and credit lines.')
          else
            ...lines.map((line) => _PreviewLineTile(line: line)),
          const Divider(height: 28),
          _TotalRow(label: 'Debit', amount: debitTotal),
          _TotalRow(label: 'Credit', amount: creditTotal),
          KSpacing.vGapLg,
          FilledButton.icon(
            onPressed: saving || !balanced ? null : onSubmit,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(saving ? 'Posting...' : 'Post Transaction'),
          ),
        ],
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _MoneyField(this.label, this.controller, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return KTextField.amount(
      label: label,
      controller: controller,
      onChanged: (_) => onChanged(),
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  final String label;
  final List<AccountDto> accounts;
  final String value;
  final ValueChanged<String> onChanged;

  const _AccountDropdown({
    required this.label,
    required this.accounts,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = accounts.firstOrNull?.code;
    return DropdownButtonFormField<String>(
      initialValue: accounts.any((a) => a.code == value) ? value : fallback,
      decoration: InputDecoration(labelText: label),
      items: accounts
          .map(
            (account) => DropdownMenuItem(
              value: account.code,
              child: Text('${account.code} - ${account.name}'),
            ),
          )
          .toList(),
      onChanged: (newValue) {
        if (newValue != null) onChanged(newValue);
      },
    );
  }
}

class _PreviewLineTile extends StatelessWidget {
  final _JournalPreviewLine line;

  const _PreviewLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${line.account.code} - ${line.account.name}'),
                Text(line.description, style: KTypography.bodySmall),
              ],
            ),
          ),
          SizedBox(
            width: 112,
            child: Text(
              line.debit > 0
                  ? 'DR ${CurrencyFormatter.formatIndian(line.debit)}'
                  : 'CR ${CurrencyFormatter.formatIndian(line.credit)}',
              textAlign: TextAlign.right,
              style: KTypography.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;

  const _TotalRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: KTypography.labelLarge)),
        Text(CurrencyFormatter.formatIndian(amount),
            style: KTypography.labelLarge),
      ],
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String message;

  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _JournalPreviewLine {
  final AccountDto account;
  final double debit;
  final double credit;
  final String description;

  const _JournalPreviewLine({
    required this.account,
    required this.debit,
    required this.credit,
    required this.description,
  });
}

class _Template {
  final String title;
  final String description;

  const _Template(this.title, this.description);
}

_Template _template(GuidedTransactionType type) => switch (type) {
      GuidedTransactionType.bankCharge => const _Template(
          'Bank charge',
          'Use when bank deducts fees or service charges.',
        ),
      GuidedTransactionType.salaryPayment => const _Template(
          'Salary payment',
          'Use when staff salary is paid without a payroll run.',
        ),
      GuidedTransactionType.ownerWithdrawal => const _Template(
          'Owner withdrawal',
          'Use when owner takes cash or bank money for personal use.',
        ),
      GuidedTransactionType.loanReceived => const _Template(
          'Loan received',
          'Use when money comes in as a loan.',
        ),
      GuidedTransactionType.loanEmi => const _Template(
          'Loan EMI',
          'Split an EMI between principal repayment and interest expense.',
        ),
      GuidedTransactionType.depreciation => const _Template(
          'Depreciation',
          'Use for month-end or year-end asset depreciation.',
        ),
      GuidedTransactionType.openingBalance => const _Template(
          'Opening balances',
          'Use once during first-time setup to enter starting balances.',
        ),
    };

bool _needsCashBank(GuidedTransactionType type) {
  return switch (type) {
    GuidedTransactionType.bankCharge ||
    GuidedTransactionType.salaryPayment ||
    GuidedTransactionType.ownerWithdrawal ||
    GuidedTransactionType.loanReceived ||
    GuidedTransactionType.loanEmi =>
      true,
    _ => false,
  };
}

String? _positiveValidator(String? value) {
  final amount = double.tryParse(value?.trim() ?? '');
  if (amount == null || amount <= 0) return 'Enter an amount greater than 0';
  return null;
}

String _apiDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
