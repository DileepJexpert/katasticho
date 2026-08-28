import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/k_colors.dart';
import '../../../core/theme/k_spacing.dart';
import '../../../core/theme/k_typography.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_card.dart';
import '../../../core/widgets/k_empty_state.dart';
import '../../../core/widgets/k_error_view.dart';
import '../../../core/widgets/k_loading.dart';
import '../../../core/widgets/k_money.dart';
import '../../../core/widgets/k_status_chip.dart';
import '../../../core/widgets/k_text_field.dart';
import '../../accounts/data/account_repository.dart';
import '../../contacts/presentation/contact_picker_sheet.dart';
import '../data/payout_models.dart';
import '../data/payout_repository.dart';

class PayoutDisbursementScreen extends ConsumerWidget {
  const PayoutDisbursementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payoutsAsync = ref.watch(payoutsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Direct Bank Payouts & Disbursements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(payoutsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.send_outlined),
            tooltip: 'Disburse Payout',
            onPressed: () => _showDisburseSheet(context, ref),
          ),
        ],
      ),
      body: payoutsAsync.when(
        loading: () => const KLoading(),
        error: (err, _) => KErrorView(
          message: 'Failed to load payouts: $err',
          onRetry: () => ref.invalidate(payoutsProvider),
        ),
        data: (payouts) {
          if (payouts.isEmpty) {
            return KEmptyState(
              icon: Icons.account_balance_outlined,
              title: 'No Payout Disbursements Yet',
              subtitle: 'Send direct IMPS/NEFT/UPI bank disbursements to vendors & employees.',
              actionLabel: 'Disburse First Payout',
              onAction: () => _showDisburseSheet(context, ref),
            );
          }

          return ListView.separated(
            padding: KSpacing.pagePadding,
            itemCount: payouts.length,
            separatorBuilder: (_, __) => KSpacing.vGapSm,
            itemBuilder: (context, i) => _PayoutCard(payout: payouts[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDisburseSheet(context, ref),
        icon: const Icon(Icons.send),
        label: const Text('Disburse Payout'),
      ),
    );
  }

  void _showDisburseSheet(BuildContext context, WidgetRef ref) {
    showDisbursePayoutModal(
      context,
      onDisbursed: () => ref.invalidate(payoutsProvider),
    );
  }
}

void showDisbursePayoutModal(
  BuildContext context, {
  Map<String, dynamic>? initialContact,
  String? initialBillId,
  String? initialBillNumber,
  double? initialAmount,
  VoidCallback? onDisbursed,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DisbursePayoutSheet(
      initialContact: initialContact,
      initialBillId: initialBillId,
      initialBillNumber: initialBillNumber,
      initialAmount: initialAmount,
      onDisbursed: onDisbursed ?? () {},
    ),
  );
}

class _PayoutCard extends StatelessWidget {
  final PayoutDisbursementModel payout;
  const _PayoutCard({required this.payout});

  @override
  Widget build(BuildContext context) {
    final isProcessed = payout.status == 'PROCESSED';

    return KCard(
      padding: const EdgeInsets.all(KSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  payout.beneficiaryName ?? payout.contactName,
                  style: KTypography.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              KMoney(
                payout.amount,
                style: KTypography.amountMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          KSpacing.vGapXs,
          Row(
            children: [
              KStatusChip(
                status: isProcessed ? 'PAID' : payout.status,
                label: isProcessed ? 'Disbursed' : payout.status,
              ),
              KSpacing.hGapSm,
              Text(
                '•  ${payout.payoutMode}',
                style: KTypography.caption.copyWith(fontWeight: FontWeight.w600),
              ),
              if (payout.utr != null) ...[
                KSpacing.hGapSm,
                Expanded(
                  child: Text(
                    'UTR: ${payout.utr}',
                    style: KTypography.mono(fontSize: 11, color: KColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          KSpacing.vGapXs,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (payout.accountNumberMasked != null)
                Text.rich(
                  TextSpan(
                    style: KTypography.caption.copyWith(color: KColors.textSecondary),
                    children: [
                      const TextSpan(text: 'A/C: '),
                      TextSpan(text: payout.accountNumberMasked, style: KTypography.mono(fontSize: 12)),
                      TextSpan(text: ' (${payout.ifscCode ?? 'IFSC'})'),
                    ],
                  ),
                )
              else if (payout.vpa != null)
                Text.rich(
                  TextSpan(
                    style: KTypography.caption.copyWith(color: KColors.textSecondary),
                    children: [
                      const TextSpan(text: 'UPI: '),
                      TextSpan(text: payout.vpa, style: KTypography.mono(fontSize: 12)),
                    ],
                  ),
                ),
              if (payout.createdAt != null)
                Text(
                  payout.createdAt!.split('T').first,
                  style: KTypography.caption.copyWith(color: KColors.textHint),
                ),
            ],
          ),
          if (payout.vendorPaymentId != null) ...[
            KSpacing.vGapXs,
            Text(
              '✓ Auto-booked in Accounts Payable & Journal',
              style: KTypography.caption.copyWith(color: KColors.success, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisbursePayoutSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialContact;
  final String? initialBillId;
  final String? initialBillNumber;
  final double? initialAmount;
  final VoidCallback onDisbursed;

  const _DisbursePayoutSheet({
    this.initialContact,
    this.initialBillId,
    this.initialBillNumber,
    this.initialAmount,
    required this.onDisbursed,
  });

  @override
  ConsumerState<_DisbursePayoutSheet> createState() => _DisbursePayoutSheetState();
}

class _DisbursePayoutSheetState extends ConsumerState<_DisbursePayoutSheet> {
  Map<String, dynamic>? _selectedContact;
  AccountDto? _selectedBankAcc;
  late final TextEditingController _amountCtl;
  late final TextEditingController _accNoCtl;
  late final TextEditingController _ifscCtl;
  late final TextEditingController _vpaCtl;
  late final TextEditingController _narrationCtl;
  String _payoutMode = 'IMPS';
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedContact = widget.initialContact;
    _amountCtl = TextEditingController(
      text: widget.initialAmount != null && widget.initialAmount! > 0
          ? widget.initialAmount!.toStringAsFixed(2)
          : '',
    );
    _accNoCtl = TextEditingController(
      text: widget.initialContact?['bankAccountNo']?.toString() ?? '',
    );
    _ifscCtl = TextEditingController(
      text: widget.initialContact?['bankIfsc']?.toString() ?? '',
    );
    _vpaCtl = TextEditingController(
      text: widget.initialContact?['upiId']?.toString() ?? '',
    );
    _narrationCtl = TextEditingController(
      text: widget.initialBillNumber != null
          ? 'Disbursement for Bill #${widget.initialBillNumber}'
          : 'Vendor Payment Disbursement',
    );
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    _accNoCtl.dispose();
    _ifscCtl.dispose();
    _vpaCtl.dispose();
    _narrationCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedContact == null) {
      setState(() => _error = 'Please select a vendor beneficiary');
      return;
    }
    final amount = double.tryParse(_amountCtl.text) ?? 0.0;
    if (amount <= 0) {
      setState(() => _error = 'Please enter a valid disbursement amount');
      return;
    }
    if (_selectedBankAcc == null) {
      setState(() => _error = 'Please select paid-through bank account');
      return;
    }

    final accNo = _accNoCtl.text.trim();
    final ifsc = _ifscCtl.text.trim();
    final vpa = _vpaCtl.text.trim();

    if ((accNo.isEmpty || ifsc.isEmpty) && vpa.isEmpty) {
      setState(() => _error = 'Enter beneficiary Bank Account + IFSC or UPI ID');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final req = PayoutDisbursementRequestPayload(
        contactId: _selectedContact!['id'].toString(),
        amount: amount,
        paidThroughAccountId: _selectedBankAcc!.id,
        payoutMode: _payoutMode,
        beneficiaryName: _selectedContact!['displayName']?.toString() ?? _selectedContact!['name']?.toString(),
        accountNumber: accNo.isNotEmpty ? accNo : null,
        ifscCode: ifsc.isNotEmpty ? ifsc : null,
        vpa: vpa.isNotEmpty ? vpa : null,
        narration: _narrationCtl.text.trim(),
        billAllocations: widget.initialBillId != null
            ? [BillAllocationPayload(billId: widget.initialBillId!, amountApplied: amount)]
            : null,
      );

      final res = await ref.read(payoutRepositoryProvider).disburse(req);
      if (!mounted) return;
      Navigator.pop(context);
      widget.onDisbursed();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Disbursement ${res.status}: UTR ${res.utr ?? res.providerPayoutId}'),
          backgroundColor: KColors.success,
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Payout failed: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: KSpacing.lg,
        right: KSpacing.lg,
        top: KSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Direct Bank Disbursement', style: KTypography.h3),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            KSpacing.vGapXs,
            Text(
              'Instantly transfer funds via RazorpayX / Cashfree corporate payout gateway with zero manual bank portal login.',
              style: KTypography.caption.copyWith(color: KColors.textSecondary),
            ),
            KSpacing.vGapMd,

            if (_error != null) ...[
              Text(_error!, style: TextStyle(color: KColors.error, fontSize: 12)),
              KSpacing.vGapSm,
            ],

            // Vendor Picker
            InkWell(
              onTap: () async {
                final picked = await showContactPicker(context, contactType: 'VENDOR');
                if (picked != null) {
                  setState(() {
                    _selectedContact = picked;
                    if (picked['bankAccountNo'] != null) _accNoCtl.text = picked['bankAccountNo'].toString();
                    if (picked['bankIfsc'] != null) _ifscCtl.text = picked['bankIfsc'].toString();
                    if (picked['upiId'] != null) _vpaCtl.text = picked['upiId'].toString();
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Beneficiary / Vendor *'),
                child: Text(
                  _selectedContact?['displayName']?.toString() ??
                      _selectedContact?['name']?.toString() ??
                      'Tap to pick vendor',
                  style: _selectedContact == null
                      ? KTypography.bodySmall.copyWith(color: KColors.textSecondary)
                      : KTypography.bodyMedium,
                ),
              ),
            ),
            KSpacing.vGapSm,

            // Paid Through Account Picker
            accountsAsync.when(
              loading: () => const KLoading(),
              error: (_, __) => const SizedBox.shrink(),
              data: (accounts) {
                final bankAccounts = accounts.where((a) {
                  return a.code.startsWith('10') || a.type == 'ASSET' || a.type == 'BANK';
                }).toList();

                return DropdownButtonFormField<String>(
                  initialValue: _selectedBankAcc?.id,
                  decoration: const InputDecoration(labelText: 'Paid Through Account *'),
                  items: bankAccounts.map((a) {
                    return DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.code} - ${a.name}'),
                    );
                  }).toList(),
                  onChanged: (id) {
                    setState(() {
                      _selectedBankAcc = bankAccounts.firstWhere((a) => a.id == id);
                    });
                  },
                );
              },
            ),
            KSpacing.vGapSm,

            Row(
              children: [
                Expanded(
                  child: KTextField(
                    label: 'Amount to Disburse (₹) *',
                    controller: _amountCtl,
                    keyboardType: TextInputType.number,
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _payoutMode,
                    decoration: const InputDecoration(labelText: 'Payout Mode'),
                    items: const [
                      DropdownMenuItem(value: 'IMPS', child: Text('IMPS (Instant 24x7)')),
                      DropdownMenuItem(value: 'NEFT', child: Text('NEFT')),
                      DropdownMenuItem(value: 'RTGS', child: Text('RTGS (Large Value)')),
                      DropdownMenuItem(value: 'UPI', child: Text('UPI (VPA)')),
                    ],
                    onChanged: (v) => setState(() => _payoutMode = v!),
                  ),
                ),
              ],
            ),
            KSpacing.vGapSm,

            if (_payoutMode == 'UPI') ...[
              KTextField(label: 'UPI ID / VPA *', hint: 'e.g. vendor@okhdfcbank', controller: _vpaCtl),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: KTextField(
                      label: 'Account Number *',
                      hint: 'Beneficiary Bank A/C',
                      controller: _accNoCtl,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  KSpacing.hGapSm,
                  Expanded(
                    child: KTextField(
                      label: 'IFSC Code *',
                      hint: 'e.g. HDFC0001234',
                      controller: _ifscCtl,
                    ),
                  ),
                ],
              ),
            ],
            KSpacing.vGapSm,

            KTextField(
              label: 'Narration / Payment Purpose',
              controller: _narrationCtl,
            ),
            KSpacing.vGapLg,

            KButton(
              label: _isSubmitting ? 'Disbursing via Gateway...' : 'Disburse Instant Payout',
              icon: Icons.flash_on,
              isLoading: _isSubmitting,
              onPressed: _submit,
              fullWidth: true,
            ),
            KSpacing.vGapLg,
          ],
        ),
      ),
    );
  }
}
