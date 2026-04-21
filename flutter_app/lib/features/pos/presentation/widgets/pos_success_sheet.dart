import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';

/// Result from the success sheet — which action the user chose.
enum SuccessAction { print, whatsapp, email, skip }

/// Post-sale success sheet — shows receipt details and share options.
/// Auto-dismisses after 10 seconds if no action taken.
Future<SuccessAction?> showPosSuccessSheet(
  BuildContext context, {
  required Map<String, dynamic> receipt,
  String? customerPhone,
}) {
  return showModalBottomSheet<SuccessAction>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    isScrollControlled: true,
    builder: (_) => _SuccessSheetContent(
      receipt: receipt,
      customerPhone: customerPhone,
    ),
  );
}

class _SuccessSheetContent extends StatefulWidget {
  final Map<String, dynamic> receipt;
  final String? customerPhone;

  const _SuccessSheetContent({
    required this.receipt,
    this.customerPhone,
  });

  @override
  State<_SuccessSheetContent> createState() => _SuccessSheetContentState();
}

class _SuccessSheetContentState extends State<_SuccessSheetContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _checkAnim;
  late final Animation<double> _scaleAnim;
  Timer? _autoDismiss;
  int _countdown = 10;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _checkAnim,
      curve: Curves.elasticOut,
    );
    _checkAnim.forward();

    _autoDismiss = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        Navigator.pop(context, SuccessAction.skip);
      }
    });
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    _autoDismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final data = _receiptData;
    final receiptNumber = data['receiptNumber'] ?? '';
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final amountReceived =
        (data['amountReceived'] as num?)?.toDouble() ?? total;
    final changeReturned =
        (data['changeReturned'] as num?)?.toDouble() ?? 0;
    final paymentMode = data['paymentMode']?.toString() ?? 'CASH';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated checkmark
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: KColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 40, color: KColors.success),
              ),
            ),
            KSpacing.vGapMd,

            Text('Sale Completed', style: KTypography.h2),
            const SizedBox(height: 4),
            Text(
              receiptNumber,
              style: KTypography.labelLarge.copyWith(color: cs.primary),
            ),
            KSpacing.vGapLg,

            // Summary rows
            _SummaryRow(label: 'Total', value: CurrencyFormatter.formatIndian(total)),
            const SizedBox(height: 6),
            _SummaryRow(
              label: _paymentLabel(paymentMode),
              value: CurrencyFormatter.formatIndian(amountReceived),
            ),
            if (changeReturned > 0) ...[
              const SizedBox(height: 6),
              _SummaryRow(
                label: 'Change',
                value: CurrencyFormatter.formatIndian(changeReturned),
                valueColor: KColors.success,
              ),
            ],
            KSpacing.vGapLg,

            // Action buttons
            _ActionButton(
              icon: Icons.print,
              label: 'Print Receipt',
              onTap: () => Navigator.pop(context, SuccessAction.print),
            ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: Icons.send,
              label: 'Send via WhatsApp',
              onTap: () => Navigator.pop(context, SuccessAction.whatsapp),
            ),
            const SizedBox(height: 8),
            _ActionButton(
              icon: Icons.email_outlined,
              label: 'Email Receipt',
              onTap: () => Navigator.pop(context, SuccessAction.email),
            ),
            KSpacing.vGapMd,

            TextButton(
              onPressed: () => Navigator.pop(context, SuccessAction.skip),
              child: Text(
                'Skip (auto in ${_countdown}s)',
                style: KTypography.labelMedium.copyWith(
                  color: KColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Map<String, dynamic> get _receiptData {
    // Handle both wrapped (ApiResponse) and direct receipt data
    final data = widget.receipt['data'];
    if (data is Map<String, dynamic>) return data;
    return widget.receipt;
  }

  String _paymentLabel(String mode) => switch (mode) {
        'CASH' => 'Cash',
        'UPI' => 'UPI',
        'CARD' => 'Card',
        _ => mode,
      };
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: KTypography.bodyMedium
                .copyWith(color: KColors.textSecondary)),
        Text(value,
            style: KTypography.labelLarge
                .copyWith(color: valueColor)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: cs.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
