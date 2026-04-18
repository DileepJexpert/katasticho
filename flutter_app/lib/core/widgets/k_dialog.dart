import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';
import 'k_button.dart';

/// Centered modal dialog — **Katasticho 2026** spec.
///
/// Layout:
///   ┌──────────────────────────────────────────┐
///   │  Title                              [X]  │  ← header
///   ├──────────────────────────────────────────┤
///   │  Body content                            │
///   ├──────────────────────────────────────────┤
///   │                     [ Cancel ] [ Save ]  │  ← footer (right-aligned)
///   └──────────────────────────────────────────┘
///
/// Use the [KDialog.show] helper for the common case, or compose directly
/// inside `showDialog(builder: ...)` for custom flows.
class KDialog extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final EdgeInsets? bodyPadding;
  final bool showCloseButton;

  const KDialog({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.maxWidth = 480,
    this.bodyPadding,
    this.showCloseButton = true,
  });

  /// Shows a centered KDialog. Returns the dialog's result.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget child,
    List<Widget>? actions,
    double maxWidth = 480,
    EdgeInsets? bodyPadding,
    bool barrierDismissible = true,
    bool showCloseButton = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => KDialog(
        title: title,
        actions: actions,
        maxWidth: maxWidth,
        bodyPadding: bodyPadding,
        showCloseButton: showCloseButton,
        child: child,
      ),
    );
  }

  /// Convenience confirm-style dialog. Returns `true` on confirm.
  static Future<bool> confirm({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    // IMPORTANT: build the actions inside the dialog's own builder so their
    // onPressed callbacks capture the *dialog* route's context. Using the
    // caller's `context` would pop the underlying page instead of the dialog.
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => KDialog(
        title: title,
        child: Text(
          message,
          style: KTypography.bodyMedium.copyWith(
            color: Theme.of(dialogCtx).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          KButton(
            label: cancelLabel,
            variant: KButtonVariant.text,
            onPressed: () => Navigator.of(dialogCtx).pop(false),
          ),
          KButton(
            label: confirmLabel,
            variant: destructive
                ? KButtonVariant.danger
                : KButtonVariant.primary,
            onPressed: () => Navigator.of(dialogCtx).pop(true),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(KSpacing.radiusXl);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: KSpacing.md,
        vertical: KSpacing.lg,
      ),
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                    child: Text(
                      title,
                      style: KTypography.h3.copyWith(color: cs.onSurface),
                    ),
                  ),
                  if (showCloseButton)
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
            Flexible(
              child: SingleChildScrollView(
                padding: bodyPadding ??
                    const EdgeInsets.fromLTRB(
                      KSpacing.md + 4,
                      KSpacing.md,
                      KSpacing.md + 4,
                      KSpacing.md,
                    ),
                child: child,
              ),
            ),

            // Footer
            if (actions != null && actions!.isNotEmpty) ...[
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
                    for (var i = 0; i < actions!.length; i++) ...[
                      if (i > 0) const SizedBox(width: KSpacing.sm),
                      actions![i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
