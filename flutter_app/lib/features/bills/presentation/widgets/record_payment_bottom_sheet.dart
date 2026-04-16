import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/bill_dto.dart';
import '../../data/bill_providers.dart';
import '../../data/bill_repository.dart';

/// Shows a modal bottom sheet to record a vendor payment against a bill.
///
/// Pre-fills the amount with the bill's balance due. On success, invalidates
/// both the bill detail and bill list providers so the UI refreshes.
Future<void> showRecordPaymentSheet(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> bill,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _RecordPaymentSheet(
      bill: bill,
      parentContext: context,
      ref: ref,
    ),
  );
}

class _RecordPaymentSheet extends StatefulWidget {
  final Map<String, dynamic> bill;
  final BuildContext parentContext;
  final WidgetRef ref;

  const _RecordPaymentSheet({
    required this.bill,
    required this.parentContext,
    required this.ref,
  });

  @override
  State<_RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<_RecordPaymentSheet> {
  late final TextEditingController _amountCtl;
  String _paymentMethod = 'BANK_TRANSFER';
  DateTime _paymentDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final b = BillDto(widget.bill);
    _amountCtl = TextEditingController(
      text: b.balanceDue.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = BillDto(widget.bill);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: KSpacing.md,
        right: KSpacing.md,
        top: KSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Record Payment', style: KTypography.h2),
          KSpacing.vGapSm,
          Text(
            'Bill: ${b.billNumber}',
            style: KTypography.bodySmall.copyWith(
              color: KColors.textSecondary,
            ),
          ),
          KSpacing.vGapXs,
          Text(
            'Balance: ${CurrencyFormatter.formatIndian(b.balanceDue)}',
            style: KTypography.bodySmall.copyWith(
              color: KColors.textSecondary,
            ),
          ),
          KSpacing.vGapMd,
          KTextField.amount(
            label: 'Amount',
            controller: _amountCtl,
          ),
          KSpacing.vGapMd,
          DropdownButtonFormField<String>(
            value: _paymentMethod,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(
                  value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
              DropdownMenuItem(value: 'CARD', child: Text('Card')),
            ],
            onChanged: (v) =>
                setState(() => _paymentMethod = v ?? 'BANK_TRANSFER'),
          ),
          KSpacing.vGapMd,
          KDatePicker(
            label: 'Payment Date',
            value: _paymentDate,
            onChanged: (d) => setState(() => _paymentDate = d),
          ),
          KSpacing.vGapLg,
          KButton(
            label: 'Record Payment',
            icon: Icons.check,
            fullWidth: true,
            isLoading: _isSubmitting,
            onPressed: _submit,
          ),
          KSpacing.vGapMd,
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtl.text) ?? 0;
    if (amount <= 0) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = widget.ref.read(billRepositoryProvider);
      final b = BillDto(widget.bill);
      await repo.recordPayment({
        'billId': b.id,
        'amount': amount,
        'paymentMethod': _paymentMethod,
        'paymentDate': _paymentDate.toIso8601String().split('T')[0],
      });
      widget.ref.invalidate(billDetailProvider(b.id));
      widget.ref.invalidate(billPaymentsProvider(b.id));
      widget.ref.invalidate(billListProvider);
      if (mounted) Navigator.pop(context);
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully')),
        );
      }
    } catch (_) {
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Failed to record payment')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
