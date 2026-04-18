import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

/// Right-side peek drawer — **Katasticho 2026** spec.
///
/// On tablet/desktop (≥ [KSpacing.tabletBreakpoint]) we slide a detail panel
/// in from the right edge instead of pushing a full-screen route. On mobile
/// it falls back to a full-height bottom sheet so callers can use the same
/// API everywhere.
///
/// Pattern is borrowed from Linear / Notion / Stripe Dashboard — keeps the
/// list context visible while inspecting a row.
class KDetailDrawer extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final List<Widget>? footerActions;
  final double width;

  const KDetailDrawer({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.footerActions,
    this.width = 480,
  });

  /// Slides the drawer in from the right. On screens narrower than the tablet
  /// breakpoint, falls back to a full-height bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    String? subtitle,
    List<Widget>? actions,
    List<Widget>? footerActions,
    double width = 480,
  }) {
    final isCompact =
        MediaQuery.sizeOf(context).width < KSpacing.tabletBreakpoint;

    if (isCompact) {
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KSpacing.radiusXl),
          ),
        ),
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.92,
          child: KDetailDrawer(
            title: title,
            subtitle: subtitle,
            actions: actions,
            footerActions: footerActions,
            width: double.infinity,
            child: child,
          ),
        ),
      );
    }

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.32),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondary) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              height: double.infinity,
              width: width,
              child: KDetailDrawer(
                title: title,
                subtitle: subtitle,
                actions: actions,
                footerActions: footerActions,
                width: width,
                child: child,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, secondary, widget) {
        final offset = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
        return SlideTransition(position: offset, child: widget);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact =
        MediaQuery.sizeOf(context).width < KSpacing.tabletBreakpoint;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: isCompact
            ? null
            : Border(left: BorderSide(color: cs.outlineVariant, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KSpacing.md + 4,
              KSpacing.md,
              KSpacing.sm,
              KSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: KTypography.h2.copyWith(color: cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: KTypography.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (actions != null) ...[
                  for (final a in actions!) ...[
                    a,
                    const SizedBox(width: 4),
                  ],
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: cs.onSurfaceVariant,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: cs.outlineVariant),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.md + 4,
                KSpacing.md,
                KSpacing.md + 4,
                KSpacing.md,
              ),
              child: child,
            ),
          ),

          // Footer
          if (footerActions != null && footerActions!.isNotEmpty) ...[
            Divider(height: 1, thickness: 1, color: cs.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KSpacing.md,
                KSpacing.sm + 2,
                KSpacing.md,
                KSpacing.sm + 2,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < footerActions!.length; i++) ...[
                    if (i > 0) const SizedBox(width: KSpacing.sm),
                    footerActions![i],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
