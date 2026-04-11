import 'package:flutter/material.dart';
import '../theme/k_colors.dart';
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
    final effectiveOnPressed = isLoading ? null : onPressed;
    final child = _buildChild();

    Widget button = switch (variant) {
      KButtonVariant.primary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: _primaryStyle(),
          child: child,
        ),
      KButtonVariant.secondary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: _secondaryStyle(),
          child: child,
        ),
      KButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveOnPressed,
          style: _outlinedStyle(),
          child: child,
        ),
      KButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          child: child,
        ),
      KButtonVariant.danger => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: _dangerStyle(),
          child: child,
        ),
    };

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }

  Widget _buildChild() {
    if (isLoading) {
      return SizedBox(
        height: _iconSize,
        width: _iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: variant == KButtonVariant.outlined
              ? KColors.primary
              : KColors.onPrimary,
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

  ButtonStyle _primaryStyle() => ElevatedButton.styleFrom(
        backgroundColor: KColors.primary,
        foregroundColor: KColors.onPrimary,
        padding: _padding,
        textStyle: _textStyle,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );

  ButtonStyle _secondaryStyle() => ElevatedButton.styleFrom(
        backgroundColor: KColors.secondary,
        foregroundColor: KColors.onSecondary,
        padding: _padding,
        textStyle: _textStyle,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );

  ButtonStyle _outlinedStyle() => OutlinedButton.styleFrom(
        foregroundColor: KColors.primary,
        padding: _padding,
        textStyle: _textStyle,
        side: const BorderSide(color: KColors.primary),
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );

  ButtonStyle _dangerStyle() => ElevatedButton.styleFrom(
        backgroundColor: KColors.error,
        foregroundColor: Colors.white,
        padding: _padding,
        textStyle: _textStyle,
        shape: RoundedRectangleBorder(borderRadius: KSpacing.borderRadiusMd),
      );
}
