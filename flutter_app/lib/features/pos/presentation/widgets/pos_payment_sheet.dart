import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/pos_cart_state.dart';

/// Payment bottom sheet — different content per payment mode.
/// Returns a map with payment details on completion, or null if cancelled.
Future<Map<String, dynamic>?> showPosPaymentSheet(
  BuildContext context, {
  required PosCartState cart,
  required String paymentMode,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: _PaymentSheetContent(cart: cart, paymentMode: paymentMode),
    ),
  );
}

class _PaymentSheetContent extends StatefulWidget {
  final PosCartState cart;
  final String paymentMode;

  const _PaymentSheetContent({
    required this.cart,
    required this.paymentMode,
  });

  @override
  State<_PaymentSheetContent> createState() => _PaymentSheetContentState();
}

class _PaymentSheetContentState extends State<_PaymentSheetContent> {
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late double _amountReceived;

  @override
  void initState() {
    super.initState();
    final total = widget.cart.total;
    _amountReceived = total;
    _amountController = TextEditingController(
      text: total.toStringAsFixed(2),
    );
    _referenceController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String value) {
    setState(() {
      _amountReceived = double.tryParse(value) ?? 0;
    });
  }

  void _setQuickAmount(double amount) {
    setState(() {
      _amountReceived = amount;
      _amountController.text = amount.toStringAsFixed(2);
    });
  }

  void _complete() {
    final total = widget.cart.total;
    if (widget.paymentMode == 'CASH' && _amountReceived < total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount received must be at least the total'),
          backgroundColor: KColors.error,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'paymentMode': widget.paymentMode,
      'amountReceived': _amountReceived,
      'upiReference': _referenceController.text.trim().isEmpty
          ? null
          : _referenceController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.cart.total;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            KSpacing.vGapMd,

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_modeIcon(widget.paymentMode),
                        color: _modeColor(widget.paymentMode)),
                    const SizedBox(width: 8),
                    Text(
                      '${_modeLabel(widget.paymentMode)} Payment',
                      style: KTypography.h3,
                    ),
                  ],
                ),
                Text(
                  'Total ${CurrencyFormatter.formatIndian(total)}',
                  style: KTypography.labelLarge.copyWith(color: cs.primary),
                ),
              ],
            ),
            KSpacing.vGapLg,

            // Mode-specific content
            if (widget.paymentMode == 'CASH') _buildCashContent(total),
            if (widget.paymentMode == 'UPI') _buildUpiContent(total),
            if (widget.paymentMode == 'CARD') _buildCardContent(),

            KSpacing.vGapLg,

            // Complete button
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _complete,
                style: FilledButton.styleFrom(
                  backgroundColor: _modeColor(widget.paymentMode),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _completeLabel(widget.paymentMode),
                  style: KTypography.labelLarge
                      .copyWith(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashContent(double total) {
    final change = _amountReceived - total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cash received', style: KTypography.labelMedium),
        KSpacing.vGapSm,
        KTextField.amount(
          label: 'Amount',
          controller: _amountController,
          onChanged: _onAmountChanged,
        ),
        KSpacing.vGapMd,

        // Quick amount buttons
        Text('Quick amounts', style: KTypography.labelSmall.copyWith(
          color: KColors.textSecondary,
        )),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _quickButton(_roundUp(total, 100)),
            _quickButton(_roundUp(total, 500)),
            _quickButton(_roundUp(total, 1000)),
            _QuickAmountChip(
              label: 'Exact',
              onTap: () => _setQuickAmount(total),
              isSelected: _amountReceived == total,
            ),
          ],
        ),
        KSpacing.vGapMd,

        // Change display
        if (change > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KColors.successLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Change to return',
                    style: KTypography.labelMedium
                        .copyWith(color: KColors.success)),
                Text(
                  CurrencyFormatter.formatIndian(change),
                  style: KTypography.h3.copyWith(color: KColors.success),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _quickButton(double amount) {
    return _QuickAmountChip(
      label: CurrencyFormatter.formatIndian(amount),
      onTap: () => _setQuickAmount(amount),
      isSelected: _amountReceived == amount,
    );
  }

  Widget _buildUpiContent(double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Amount display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: KColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.qr_code_2, size: 48, color: KColors.primary),
              KSpacing.vGapSm,
              Text(
                CurrencyFormatter.formatIndian(total),
                style: KTypography.h2.copyWith(
                  color: KColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Collect via UPI',
                style: KTypography.bodySmall.copyWith(
                  color: KColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // Reference field
        Text('Reference (optional)', style: KTypography.labelMedium),
        KSpacing.vGapSm,
        KTextField(
          label: 'UTR / Reference number',
          hint: 'Enter UTR or transaction reference',
          controller: _referenceController,
          keyboardType: TextInputType.text,
          prefixIcon: Icons.tag,
        ),
      ],
    );
  }

  Widget _buildCardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card terminal prompt
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: KColors.secondarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(Icons.credit_card, size: 48, color: KColors.secondary),
              KSpacing.vGapSm,
              Text(
                'Swipe card on POS terminal',
                style: KTypography.labelLarge
                    .copyWith(color: KColors.textSecondary),
              ),
            ],
          ),
        ),
        KSpacing.vGapMd,

        // Auth code field
        Text('Auth code / Reference', style: KTypography.labelMedium),
        KSpacing.vGapSm,
        KTextField(
          label: 'Auth code',
          hint: 'Enter terminal auth code',
          controller: _referenceController,
          keyboardType: TextInputType.text,
          prefixIcon: Icons.pin,
        ),
      ],
    );
  }

  double _roundUp(double amount, double step) {
    return (amount / step).ceil() * step.toDouble();
  }

  IconData _modeIcon(String mode) => switch (mode) {
        'CASH' => Icons.payments_outlined,
        'UPI' => Icons.qr_code_2,
        'CARD' => Icons.credit_card,
        _ => Icons.payment,
      };

  Color _modeColor(String mode) => switch (mode) {
        'CASH' => KColors.success,
        'UPI' => KColors.primary,
        'CARD' => KColors.secondary,
        _ => KColors.primary,
      };

  String _modeLabel(String mode) => switch (mode) {
        'CASH' => 'Cash',
        'UPI' => 'UPI',
        'CARD' => 'Card',
        _ => mode,
      };

  String _completeLabel(String mode) => switch (mode) {
        'CASH' => 'Complete Sale',
        'UPI' => 'Mark as Received & Complete',
        'CARD' => 'Confirm Payment & Complete',
        _ => 'Complete Sale',
      };
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _QuickAmountChip({
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: isSelected
          ? cs.primary.withValues(alpha: 0.12)
          : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: KTypography.labelMedium.copyWith(
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
