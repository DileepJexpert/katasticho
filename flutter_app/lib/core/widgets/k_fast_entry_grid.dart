import 'package:flutter/material.dart';
import '../shortcuts/k_shortcuts.dart';
import '../theme/k_colors.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// Floating or embedded quick-reference shortcut bar for keyboard-first billing.
class KBillingShortcutBar extends StatelessWidget {
  final VoidCallback? onDateJump;
  final VoidCallback? onItemLookup;
  final VoidCallback? onSchemeLookup;
  final VoidCallback? onQuickCreate;
  final VoidCallback? onAddRow;
  final VoidCallback? onSubmit;
  final VoidCallback? onPrint;

  const KBillingShortcutBar({
    super.key,
    this.onDateJump,
    this.onItemLookup,
    this.onSchemeLookup,
    this.onQuickCreate,
    this.onAddRow,
    this.onSubmit,
    this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: KSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onDateJump != null)
            _ShortcutChip(
              keyLabel: KShortcuts.billingDateJump,
              actionLabel: 'Date',
              onTap: onDateJump,
            ),
          if (onItemLookup != null)
            _ShortcutChip(
              keyLabel: KShortcuts.billingItemLookup,
              actionLabel: 'Find Item',
              onTap: onItemLookup,
            ),
          if (onSchemeLookup != null)
            _ShortcutChip(
              keyLabel: KShortcuts.billingSchemeLookup,
              actionLabel: 'Schemes',
              onTap: onSchemeLookup,
            ),
          if (onQuickCreate != null)
            _ShortcutChip(
              keyLabel: KShortcuts.billingQuickCreate,
              actionLabel: 'New Party/Item',
              onTap: onQuickCreate,
            ),
          if (onAddRow != null)
            _ShortcutChip(
              keyLabel: 'Alt+A',
              actionLabel: 'Add Row',
              onTap: onAddRow,
            ),
          if (onSubmit != null)
            _ShortcutChip(
              keyLabel: KShortcuts.formSubmit,
              actionLabel: 'Save Order',
              isPrimary: true,
              onTap: onSubmit,
            ),
          if (onPrint != null)
            _ShortcutChip(
              keyLabel: KShortcuts.billingPrint,
              actionLabel: 'Save & Print',
              onTap: onPrint,
            ),
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final String keyLabel;
  final String actionLabel;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _ShortcutChip({
    required this.keyLabel,
    required this.actionLabel,
    this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: isPrimary
                    ? KColors.primary
                    : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isPrimary
                      ? KColors.primary
                      : cs.outlineVariant,
                ),
              ),
              child: Text(
                keyLabel,
                style: KTypography.mono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? Colors.white : cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              actionLabel,
              style: KTypography.labelSmall.copyWith(
                color: isPrimary ? KColors.primary : cs.onSurface,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
