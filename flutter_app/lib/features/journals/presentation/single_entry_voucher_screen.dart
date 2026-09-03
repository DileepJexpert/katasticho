import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_text_field.dart';
import '../../accounts/data/account_repository.dart';
import '../data/single_entry_voucher_repository.dart';

class SingleEntryVoucherScreen extends ConsumerStatefulWidget {
  const SingleEntryVoucherScreen({super.key});

  @override
  ConsumerState<SingleEntryVoucherScreen> createState() => _SingleEntryVoucherScreenState();
}

class _LineItem {
  String? accountId;
  String? accountName;
  String? accountCode;
  final TextEditingController amountController = TextEditingController();
  final TextEditingController narrationController = TextEditingController();

  double get amount => double.tryParse(amountController.text.replaceAll(',', '')) ?? 0.0;
}

class _SingleEntryVoucherScreenState extends ConsumerState<SingleEntryVoucherScreen> {
  final _formKey = GlobalKey<FormState>();

  String _voucherType = 'PAYMENT'; // PAYMENT, RECEIPT, CONTRA
  DateTime _date = DateTime.now();
  final _refController = TextEditingController();
  final _narrationController = TextEditingController();

  String? _primaryAccountId;

  final List<_LineItem> _lines = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _addLine();
  }

  @override
  void dispose() {
    _refController.dispose();
    _narrationController.dispose();
    for (final line in _lines) {
      line.amountController.dispose();
      line.narrationController.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    setState(() {
      final line = _LineItem();
      line.amountController.addListener(() => setState(() {}));
      _lines.add(line);
    });
  }

  void _removeLine(int index) {
    if (_lines.length <= 1) return;
    setState(() {
      final line = _lines.removeAt(index);
      line.amountController.dispose();
      line.narrationController.dispose();
    });
  }

  double get _totalAmount => _lines.fold(0.0, (sum, l) => sum + l.amount);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_primaryAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a primary Cash/Bank Account'), backgroundColor: KColors.error),
      );
      return;
    }

    final validLines = _lines.where((l) => l.accountId != null && l.amount > 0).toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one valid line with an account and amount'), backgroundColor: KColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(singleEntryVoucherRepositoryProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);

      final lineDtos = validLines
          .map((l) => SingleEntryVoucherLineDto(
                accountId: l.accountId!,
                amount: l.amount,
                narration: l.narrationController.text.trim().isNotEmpty
                    ? l.narrationController.text.trim()
                    : null,
              ))
          .toList();

      await repo.postVoucher(
        voucherType: _voucherType,
        primaryAccountId: _primaryAccountId!,
        date: dateStr,
        referenceNumber: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
        narration: _narrationController.text.trim().isNotEmpty ? _narrationController.text.trim() : null,
        lines: lineDtos,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_voucherType voucher posted successfully!'),
          backgroundColor: KColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post voucher: $e'), backgroundColor: KColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, alt: true): _submit,
        const SingleActivator(LogicalKeyboardKey.keyA, alt: true): _addLine,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Single-Entry Voucher Mode'),
            actions: [
              KButton.primary(
                label: _isSubmitting ? 'Posting…' : 'Save (Alt+S)',
                icon: Icons.check,
                onPressed: _isSubmitting ? null : _submit,
              ),
              KSpacing.hGapSm,
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: KSpacing.pagePadding,
              children: [
                // Voucher Type Bar (Tally-style F4/F5/F6)
                Row(
                  children: [
                    _VoucherTypeButton(
                      label: 'Payment (F5)',
                      subLabel: 'Cr Bank/Cash  ·  Dr Expenses',
                      isSelected: _voucherType == 'PAYMENT',
                      onTap: () => setState(() => _voucherType = 'PAYMENT'),
                    ),
                    KSpacing.hGapSm,
                    _VoucherTypeButton(
                      label: 'Receipt (F6)',
                      subLabel: 'Dr Bank/Cash  ·  Cr Incomes',
                      isSelected: _voucherType == 'RECEIPT',
                      onTap: () => setState(() => _voucherType = 'RECEIPT'),
                    ),
                    KSpacing.hGapSm,
                    _VoucherTypeButton(
                      label: 'Contra (F4)',
                      subLabel: 'Cash ↔ Bank Transfer',
                      isSelected: _voucherType == 'CONTRA',
                      onTap: () => setState(() => _voucherType = 'CONTRA'),
                    ),
                  ],
                ),
                KSpacing.vGapLg,

                // Header Account & Date
                KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Header Details', style: KTypography.labelLarge),
                      KSpacing.vGapMd,
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Primary Account (Cash / Bank)
                          Expanded(
                            flex: 3,
                            child: accountsAsync.when(
                              loading: () => const Text('Loading accounts…'),
                              error: (e, _) => Text('Error loading accounts: $e'),
                              data: (accounts) {
                                final cashBankAccounts = accounts.where((a) {
                                  final code = a.code;
                                  return code.startsWith('1010') ||
                                      code.startsWith('1020') ||
                                      code.startsWith('102') ||
                                      code.startsWith('100');
                                }).toList();

                                return DropdownButtonFormField<String>(
                                  initialValue: _primaryAccountId,
                                  decoration: InputDecoration(
                                    labelText: _voucherType == 'PAYMENT'
                                        ? 'Paid Through (Cash / Bank Account)'
                                        : 'Received In (Cash / Bank Account)',
                                    border: const OutlineInputBorder(),
                                  ),
                                  items: cashBankAccounts.map((a) {
                                    return DropdownMenuItem(
                                      value: a.id,
                                      child: Text('${a.code} - ${a.name}'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _primaryAccountId = val;
                                    });
                                  },
                                  validator: (v) => v == null ? 'Required' : null,
                                );
                              },
                            ),
                          ),
                          KSpacing.hGapMd,

                          // Date Picker
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _date,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) setState(() => _date = picked);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Voucher Date',
                                  border: OutlineInputBorder(),
                                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                                ),
                                child: Text(DateFormat('dd MMM yyyy').format(_date)),
                              ),
                            ),
                          ),
                          KSpacing.hGapMd,

                          // Ref Number
                          Expanded(
                            flex: 2,
                            child: KTextField(
                              controller: _refController,
                              label: 'Cheque / Ref No',
                              hint: 'e.g. CHQ-882190',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                KSpacing.vGapLg,

                // Particulars / Lines Table
                KCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Particulars (Ledger Accounts)', style: KTypography.labelLarge),
                          KButton.outlined(
                            label: 'Add Line (Alt+A)',
                            icon: Icons.add,
                            onPressed: _addLine,
                          ),
                        ],
                      ),
                      KSpacing.vGapMd,

                      // Lines List
                      ..._lines.asMap().entries.map((entry) {
                        final i = entry.key;
                        final line = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: KSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Line Account Picker
                              Expanded(
                                flex: 4,
                                child: accountsAsync.when(
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                  data: (accounts) {
                                    return DropdownButtonFormField<String>(
                                      initialValue: line.accountId,
                                      decoration: const InputDecoration(
                                        labelText: 'Particulars Account',
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      ),
                                      items: accounts.map((a) {
                                        return DropdownMenuItem(
                                          value: a.id,
                                          child: Text('${a.code} - ${a.name} (${a.type})'),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          line.accountId = val;
                                          final selected = accounts.where((a) => a.id == val).firstOrNull;
                                          line.accountName = selected?.name;
                                          line.accountCode = selected?.code;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                              KSpacing.hGapMd,

                              // Amount
                              Expanded(
                                flex: 2,
                                child: KTextField.amount(
                                  controller: line.amountController,
                                  label: 'Amount (₹)',
                                  hint: '0.00',
                                ),
                              ),
                              KSpacing.hGapMd,

                              // Line Narration
                              Expanded(
                                flex: 3,
                                child: KTextField(
                                  controller: line.narrationController,
                                  label: 'Line Narration (optional)',
                                  hint: 'Remarks',
                                ),
                              ),
                              KSpacing.hGapSm,

                              // Delete Button
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: KColors.error),
                                onPressed: _lines.length > 1 ? () => _removeLine(i) : null,
                              ),
                            ],
                          ),
                        );
                      }),

                      const Divider(),
                      KSpacing.vGapSm,

                      // Voucher Narration
                      KTextField(
                        controller: _narrationController,
                        label: 'Overall Voucher Narration',
                        hint: 'Being payment/receipt towards...',
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                KSpacing.vGapLg,

                // Summary Card
                KCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total Voucher Amount', style: KTypography.bodySmall.copyWith(color: KColors.textSecondary)),
                          KSpacing.vGapXs,
                          KMoney(
                            _totalAmount,
                            style: KTypography.h1.copyWith(color: KColors.primary),
                          ),
                        ],
                      ),
                      KButton.primary(
                        label: _isSubmitting ? 'Posting…' : 'Post Voucher (Alt+S)',
                        icon: Icons.check_circle_outline,
                        onPressed: _isSubmitting ? null : _submit,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoucherTypeButton extends StatelessWidget {
  final String label;
  final String subLabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _VoucherTypeButton({
    required this.label,
    required this.subLabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: KSpacing.borderRadiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? KColors.primary.withValues(alpha: 0.1) : KColors.surface,
            border: Border.all(
              color: isSelected ? KColors.primary : KColors.border,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: KSpacing.borderRadiusMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: KTypography.labelLarge.copyWith(
                  color: isSelected ? KColors.primary : KColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              KSpacing.vGapXs,
              Text(
                subLabel,
                style: KTypography.bodySmall.copyWith(
                  color: isSelected ? KColors.primary : KColors.textHint,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}