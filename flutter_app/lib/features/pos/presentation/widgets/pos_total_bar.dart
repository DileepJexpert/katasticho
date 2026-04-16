import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/pos_cart_state.dart';

/// Sticky bottom bar with total amount and payment mode buttons.
class PosTotalBar extends ConsumerWidget {
  final VoidCallback? onCashTap;
  final VoidCallback? onUpiTap;
  final VoidCallback? onCardTap;

  const PosTotalBar({
    super.key,
    this.onCashTap,
    this.onUpiTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Total row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: KTypography.h3),
                Text(
                  CurrencyFormatter.formatIndian(cart.subtotal),
                  style: KTypography.h2.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            KSpacing.vGapMd,

            // Payment mode buttons
            Row(
              children: [
                Expanded(
                  child: _PaymentButton(
                    icon: Icons.payments_outlined,
                    label: 'Cash',
                    color: KColors.success,
                    isSelected: cart.paymentMode == 'CASH',
                    onTap: cart.isEmpty ? null : onCashTap,
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: _PaymentButton(
                    icon: Icons.qr_code_2,
                    label: 'UPI',
                    color: KColors.primary,
                    isSelected: cart.paymentMode == 'UPI',
                    onTap: cart.isEmpty ? null : onUpiTap,
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: _PaymentButton(
                    icon: Icons.credit_card,
                    label: 'Card',
                    color: KColors.secondary,
                    isSelected: cart.paymentMode == 'CARD',
                    onTap: cart.isEmpty ? null : onCardTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PaymentButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = onTap == null ? cs.onSurface.withValues(alpha: 0.3) : color;

    return Material(
      color: isSelected
          ? effectiveColor.withValues(alpha: 0.12)
          : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 22, color: effectiveColor),
              const SizedBox(height: 4),
              Text(label,
                  style: KTypography.labelSmall.copyWith(
                    color: effectiveColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
