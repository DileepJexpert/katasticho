import 'package:flutter/material.dart';
import '../theme/k_typography.dart';
import '../theme/k_spacing.dart';

enum KButtonVariant { primary, secondary, outlined, text, danger }
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
          color: variant == KButtonVariant.outlined
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
          KSpacing.hGapSm,
          Text(label),
        ],
      );
    }

    return Text(label);
  }

  double get _iconSize => switch (size) {
        KButtonSize.small => 14,
        KButtonSize.medium => 18,
        KButtonSize.large => 20,
      };

  EdgeInsets get _padding => switch (size) {
        KButtonSize.small =>
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        KButtonSize.medium =>
          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        KButtonSize.large =>
          const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
      };

  TextStyle get _textStyle => switch (size) {
        KButtonSize.small => KTypography.buttonSmall,
        KButtonSize.medium => KTypography.button,
        KButtonSize.large => KTypography.button.copyWith(fontSize: 16),
      };

  ButtonStyle _primaryStyle(ColorScheme cs) => ElevatedButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        padding: _padding,
        textStyle: _textStyle,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );

  ButtonStyle _secondaryStyle(ColorScheme cs) => ElevatedButton.styleFrom(
        backgroundColor: cs.secondary,
        foregroundColor: cs.onSecondary,
        padding: _padding,
        textStyle: _textStyle,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );

  ButtonStyle _outlinedStyle(ColorScheme cs) => OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        padding: _padding,
        textStyle: _textStyle,
        side: BorderSide(color: cs.primary),
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );

  ButtonStyle _dangerStyle(ColorScheme cs) => ElevatedButton.styleFrom(
        backgroundColor: cs.error,
        foregroundColor: cs.onError,
        padding: _padding,
        textStyle: _textStyle,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );
}
