import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/shortcuts/k_shortcuts.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/pos_cart_state.dart';
import '../../data/pos_providers.dart';

/// Sticky bottom bar with subtotal/tax/total breakdown and payment mode buttons.
class PosTotalBar extends ConsumerWidget {
  final VoidCallback? onCashTap;
  final VoidCallback? onUpiTap;
  final VoidCallback? onCardTap;
  final VoidCallback? onSplitTap;
  final VoidCallback? onKhataTap;

  const PosTotalBar({
    super.key,
    this.onCashTap,
    this.onUpiTap,
    this.onCardTap,
    this.onSplitTap,
    this.onKhataTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(posCartProvider);
    final khataEnabled =
        ref.watch(posAllowCreditSalesProvider).valueOrNull ?? false;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
            if (cart.hasMrpViolation)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: KColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: KColors.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gpp_bad_outlined, size: 14, color: KColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Above MRP: ${cart.mrpViolatedItems.map((i) => i.name).join(', ')}',
                        style: const TextStyle(
                          fontSize: 11, color: KColors.error, fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (!cart.isEmpty) ...[
              if (cart.schemeSavings > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_offer_outlined, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Scheme savings: ${CurrencyFormatter.formatIndian(cart.schemeSavings)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _InlineAmount(
                      label: 'Subtotal',
                      amount: cart.subtotal,
                    ),
                  ),
                  if (cart.taxAmount > 0)
                    Expanded(
                      child: _InlineAmount(
                        label: 'GST',
                        amount: cart.taxAmount,
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Total', style: KTypography.labelMedium),
                        const SizedBox(width: 8),
                        _OverallMarginDot(cart: cart),
                        const SizedBox(width: 8),
                        Flexible(
                          child: KMoney(
                            cart.total,
                            size: KMoneySize.large,
                            style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total', style: KTypography.labelMedium),
                  KMoney(
                    cart.total,
                    size: KMoneySize.large,
                    style: TextStyle(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: _PaymentButton(
                    icon: Icons.payments_outlined,
                    label: 'Cash',
                    shortcut: KShortcuts.posCash,
                    color: KColors.success,
                    isSelected: cart.paymentMode == 'CASH',
                    onTap: cart.isEmpty ? null : onCashTap,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PaymentButton(
                    icon: Icons.qr_code_2,
                    label: 'UPI',
                    shortcut: KShortcuts.posUpi,
                    color: KColors.primary,
                    isSelected: cart.paymentMode == 'UPI',
                    onTap: cart.isEmpty ? null : onUpiTap,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PaymentButton(
                    icon: Icons.credit_card,
                    label: 'Card',
                    shortcut: KShortcuts.posCard,
                    color: KColors.secondary,
                    isSelected: cart.paymentMode == 'CARD',
                    onTap: cart.isEmpty ? null : onCardTap,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _PaymentButton(
                    icon: Icons.call_split,
                    label: 'Split',
                    shortcut: KShortcuts.posSplit,
                    color: KColors.info,
                    isSelected: false,
                    onTap: cart.isEmpty ? null : onSplitTap,
                  ),
                ),
                if (khataEnabled) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: _PaymentButton(
                      icon: Icons.menu_book_outlined,
                      label: 'Khata',
                      shortcut: '',
                      color: KColors.warning,
                      isSelected: cart.paymentMode == 'CREDIT',
                      onTap: cart.isEmpty ? null : onKhataTap,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineAmount extends StatelessWidget {
  final String label;
  final double amount;

  const _InlineAmount({
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: KTypography.labelSmall.copyWith(
            color: KColors.textSecondary,
            fontSize: 10,
          ),
        ),
        KMoney(
          amount,
          size: KMoneySize.small,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: effectiveColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: KTypography.labelSmall.copyWith(
                    color: effectiveColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(shortcut,
                  style: KTypography.labelSmall.copyWith(
                    color: effectiveColor.withValues(alpha: 0.55),
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
      case 4:
        return const Color(0xFF1F2937);
      case 3:
        return const Color(0xFFEF4444);
      case 2:
        return const Color(0xFFEAB308);
      case 1:
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFF22C55E);
    }
  }
}
