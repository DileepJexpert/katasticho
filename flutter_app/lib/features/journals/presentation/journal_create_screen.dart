import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/form_error_handler.dart';
import '../../../core/widgets/widgets.dart';
import '../../accounts/data/account_repository.dart';
import '../data/journal_repository.dart';

class _JournalLine {
  AccountDto? account;
  final TextEditingController debitController;
  final TextEditingController creditController;
  final TextEditingController descriptionController;

  _JournalLine()
      : debitController = TextEditingController(),
        creditController = TextEditingController(),
        descriptionController = TextEditingController();

  double get debit => double.tryParse(debitController.text) ?? 0.0;
  double get credit => double.tryParse(creditController.text) ?? 0.0;

  void dispose() {
    debitController.dispose();
    creditController.dispose();
    descriptionController.dispose();
  }
}

class JournalCreateScreen extends ConsumerStatefulWidget {
  const JournalCreateScreen({super.key});

  @override
  ConsumerState<JournalCreateScreen> createState() =>
      _JournalCreateScreenState();
}

class _JournalCreateScreenState extends ConsumerState<JournalCreateScreen>
    with FormErrorHandler {
  final _formKey = GlobalKey<FormState>();
  DateTime? _effectiveDate;
  final _referenceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final List<_JournalLine> _lines = [];
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _effectiveDate = DateTime.now();
    _lines.add(_JournalLine());
    _lines.add(_JournalLine());
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _descriptionController.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  double get _totalDebit =>
      _lines.fold(0.0, (sum, l) => sum + l.debit);

  double get _totalCredit =>
      _lines.fold(0.0, (sum, l) => sum + l.credit);

  double get _difference => (_totalDebit - _totalCredit).abs();

  bool get _isBalanced => _difference < 0.005;

  bool get _canSubmit {
    if (_effectiveDate == null) return false;
    if (_descriptionController.text.trim().isEmpty) return false;
    // At least 2 lines with accounts
    final filledLines =
        _lines.where((l) => l.account != null).toList();
    if (filledLines.length < 2) return false;
    if (!_isBalanced) return false;
    if (_totalDebit == 0) return false;
    return true;
  }

  void _addLine() {
    setState(() => _lines.add(_JournalLine()));
  }

  void _removeLine(int index) {
    if (_lines.length <= 2) return;
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  void _recalc() => setState(() {});

  Future<void> _submit({required bool autoPost}) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_canSubmit) return;

    setState(() => _submitting = true);

    final body = <String, dynamic>{
      'effectiveDate': DateFormatter.api(_effectiveDate!),
      'description': _descriptionController.text.trim(),
      'sourceModule': 'MANUAL',
      'autoPost': autoPost,
      'lines': _lines
          .where((l) => l.account != null)
          .map((l) => {
                'accountCode': l.account!.code,
                'debit': l.debit,
                'credit': l.credit,
                'description': l.descriptionController.text.trim(),
              })
          .toList(),
    };

    if (_referenceController.text.trim().isNotEmpty) {
      body['reference'] = _referenceController.text.trim();
    }

    try {
      final repo = ref.read(journalRepositoryProvider);
      await repo.createJournal(body);
      ref.invalidate(journalListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(autoPost
                ? 'Journal entry created and posted'
                : 'Journal entry saved as draft'),
          ),
        );
        context.go('/accounting/journal-entries');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create journal: $e'),
            backgroundColor: KColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Manual Journal'),
      ),
      body: accountsAsync.when(
        loading: () => const KLoading(message: 'Loading accounts...'),
        error: (err, _) => KErrorView(
          message: 'Failed to load accounts',
          onRetry: () => ref.invalidate(accountsProvider),
        ),
        data: (accounts) => _buildForm(accounts, cs),
      ),
      bottomNavigationBar: _buildFooter(cs),
    );
  }

  Widget _buildForm(List<AccountDto> accounts, ColorScheme cs) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: KSpacing.pagePadding,
        children: [
          // Date picker
          KDatePicker(
            label: 'Effective Date',
            value: _effectiveDate,
            onChanged: (d) => setState(() => _effectiveDate = d),
          ),
          KSpacing.vGapMd,

          // Reference
          KTextField(
            label: 'Reference',
            hint: 'e.g. Year-end adjustment',
            controller: _referenceController,
            serverError: serverErrors['reference'],
          ),
          KSpacing.vGapMd,

          // Description
          KTextField(
            label: 'Description',
            hint: 'Describe this journal entry',
            controller: _descriptionController,
            maxLines: 2,
            isRequired: true,
            serverError: serverErrors['description'],
            validator: (v) => fieldError(
              'description',
              (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            onChanged: (_) => _recalc(),
          ),
          KSpacing.vGapLg,

          // Line items header
          Row(
            children: [
              Text('Line Items',
                  style: KTypography.h3.copyWith(color: cs.onSurface)),
              const Spacer(),
              KButton(
                label: 'Add Line',
                icon: Icons.add,
                variant: KButtonVariant.text,
                size: KButtonSize.small,
                onPressed: _addLine,
              ),
            ],
          ),
          KSpacing.vGapSm,

          // Lines
          ...List.generate(_lines.length, (index) {
            return _JournalLineCard(
              key: ValueKey(index),
              index: index,
              line: _lines[index],
              accounts: accounts,
              canRemove: _lines.length > 2,
              onRemove: () => _removeLine(index),
              onChanged: _recalc,
            );
          }),

          KSpacing.vGapMd,

          // Balance indicator
          _BalanceIndicator(
            totalDebit: _totalDebit,
            totalCredit: _totalCredit,
            difference: _difference,
            isBalanced: _isBalanced,
          ),

          // Extra padding for scroll
          KSpacing.vGapXl,
        ],
      ),
    );
  }

  Widget _buildFooter(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(KSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(
            color: cs.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: KButton(
                label: 'Save Draft',
                variant: KButtonVariant.outlined,
                isLoading: _submitting,
                onPressed:
                    _canSubmit ? () => _submit(autoPost: false) : null,
              ),
            ),
            KSpacing.hGapMd,
            Expanded(
              child: KButton(
                label: 'Post',
                variant: KButtonVariant.primary,
                icon: Icons.check,
                isLoading: _submitting,
                onPressed:
                    _canSubmit ? () => _submit(autoPost: true) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalLineCard extends StatelessWidget {
  final int index;
  final _JournalLine line;
  final List<AccountDto> accounts;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _JournalLineCard({
    super.key,
    required this.index,
    required this.line,
    required this.accounts,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return KCard(
      margin: const EdgeInsets.only(bottom: KSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with line number and delete
          Row(
            children: [
              Text(
                'Line ${index + 1}',
                style: KTypography.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: KColors.error,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Remove line',
                  onPressed: onRemove,
                ),
            ],
          ),
          KSpacing.vGapSm,

          // Account dropdown
          DropdownButtonFormField<AccountDto>(
            value: line.account,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Account',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
            ),
            items: accounts
                .where((a) => a.isActive && !a.hasChildren)
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(
                        '${a.code} — ${a.name}',
                        overflow: TextOverflow.ellipsis,
                        style: KTypography.bodySmall,
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              line.account = v;
              onChanged();
            },
            validator: (v) => v == null ? 'Select an account' : null,
          ),
          KSpacing.vGapSm,

          // Debit / Credit row
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.debitController,
                  decoration: const InputDecoration(
                    labelText: 'Debit',
                    prefixText: '₹ ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  onChanged: (v) {
                    // If debit has a value, clear credit
                    if (v.isNotEmpty &&
                        (double.tryParse(v) ?? 0) > 0 &&
                        line.creditController.text.isNotEmpty) {
                      line.creditController.clear();
                    }
                    onChanged();
                  },
                ),
              ),
              KSpacing.hGapSm,
              Expanded(
                child: TextFormField(
                  controller: line.creditController,
                  decoration: const InputDecoration(
                    labelText: 'Credit',
                    prefixText: '₹ ',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  onChanged: (v) {
                    // If credit has a value, clear debit
                    if (v.isNotEmpty &&
                        (double.tryParse(v) ?? 0) > 0 &&
                        line.debitController.text.isNotEmpty) {
                      line.debitController.clear();
                    }
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,

          // Line description
          TextFormField(
            controller: line.descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Line description (optional)',
              isDense: true,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceIndicator extends StatelessWidget {
  final double totalDebit;
  final double totalCredit;
  final double difference;
  final bool isBalanced;

  const _BalanceIndicator({
    required this.totalDebit,
    required this.totalCredit,
    required this.difference,
    required this.isBalanced,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return KCard(
      borderColor: isBalanced
          ? KColors.success.withValues(alpha: 0.4)
          : KColors.error.withValues(alpha: 0.4),
      backgroundColor: isBalanced
          ? KColors.success.withValues(alpha: 0.04)
          : KColors.error.withValues(alpha: 0.04),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Debit',
                        style: KTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
                    Text(
                      CurrencyFormatter.formatIndian(totalDebit),
                      style: KTypography.amountSmall.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Total Credit',
                        style: KTypography.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        )),
                    Text(
                      CurrencyFormatter.formatIndian(totalCredit),
                      style: KTypography.amountSmall.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          KSpacing.vGapSm,
          const Divider(height: 1),
          KSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBalanced
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 18,
                color: isBalanced ? KColors.success : KColors.error,
              ),
              KSpacing.hGapSm,
              Text(
                isBalanced
                    ? 'Balanced'
                    : 'Difference: ${CurrencyFormatter.formatIndian(difference)}',
                style: KTypography.labelLarge.copyWith(
                  color: isBalanced ? KColors.success : KColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
