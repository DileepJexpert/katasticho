import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_config.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/bill_dto.dart';
import '../../data/bill_providers.dart';
import '../../data/bill_repository.dart';
import '../../../vendor_payments/data/vendor_payment_providers.dart';

final _paidThroughAccountsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final resp = await api.get(ApiConfig.chartOfAccounts);
  final data = (resp.data as Map<String, dynamic>)['data'];
  if (data is! List) return <Map<String, dynamic>>[];
  return data.cast<Map<String, dynamic>>().where((a) {
    final subType = a['subType'] as String? ?? '';
    final name = (a['name'] as String? ?? '').toLowerCase();
    return subType == 'CURRENT_ASSET' ||
        subType == 'BANK' ||
        name.contains('cash') ||
        name.contains('bank');
  }).toList();
});

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
    ),
  );
}

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> bill;
  final BuildContext parentContext;

  const _RecordPaymentSheet({
    required this.bill,
    required this.parentContext,
  });

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  late final TextEditingController _amountCtl;
  String _paymentMode = 'BANK_TRANSFER';
  String? _paidThroughId;
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
    final accountsAsync = ref.watch(_paidThroughAccountsProvider);

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
            value: _paymentMode,
            decoration: const InputDecoration(labelText: 'Payment Mode'),
            items: const [
              DropdownMenuItem(value: 'CASH', child: Text('Cash')),
              DropdownMenuItem(
                  value: 'BANK_TRANSFER', child: Text('Bank Transfer')),
              DropdownMenuItem(value: 'UPI', child: Text('UPI')),
              DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque')),
              DropdownMenuItem(value: 'CARD', child: Text('Card')),
            ],
            onChanged: (v) =>
                setState(() => _paymentMode = v ?? 'BANK_TRANSFER'),
          ),
          KSpacing.vGapMd,
          accountsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => Text(
              'Failed to load accounts',
              style: KTypography.bodySmall.copyWith(color: KColors.error),
            ),
            data: (accounts) => DropdownButtonFormField<String>(
              value: _paidThroughId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Paid through *'),
              items: accounts.map((a) {
                return DropdownMenuItem<String>(
                  value: a['id']?.toString(),
                  child: Text(
                    '${a['code']} — ${a['name']}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _paidThroughId = v),
            ),
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
            onPressed: _paidThroughId == null ? null : _submit,
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
      final repo = ref.read(billRepositoryProvider);
      final b = BillDto(widget.bill);
      await repo.recordPayment({
        'contactId': b.contactId,
        'amount': amount,
        'paymentMode': _paymentMode,
        'paymentDate': _paymentDate.toIso8601String().split('T')[0],
        'paidThroughId': _paidThroughId,
        'allocations': [
          {
            'billId': b.id,
            'amountApplied': amount,
          },
        ],
      });
      ref.invalidate(billDetailProvider(b.id));
      ref.invalidate(billPaymentsProvider(b.id));
      ref.invalidate(billListProvider);
      ref.invalidate(vendorPaymentListProvider);
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
