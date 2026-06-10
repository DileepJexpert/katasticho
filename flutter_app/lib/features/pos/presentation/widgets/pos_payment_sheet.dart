import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/pos_cart_state.dart';
import '../../data/pos_providers.dart';

const double _maxTenderAmount = 999999.99;
const int _maxTenderInputLength = 9;

/// Payment bottom sheet — different content per payment mode.
/// Returns a map with payment details on completion, or null if cancelled.
/// Pass paymentMode='SPLIT' to open split payment mode directly.
Future<Map<String, dynamic>?> showPosPaymentSheet(
  BuildContext context, {
  required PosCartState cart,
  required String paymentMode,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: true,
    builder: (context) {
      final media = MediaQuery.of(context);
      final maxWidth = media.size.width >= 720 ? 640.0 : media.size.width - 24;
      final maxHeight = media.size.height - media.viewInsets.vertical - 48;
      final safeMaxHeight = maxHeight < 320 ? 320.0 : maxHeight;

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: safeMaxHeight,
          ),
          child: IntrinsicHeight(
            child: Padding(
              padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
              child: paymentMode == 'SPLIT'
                  ? _SplitPaymentContent(
                      cart: cart,
                    )
                  : _PaymentSheetContent(
                      cart: cart,
                      paymentMode: paymentMode,
                    ),
            ),
          ),
        ),
      );
    },
  );
}

class _PaymentSheetContent extends ConsumerStatefulWidget {
  final PosCartState cart;
  final String paymentMode;

  const _PaymentSheetContent({
    required this.cart,
    required this.paymentMode,
  });

  @override
  ConsumerState<_PaymentSheetContent> createState() =>
      _PaymentSheetContentState();
}

class _PaymentSheetContentState extends ConsumerState<_PaymentSheetContent> {
  late final TextEditingController _amountController;
  late final TextEditingController _referenceController;
  late double _amountReceived;
  String? _amountError;
  bool _gstInvoice = false;

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
    final amount = double.tryParse(value) ?? 0;
    setState(() {
      _amountReceived = amount;
      _amountError = amount > _maxTenderAmount
          ? 'Maximum allowed is ${CurrencyFormatter.formatIndian(_maxTenderAmount)}'
          : null;
    });
  }

  void _setQuickAmount(double amount) {
    setState(() {
      _amountReceived = amount;
      _amountController.text = amount.toStringAsFixed(2);
      _amountError = null;
    });
  }

  void _complete() {
    final total = widget.cart.total;
    if (_amountReceived > _maxTenderAmount) {
      setState(() {
        _amountError =
            'Maximum allowed is ${CurrencyFormatter.formatIndian(_maxTenderAmount)}';
      });
      return;
    }
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
      'gstInvoice': _gstInvoice,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.cart.total;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            KSpacing.vGapSm,
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
                      style: KTypography.h4,
                    ),
                  ],
                ),
                Text(
                  'Total ${CurrencyFormatter.formatIndian(total)}',
                  style: KTypography.labelLarge.copyWith(color: cs.primary),
                ),
              ],
            ),
            KSpacing.vGapSm,
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MarginHintBanner(cart: widget.cart),
                    const SizedBox(height: 8),
                    if (widget.paymentMode == 'CASH') _buildCashContent(total),
                    if (widget.paymentMode == 'UPI') _buildUpiContent(total),
                    if (widget.paymentMode == 'CARD') _buildCardContent(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            _GstInvoiceToggle(
              value: _gstInvoice,
              onChanged: (v) => setState(() => _gstInvoice = v),
            ),
            KSpacing.vGapSm,
            SizedBox(
              height: 48,
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
          maxLength: _maxTenderInputLength,
          onChanged: _onAmountChanged,
        ),
        if (_amountError != null) ...[
          const SizedBox(height: 6),
          Text(
            _amountError!,
            style: KTypography.labelSmall.copyWith(color: KColors.error),
          ),
        ],
        KSpacing.vGapSm,

        // Quick amount buttons
        Text('Quick amounts',
            style: KTypography.labelSmall.copyWith(
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
        KSpacing.vGapSm,

        // Change display
        if (change > 0)
          Container(
            padding: const EdgeInsets.all(10),
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
    final upiAsync = ref.watch(upiSettingsProvider);
    final upiSettings = upiAsync.valueOrNull ?? {};
    final upiId = upiSettings['upiId'] ?? '';
    final displayName = upiSettings['displayName'] ?? '';
    final hasUpi = upiId.isNotEmpty;

    final amountStr = total.toStringAsFixed(2);
    final qrData = hasUpi
        ? 'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(displayName)}&am=$amountStr&cu=INR'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: KColors.primarySoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: hasUpi
              ? Column(
                  children: [
                    QrImageView(
                      data: qrData!,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatIndian(total),
                      style: KTypography.h3.copyWith(
                        color: KColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (displayName.isNotEmpty)
                      Text(
                        displayName,
                        style: KTypography.bodySmall
                            .copyWith(color: KColors.textSecondary),
                      ),
                    Text(
                      upiId,
                      style: KTypography.labelSmall.copyWith(
                          color: KColors.textHint, fontSize: 10),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2, size: 30, color: KColors.primary),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CurrencyFormatter.formatIndian(total),
                          style: KTypography.h3.copyWith(
                            color: KColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Collect via UPI',
                          style: KTypography.bodySmall
                              .copyWith(color: KColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
        if (!hasUpi) ...[
          const SizedBox(height: 6),
          Text(
            'Set up UPI ID in POS settings to show QR code',
            style: KTypography.labelSmall
                .copyWith(color: KColors.textHint, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
        KSpacing.vGapSm,
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: KColors.secondary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.credit_card, size: 30, color: KColors.secondary),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Swipe card on POS terminal',
                  style: KTypography.labelLarge
                      .copyWith(color: KColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        KSpacing.vGapSm,

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

  const _SplitPaymentContent({
    required this.cart,
  });

  @override
  State<_SplitPaymentContent> createState() => _SplitPaymentContentState();
}

class _SplitPaymentContentState extends State<_SplitPaymentContent> {
  final _cashCtrl = TextEditingController(text: '0.00');
  final _upiCtrl = TextEditingController(text: '0.00');
  final _cardCtrl = TextEditingController(text: '0.00');
  final _upiRefCtrl = TextEditingController();
  bool _gstInvoice = false;

  double get _cash => double.tryParse(_cashCtrl.text) ?? 0;
  double get _upi => double.tryParse(_upiCtrl.text) ?? 0;
  double get _card => double.tryParse(_cardCtrl.text) ?? 0;
  double get _splitSum => _cash + _upi + _card;
  double get _remaining => widget.cart.total - _splitSum;
  bool get _hasSplitLimitError =>
      _cash > _maxTenderAmount ||
      _upi > _maxTenderAmount ||
      _card > _maxTenderAmount;

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
          _cashCtrl.text =
              (total - _upi - _card).clamp(0, total).toStringAsFixed(2);
        case 'UPI':
          _upiCtrl.text =
              (total - _cash - _card).clamp(0, total).toStringAsFixed(2);
        case 'CARD':
          _cardCtrl.text =
              (total - _cash - _upi).clamp(0, total).toStringAsFixed(2);
      }
    });
  }

  void _complete() {
    if (_hasSplitLimitError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Each payment amount must be ${CurrencyFormatter.formatIndian(_maxTenderAmount)} or less',
          ),
          backgroundColor: KColors.error,
        ),
      );
      return;
    }
    if (_splitSum < widget.cart.total - 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Split total (${CurrencyFormatter.formatIndian(_splitSum)}) is less than bill total'),
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
        if (_upiRefCtrl.text.trim().isNotEmpty)
          'reference': _upiRefCtrl.text.trim(),
      });
    }
    if (_card > 0) splits.add({'mode': 'CARD', 'amount': _card});

    final primary = splits.reduce(
        (a, b) => (a['amount'] as double) >= (b['amount'] as double) ? a : b);

    Navigator.pop(context, {
      'paymentMode': primary['mode'],
      'amountReceived': _splitSum,
      'upiReference':
          _upiRefCtrl.text.trim().isEmpty ? null : _upiRefCtrl.text.trim(),
      'splits': splits,
      'gstInvoice': _gstInvoice,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = widget.cart.total;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            KSpacing.vGapSm,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Split Payment', style: KTypography.h4),
                Text('Total ${CurrencyFormatter.formatIndian(total)}',
                    style: KTypography.labelLarge.copyWith(color: cs.primary)),
              ],
            ),
            KSpacing.vGapSm,
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MarginHintBanner(cart: widget.cart),
                    const SizedBox(height: 8),
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
                    if (_hasSplitLimitError) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Each payment amount must be ${CurrencyFormatter.formatIndian(_maxTenderAmount)} or less',
                        style: KTypography.labelSmall
                            .copyWith(color: KColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
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
                    CurrencyFormatter.formatIndian(
                        _remaining.abs() < 0.01 ? 0 : _remaining),
                    style: KTypography.h3.copyWith(
                      color: _remaining.abs() < 0.01
                          ? KColors.success
                          : KColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            _GstInvoiceToggle(
              value: _gstInvoice,
              onChanged: (v) => setState(() => _gstInvoice = v),
            ),
            KSpacing.vGapSm,
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _splitSum >= total - 0.01 && !_hasSplitLimitError
                    ? _complete
                    : null,
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
            maxLength: _maxTenderInputLength,
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

class _GstInvoiceToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GstInvoiceToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Customer needs GST invoice',
                      style: KTypography.labelMedium),
                  Text(
                    'Prints detailed receipt with HSN & tax breakdown',
                    style: KTypography.labelSmall.copyWith(
                      color: KColors.textSecondary,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarginHintBanner extends StatelessWidget {
  final PosCartState cart;
  const _MarginHintBanner({required this.cart});

  @override
  Widget build(BuildContext context) {
    final totalCost = cart.totalCost;
    if (totalCost <= 0) return const SizedBox.shrink();

    final sellingTotal = cart.subtotal;
    final margin = sellingTotal - totalCost;
    final marginPct = (margin / totalCost * 100);
    final isBelowCost = margin < 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isBelowCost
            ? KColors.error.withValues(alpha: 0.08)
            : KColors.successLight,
        borderRadius: BorderRadius.circular(10),
        border: isBelowCost
            ? Border.all(color: KColors.error.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isBelowCost ? Icons.warning_amber_rounded : Icons.insights,
                size: 16,
                color: isBelowCost ? KColors.error : KColors.success,
              ),
              const SizedBox(width: 6),
              Text(
                isBelowCost ? 'Selling below cost!' : 'Margin summary',
                style: KTypography.labelSmall.copyWith(
                  color: isBelowCost ? KColors.error : KColors.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                  child: _field(
                      'Cost', CurrencyFormatter.formatIndian(totalCost))),
              Expanded(
                  child: _field(
                      'Selling', CurrencyFormatter.formatIndian(sellingTotal))),
              Expanded(
                child: _field(
                  'Margin',
                  '${CurrencyFormatter.formatIndian(margin.abs())} (${marginPct.abs().toStringAsFixed(0)}%)',
                  color: isBelowCost ? KColors.error : KColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _field(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: KTypography.labelSmall
                .copyWith(color: KColors.textSecondary, fontSize: 10)),
        Text(value,
            style: KTypography.labelSmall.copyWith(
              color: color ?? KColors.textPrimary,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }
}
