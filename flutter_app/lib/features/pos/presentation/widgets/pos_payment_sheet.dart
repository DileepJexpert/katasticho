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
/// Pass paymentMode='SPLIT' to open split payment mode directly.
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
      child: paymentMode == 'SPLIT'
          ? _SplitPaymentContent(cart: cart)
          : _PaymentSheetContent(cart: cart, paymentMode: paymentMode),
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
            color: KColors.secondary.withValues(alpha: 0.10),
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

/// Split payment sheet — allows distributing total across Cash, UPI, Card.
class _SplitPaymentContent extends StatefulWidget {
  final PosCartState cart;
  const _SplitPaymentContent({required this.cart});

  @override
  State<_SplitPaymentContent> createState() => _SplitPaymentContentState();
}

class _SplitPaymentContentState extends State<_SplitPaymentContent> {
  final _cashCtrl = TextEditingController(text: '0.00');
  final _upiCtrl = TextEditingController(text: '0.00');
  final _cardCtrl = TextEditingController(text: '0.00');
  final _upiRefCtrl = TextEditingController();

  double get _cash => double.tryParse(_cashCtrl.text) ?? 0;
  double get _upi => double.tryParse(_upiCtrl.text) ?? 0;
  double get _card => double.tryParse(_cardCtrl.text) ?? 0;
  double get _splitSum => _cash + _upi + _card;
  double get _remaining => widget.cart.total - _splitSum;

  @override
  void dispose() {
    _cashCtrl.dispose();
    _upiCtrl.dispose();
    _cardCtrl.dispose();
    _upiRefCtrl.dispose();
    super.dispose();
  }

  void _autoFill(String mode) {
    final total = widget.cart.total;
    setState(() {
      switch (mode) {
        case 'CASH':
          _cashCtrl.text = (total - _upi - _card).clamp(0, total).toStringAsFixed(2);
        case 'UPI':
          _upiCtrl.text = (total - _cash - _card).clamp(0, total).toStringAsFixed(2);
        case 'CARD':
          _cardCtrl.text = (total - _cash - _upi).clamp(0, total).toStringAsFixed(2);
      }
    });
  }

  void _complete() {
    if (_splitSum < widget.cart.total - 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Split total (${CurrencyFormatter.formatIndian(_splitSum)}) is less than bill total'),
          backgroundColor: KColors.error,
        ),
      );
      return;
    }

    final splits = <Map<String, dynamic>>[];
    if (_cash > 0) splits.add({'mode': 'CASH', 'amount': _cash});
    if (_upi > 0) {
      splits.add({
        'mode': 'UPI',
        'amount': _upi,
        if (_upiRefCtrl.text.trim().isNotEmpty) 'reference': _upiRefCtrl.text.trim(),
      });
    }
    if (_card > 0) splits.add({'mode': 'CARD', 'amount': _card});

    final primary = splits.reduce((a, b) =>
        (a['amount'] as double) >= (b['amount'] as double) ? a : b);

    Navigator.pop(context, {
      'paymentMode': primary['mode'],
      'amountReceived': _splitSum,
      'upiReference': _upiRefCtrl.text.trim().isEmpty ? null : _upiRefCtrl.text.trim(),
      'splits': splits,
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
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            KSpacing.vGapMd,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Split Payment', style: KTypography.h3),
                Text('Total ${CurrencyFormatter.formatIndian(total)}',
                    style: KTypography.labelLarge.copyWith(color: cs.primary)),
              ],
            ),
            KSpacing.vGapLg,
            _SplitRow(
              icon: Icons.payments_outlined,
              label: 'Cash',
              color: KColors.success,
              controller: _cashCtrl,
              onChanged: (_) => setState(() {}),
              onAutoFill: () => _autoFill('CASH'),
            ),
            KSpacing.vGapSm,
            _SplitRow(
              icon: Icons.qr_code_2,
              label: 'UPI',
              color: KColors.primary,
              controller: _upiCtrl,
              onChanged: (_) => setState(() {}),
              onAutoFill: () => _autoFill('UPI'),
            ),
            if (_upi > 0) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: KTextField(
                  label: 'UPI Reference',
                  hint: 'UTR / Transaction ID',
                  controller: _upiRefCtrl,
                  keyboardType: TextInputType.text,
                  prefixIcon: Icons.tag,
                ),
              ),
            ],
            KSpacing.vGapSm,
            _SplitRow(
              icon: Icons.credit_card,
              label: 'Card',
              color: KColors.secondary,
              controller: _cardCtrl,
              onChanged: (_) => setState(() {}),
              onAutoFill: () => _autoFill('CARD'),
            ),
            KSpacing.vGapMd,
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _remaining.abs() < 0.01
                    ? KColors.successLight
                    : KColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _remaining.abs() < 0.01 ? 'Fully covered' : 'Remaining',
                    style: KTypography.labelMedium.copyWith(
                      color: _remaining.abs() < 0.01
                          ? KColors.success
                          : KColors.warning,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.formatIndian(_remaining.abs() < 0.01 ? 0 : _remaining),
                    style: KTypography.h3.copyWith(
                      color: _remaining.abs() < 0.01
                          ? KColors.success
                          : KColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            KSpacing.vGapLg,
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _splitSum >= total - 0.01 ? _complete : null,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('Complete Split Payment',
                    style: KTypography.labelLarge
                        .copyWith(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onAutoFill;

  const _SplitRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.controller,
    required this.onChanged,
    required this.onAutoFill,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        SizedBox(
          width: 48,
          child: Text(label, style: KTypography.labelMedium),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: KTextField.amount(
            label: '',
            controller: controller,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.auto_fix_high, size: 18),
          onPressed: onAutoFill,
          tooltip: 'Fill remaining',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
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
