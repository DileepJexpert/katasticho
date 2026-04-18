import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import '../../routing/app_router.dart';

/// A popup "Quick Create" menu — Zoho NextGen style.
///
/// Shows a floating menu of the most common create actions anchored
/// to the widget it wraps (usually a `+` button in the sidebar or top bar).
class KQuickCreateMenu extends StatelessWidget {
  /// Whether to show labels alongside icons (sidebar = true, icon bar = false).
  final bool expanded;

  const KQuickCreateMenu({super.key, this.expanded = true});

  static const _items = [
    _CreateItem(
      label: 'Invoice',
      icon: Icons.receipt_long_rounded,
      route: Routes.invoiceCreate,
    ),
    _CreateItem(
      label: 'Estimate',
      icon: Icons.request_quote_rounded,
      route: Routes.estimateCreate,
    ),
    _CreateItem(
      label: 'Bill',
      icon: Icons.receipt_rounded,
      route: Routes.billCreate,
    ),
    _CreateItem(
      label: 'Expense',
      icon: Icons.payments_rounded,
      route: Routes.expenseCreate,
    ),
    _CreateItem(
      label: 'Contact',
      icon: Icons.person_add_rounded,
      route: Routes.contactCreate,
    ),
    _CreateItem(
      label: 'Item',
      icon: Icons.add_box_rounded,
      route: Routes.itemCreate,
    ),
    _CreateItem(
      label: 'Credit Note',
      icon: Icons.note_add_rounded,
      route: Routes.creditNoteCreate,
    ),
  ];

  void _show(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + size.height + 4,
        offset.dx + size.width,
        0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(KSpacing.radiusMd),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      elevation: 0,
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
      return IconButton(
        icon: const Icon(Icons.add_rounded),
        tooltip: 'Quick Create',
        onPressed: () => _show(context),
        color: cs.onSurface,
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
