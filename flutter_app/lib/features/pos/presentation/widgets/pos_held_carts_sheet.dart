import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/k_colors.dart';
import '../../../../core/theme/k_spacing.dart';
import '../../../../core/theme/k_typography.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/pos_cart_state.dart';
import '../../data/pos_held_carts.dart';

Future<PosCartState?> showHeldCartsSheet(BuildContext context) {
  return showDialog<PosCartState>(
    context: context,
    builder: (_) => const Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: _HeldCartsSheetContent(),
    ),
  );
}

class _HeldCartsSheetContent extends ConsumerWidget {
  const _HeldCartsSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final held = ref.watch(heldCartsProvider);
    final cs = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.pause_circle_outline, size: 20),
                KSpacing.hGapSm,
                Text('Held Carts (${held.length}/5)',
                    style: KTypography.h3),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            KSpacing.vGapMd,
            if (held.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.shopping_cart_outlined,
                        size: 48, color: cs.outlineVariant),
                    KSpacing.vGapSm,
                    Text('No held carts',
                        style: KTypography.bodyMedium
                            .copyWith(color: KColors.textSecondary)),
                  ],
                ),
              )
            else
              ...held.map((h) => _HeldCartTile(
                    held: h,
                    onRecall: () {
                      final cart =
                          ref.read(heldCartsProvider.notifier).recall(h.id);
                      Navigator.pop(context, cart);
                    },
                    onDelete: () {
                      ref.read(heldCartsProvider.notifier).remove(h.id);
                    },
                  )),
          ],
        ),
      ),
    );
  }
}

class _HeldCartTile extends StatelessWidget {
  final HeldCart held;
  final VoidCallback onRecall;
  final VoidCallback onDelete;

  const _HeldCartTile({
    required this.held,
    required this.onRecall,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ago = DateTime.now().difference(held.heldAt);
    final agoText = ago.inMinutes < 1
        ? 'just now'
        : ago.inMinutes < 60
            ? '${ago.inMinutes}m ago'
            : '${ago.inHours}h ago';

    return KCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: onRecall,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${held.cart.itemCount}',
                style: KTypography.labelLarge
                    .copyWith(color: cs.primary),
              ),
            ),
          ),
          KSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(held.label, style: KTypography.labelMedium),
                const SizedBox(height: 2),
                Text(
                  '${held.cart.totalQuantity} items · $agoText',
                  style: KTypography.bodySmall
                      .copyWith(color: KColors.textSecondary),
                ),
              ],
            ),
          ),
          KMoney(
            held.cart.total,
            size: KMoneySize.small,
          ),
          KSpacing.hGapSm,
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onDelete,
            tooltip: 'Discard',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
