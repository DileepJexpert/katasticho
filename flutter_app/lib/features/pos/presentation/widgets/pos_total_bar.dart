import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/pos_cart_state.dart';

/// Sticky bottom bar with subtotal/tax/total breakdown and payment mode buttons.
class PosTotalBar extends ConsumerWidget {
  final VoidCallback? onCashTap;
  final VoidCallback? onUpiTap;
  final VoidCallback? onCardTap;
  final VoidCallback? onSplitTap;

  const PosTotalBar({
    super.key,
    this.onCashTap,
    this.onUpiTap,
    this.onCardTap,
    this.onSplitTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
            // Subtotal + tax + total breakdown
            if (!cart.isEmpty) ...[
              _AmountRow(
                label: 'Subtotal',
                amount: cart.subtotal,
                style: KTypography.bodyMedium,
                amountStyle: KTypography.labelMedium,
              ),
              if (cart.taxAmount > 0) ...[
                const SizedBox(height: 2),
                _AmountRow(
                  label: 'GST',
                  amount: cart.taxAmount,
                  style: KTypography.bodySmall.copyWith(
                    color: KColors.textSecondary,
                  ),
                  amountStyle: KTypography.bodySmall.copyWith(
                    color: KColors.textSecondary,
                  ),
                ),
              ],
              Divider(height: 12, color: cs.outlineVariant),
            ],

            // Grand total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Total', style: KTypography.h3),
                    if (!cart.isEmpty) ...[
                      const SizedBox(width: 8),
                      _OverallMarginDot(cart: cart),
                    ],
                  ],
                ),
                Text(
                  CurrencyFormatter.formatIndian(cart.total),
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
                    shortcut: 'F1',
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
                    shortcut: 'F2',
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
                    shortcut: 'F3',
                    color: KColors.secondary,
                    isSelected: cart.paymentMode == 'CARD',
                    onTap: cart.isEmpty ? null : onCardTap,
                  ),
                ),
                KSpacing.hGapSm,
                Expanded(
                  child: _PaymentButton(
                    icon: Icons.call_split,
                    label: 'Split',
                    shortcut: 'F6',
                    color: KColors.info,
                    isSelected: false,
                    onTap: cart.isEmpty ? null : onSplitTap,
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

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final TextStyle style;
  final TextStyle amountStyle;

  const _AmountRow({
    required this.label,
    required this.amount,
    required this.style,
    required this.amountStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(CurrencyFormatter.formatIndian(amount), style: amountStyle),
      ],
    );
  }
}

class _PaymentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String shortcut;
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PaymentButton({
    required this.icon,
    required this.label,
    required this.shortcut,
    required this.color,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor =
        onTap == null ? cs.onSurface.withValues(alpha: 0.3) : color;

    return Material(
      color: isSelected
          ? effectiveColor.withValues(alpha: 0.12)
          : cs.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 22, color: effectiveColor),
              const SizedBox(height: 3),
              Text(label,
                  style: KTypography.labelSmall.copyWith(
                    color: effectiveColor,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                  )),
              Text(shortcut,
                  style: KTypography.labelSmall.copyWith(
                    color: effectiveColor.withValues(alpha: 0.5),
                    fontSize: 9,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverallMarginDot extends StatelessWidget {
  final PosCartState cart;

  const _OverallMarginDot({required this.cart});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _overallColor(),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
    );
  }

  Color _overallColor() {
    if (cart.isEmpty) return const Color(0xFF22C55E);

    Color worst = const Color(0xFF22C55E);
    int worstRank = 0;

    for (final item in cart.items) {
      final rank = _bandRank(item);
      if (rank > worstRank) {
        worstRank = rank;
        worst = _bandColor(rank);
      }
    }
    return worst;
  }

  int _bandRank(CartItem item) {
    final t = item.discountThresholds;
    if (t == null) return 0;

    final blockAt = (t['blockAt'] as num?)?.toDouble() ?? 100;
    final redMax = (t['redMax'] as num?)?.toDouble() ?? 100;
    final yellowMax = (t['yellowMax'] as num?)?.toDouble() ?? 100;
    final blueMax = (t['blueMax'] as num?)?.toDouble() ?? 100;

    if (item.discountPct > blockAt) return 4;
    if (item.discountPct > redMax) return 3;
    if (item.discountPct > yellowMax) return 2;
    if (item.discountPct > blueMax) return 1;
    return 0;
  }

  Color _bandColor(int rank) {
    switch (rank) {
      case 4: return const Color(0xFF1F2937);
      case 3: return const Color(0xFFEF4444);
      case 2: return const Color(0xFFEAB308);
      case 1: return const Color(0xFF3B82F6);
      default: return const Color(0xFF22C55E);
    }
  }
}
