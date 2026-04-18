import 'package:flutter/material.dart';
import '../theme/k_spacing.dart';
import '../theme/k_typography.dart';

enum KButtonVariant { primary, secondary, outlined, text, danger }

/// Densities follow the Katasticho 2026 spec:
///   • small  → 32px height, for table-row actions
///   • medium → 38px height, default for forms & CTAs
///   • large  → 44px height, hero CTAs (e.g. "Pay Now")
enum KButtonSize { small, medium, large }

class KButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final KButtonVariant variant;
  final KButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool fullWidth;

  const KButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = KButtonVariant.primary,
    this.size = KButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = _buildChild(cs);

    Widget button = switch (variant) {
      KButtonVariant.primary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: _primaryStyle(cs),
          child: child,
        ),
      KButtonVariant.secondary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: _secondaryStyle(cs),
          child: child,
        ),
      KButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: _outlinedStyle(cs),
          child: child,
        ),
      KButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          style: _textStyleBtn(cs),
          child: child,
        ),
      KButtonVariant.danger => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: _dangerStyle(cs),
          child: child,
        ),
    };

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _buildChild(ColorScheme cs) {
    if (isLoading) {
      return SizedBox(
        height: _iconSize,
        width: _iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: variant == KButtonVariant.outlined ||
                  variant == KButtonVariant.text
              ? cs.primary
              : cs.onPrimary,
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _iconSize),
          SizedBox(width: size == KButtonSize.small ? 4 : 6),
          Text(label),
        ],
      );
    }

    return Text(label);
  }

  double get _iconSize => switch (size) {
        KButtonSize.small => 14,
        KButtonSize.medium => 16,
        KButtonSize.large => 18,
      };

  /// Visible button height (not tap target — M3 still expands hit area to 48dp).
  double get _minHeight => switch (size) {
        KButtonSize.small => 32,
        KButtonSize.medium => 38,
        KButtonSize.large => 44,
      };

  EdgeInsets get _padding => switch (size) {
        KButtonSize.small =>
          const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        KButtonSize.medium =>
          const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        KButtonSize.large =>
          const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
      };

  TextStyle get _textStyle => switch (size) {
        KButtonSize.small => KTypography.buttonSmall,
        KButtonSize.medium => KTypography.button,
        KButtonSize.large => KTypography.button.copyWith(fontSize: 15),
      };

  ButtonStyle _baseStyle({
    required Color background,
    required Color foreground,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      padding: _padding,
      textStyle: _textStyle,
      elevation: 0,
      shadowColor: Colors.transparent,
      minimumSize: Size(0, _minHeight),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
    );
  }

  ButtonStyle _primaryStyle(ColorScheme cs) =>
      _baseStyle(background: cs.primary, foreground: cs.onPrimary);

  /// "Secondary" in 2026 spec = a soft tinted fill (primaryContainer),
  /// not the old teal `cs.secondary`. Reads as a quieter primary action.
  ButtonStyle _secondaryStyle(ColorScheme cs) => _baseStyle(
        background: cs.primaryContainer,
        foreground: cs.onPrimaryContainer,
      );

  ButtonStyle _outlinedStyle(ColorScheme cs) => OutlinedButton.styleFrom(
        foregroundColor: cs.onSurface,
        padding: _padding,
        textStyle: _textStyle,
        side: BorderSide(color: cs.outlineVariant, width: 1),
        minimumSize: Size(0, _minHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );

  ButtonStyle _textStyleBtn(ColorScheme cs) => TextButton.styleFrom(
        foregroundColor: cs.primary,
        padding: _padding,
        textStyle: _textStyle,
        minimumSize: Size(0, _minHeight),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );

  ButtonStyle _dangerStyle(ColorScheme cs) =>
      _baseStyle(background: cs.error, foreground: cs.onError);
}
