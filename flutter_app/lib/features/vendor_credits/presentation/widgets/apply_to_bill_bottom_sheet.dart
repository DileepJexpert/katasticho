import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../bills/data/bill_dto.dart';
import '../../data/vendor_credit_dto.dart';
import '../../data/vendor_credit_providers.dart';
import '../../data/vendor_credit_repository.dart';

/// Shows a modal bottom sheet to apply a vendor credit to an outstanding bill.
///
/// Loads the vendor's OPEN bills via [VendorCreditRepository.listVendorBills],
/// lets the user pick a bill and enter an amount, then calls [applyToBill].
Future<void> showApplyToBillSheet(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> credit,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ApplyToBillSheet(
      credit: credit,
      parentContext: context,
      ref: ref,
    ),
  );
}

class _ApplyToBillSheet extends StatefulWidget {
  final Map<String, dynamic> credit;
  final BuildContext parentContext;
  final WidgetRef ref;

  const _ApplyToBillSheet({
    required this.credit,
    required this.parentContext,
    required this.ref,
  });

  @override
  State<_ApplyToBillSheet> createState() => _ApplyToBillSheetState();
}

class _ApplyToBillSheetState extends State<_ApplyToBillSheet> {
  late final TextEditingController _amountCtl;
  List<Map<String, dynamic>> _bills = [];
  bool _loadingBills = true;
  String? _selectedBillId;
  String _selectedBillNumber = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final c = VendorCreditDto(widget.credit);
    _amountCtl = TextEditingController(
      text: c.balance.toStringAsFixed(2),
    );
    _loadBills(c.contactId);
  }

  @override
  void dispose() {
    _amountCtl.dispose();
    super.dispose();
  }

  Future<void> _loadBills(String contactId) async {
    try {
      final repo = widget.ref.read(vendorCreditRepositoryProvider);
      final result = await repo.listVendorBills(contactId);
      final content = result['data'];
      final list = content is List
          ? content.cast<Map<String, dynamic>>()
          : (content is Map
              ? ((content['content'] as List?)
                      ?.cast<Map<String, dynamic>>() ??
                  [])
              : <Map<String, dynamic>>[]);
      if (mounted) {
        setState(() {
          _bills = list;
          _loadingBills = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBills = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = VendorCreditDto(widget.credit);

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
          Text('Apply to Bill', style: KTypography.h2),
          KSpacing.vGapSm,
          Text(
            'Credit: ${c.creditNumber}',
            style: KTypography.bodySmall.copyWith(
              color: KColors.textSecondary,
            ),
          ),
          KSpacing.vGapXs,
          Text(
            'Available: ${CurrencyFormatter.formatIndian(c.balance)}',
            style: KTypography.bodySmall.copyWith(
              color: KColors.textSecondary,
            ),
          ),
          KSpacing.vGapMd,

          // Bill selector
          Text('Select Bill', style: KTypography.labelLarge),
          KSpacing.vGapSm,

          if (_loadingBills)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_bills.isEmpty)
            Container(
              padding: const EdgeInsets.all(KSpacing.md),
              decoration: BoxDecoration(
                color: KColors.surface,
                borderRadius: KSpacing.borderRadiusMd,
                border: Border.all(color: KColors.divider),
              ),
              child: Text(
                'No open bills for this vendor',
                style: KTypography.bodyMedium.copyWith(
                  color: KColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _bills.length,
                itemBuilder: (context, index) {
                  final bill = _bills[index];
                  final b = BillDto(bill);
                  final isSelected = _selectedBillId == b.id;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedBillId = b.id;
                        _selectedBillNumber = b.billNumber;
                        // Pre-fill with the lesser of credit balance or bill balance
                        final maxApply =
                            c.balance < b.balanceDue ? c.balance : b.balanceDue;
                        _amountCtl.text = maxApply.toStringAsFixed(2);
                      });
                    },
                    borderRadius: KSpacing.borderRadiusMd,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? KColors.primary.withValues(alpha: 0.06)
                            : KColors.surface,
                        borderRadius: KSpacing.borderRadiusMd,
                        border: Border.all(
                          color:
                              isSelected ? KColors.primary : KColors.divider,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.billNumber,
                                    style: KTypography.labelLarge),
                                KSpacing.vGapXs,
                                Text(
                                  'Due: ${CurrencyFormatter.formatIndian(b.balanceDue)}',
                                  style: KTypography.bodySmall.copyWith(
                                    color: KColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatIndian(b.totalAmount),
                            style: KTypography.amountSmall,
                          ),
                          if (isSelected) ...[
                            KSpacing.hGapSm,
                            const Icon(Icons.check_circle,
                                color: KColors.primary, size: 20),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          KSpacing.vGapMd,
          KTextField.amount(
            label: 'Amount to Apply',
            controller: _amountCtl,
          ),
          KSpacing.vGapLg,
          KButton(
            label: 'Apply Credit',
            icon: Icons.check,
            fullWidth: true,
            isLoading: _isSubmitting,
            onPressed: _bills.isEmpty ? null : _submit,
          ),
          KSpacing.vGapMd,
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtl.text) ?? 0;
    if (amount <= 0 || _selectedBillId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = widget.ref.read(vendorCreditRepositoryProvider);
      final c = VendorCreditDto(widget.credit);
      await repo.applyToBill(c.id, _selectedBillId!, amount);
      widget.ref.invalidate(vendorCreditDetailProvider(c.id));
      widget.ref.invalidate(vendorCreditListProvider);
      if (mounted) Navigator.pop(context);
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          SnackBar(
            content: Text(
              'Applied ${CurrencyFormatter.formatIndian(amount)} to $_selectedBillNumber',
            ),
          ),
        );
      }
    } catch (_) {
      if (widget.parentContext.mounted) {
        ScaffoldMessenger.of(widget.parentContext).showSnackBar(
          const SnackBar(content: Text('Failed to apply credit')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
