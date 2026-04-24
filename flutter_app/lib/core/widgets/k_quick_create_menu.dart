import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import '../../routing/app_router.dart';

class KQuickCreateMenu extends StatelessWidget {
  final bool expanded;

  const KQuickCreateMenu({super.key, this.expanded = true});

  static const _items = [
    _CreateItem(label: 'New Invoice', icon: Icons.receipt_long_rounded, route: Routes.invoiceCreate),
    _CreateItem(label: 'New POS Sale', icon: Icons.point_of_sale_rounded, route: Routes.pos),
    _CreateItem(label: 'New Bill', icon: Icons.receipt_rounded, route: Routes.billCreate),
    _CreateItem(label: 'New Customer', icon: Icons.person_add_rounded, route: Routes.contactCreate),
    _CreateItem(label: 'New Item', icon: Icons.add_box_rounded, route: Routes.itemCreate),
    _CreateItem(label: 'New Expense', icon: Icons.payments_rounded, route: Routes.expenseCreate),
    _CreateItem(label: 'New Estimate', icon: Icons.request_quote_rounded, route: Routes.estimateCreate),
    _CreateItem(label: 'New Sales Order', icon: Icons.assignment_rounded, route: Routes.salesOrderCreate),
    _CreateItem(label: 'New Credit Note', icon: Icons.note_add_rounded, route: Routes.creditNoteCreate),
  ];

  void _show(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlayBox = Navigator.of(context)
        .overlay!
        .context
        .findRenderObject()! as RenderBox;
    final pos =
        renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final size = renderBox.size;
    final overlaySize = overlayBox.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        pos.dx,
        pos.dy + size.height + 4,
        overlaySize.width - pos.dx - size.width,
        overlaySize.height - pos.dy - size.height - 4,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      items: _items
          .map(
            (item) => PopupMenuItem<String>(
              value: item.route,
              padding: const EdgeInsets.symmetric(
                  horizontal: KSpacing.md, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.label,
                    style: KTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ).then((route) {
      if (route != null && context.mounted) {
        context.push(route);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!expanded) {
      return Material(
        color: cs.primary,
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(KSpacing.radiusMd),
          onTap: () => _show(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Create',
                  style: KTypography.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _show(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: KSpacing.sm + 4, vertical: 10),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_rounded, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'Quick Create',
              style: KTypography.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateItem {
  final String label;
  final IconData icon;
  final String route;
  const _CreateItem(
      {required this.label, required this.icon, required this.route});
}
